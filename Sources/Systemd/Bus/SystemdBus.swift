#if os(Linux)
    import CSystemd
    import Dispatch
    import Glibc

    public actor SystemdBus {
        private typealias Continuation = CheckedContinuation<SystemdMessage, Error>

        // _bus, _readSource, and _writeSource are only touched during
        // init and deinit (which run outside the actor's mailbox); the
        // actor's serial execution covers the rest of the state.
        // `OpaquePointer` isn't `Sendable` in the Swift 5 language
        // surface, so the `let` needs `nonisolated(unsafe)` rather
        // than plain `nonisolated`.
        nonisolated(unsafe) private let _bus: OpaquePointer
        private var _continuations = [UInt64: Continuation]()
        nonisolated(unsafe) private var _readSource: DispatchSourceRead?
        nonisolated(unsafe) private var _writeSource: DispatchSourceWrite?
        // Wakes the bus when sd-bus next has a deadline, so call timeouts fire.
        nonisolated(unsafe) private let _timerSource: DispatchSourceTimer

        public static var system: Self {
            get throws {
                var sd: OpaquePointer!

                try throwingSystemdBusError {
                    sd_bus_default_system(&sd)
                }

                return try .init(bus: sd)
            }
        }

        public static var user: Self {
            get throws {
                var sd: OpaquePointer!

                try throwingSystemdBusError {
                    sd_bus_default_user(&sd)
                }

                return try .init(bus: sd)
            }
        }

        /// A new connection to the system bus of this actor's own.
        ///
        /// ``system`` wraps the calling thread's shared default connection, so two
        /// instances got on one thread drive one `sd_bus` from two actors. A private
        /// connection is serialised by this actor alone, and closes when it is released.
        public static func openSystem() throws -> Self {
            try _open(sd_bus_open_system)
        }

        /// A new connection to the user bus of this actor's own; see ``openSystem()``.
        public static func openUser() throws -> Self {
            try _open(sd_bus_open_user)
        }

        private static func _open(
            _ open: (UnsafeMutablePointer<OpaquePointer?>) -> CInt
        ) throws -> Self {
            var sd: OpaquePointer?
            try throwingSystemdBusError { open(&sd) }
            defer { sd_bus_unref(sd) }
            return try .init(bus: sd!)
        }

        nonisolated private var events: CInt {
            get throws {
                try throwingSystemdBusError {
                    sd_bus_get_events(_bus)
                }
            }
        }

        private func _process() throws -> Bool {
            let hasMoreMessages = try throwingSystemdBusError {
                sd_bus_process(_bus, nil)
            }
            return hasMoreMessages != 0
        }

        private func _processPending() {
            while (try? _process()) == true {}
            _rearmTimer()
        }

        nonisolated private func _processAll() {
            Task { await _processPending() }
        }

        /// Schedules the timer for sd-bus's next deadline, a reply timeout, if any.
        private func _rearmTimer() {
            var deadline = UInt64.max
            guard sd_bus_get_timeout(_bus, &deadline) >= 0, deadline != .max else {
                _timerSource.schedule(deadline: .distantFuture)
                return
            }
            // sd-bus's deadline is CLOCK_MONOTONIC, as DispatchTime's uptime is on Linux
            let (nanoseconds, overflow) = deadline.multipliedReportingOverflow(by: 1000)
            _timerSource.schedule(
                deadline: overflow ? .distantFuture : DispatchTime(uptimeNanoseconds: nanoseconds)
            )
        }

        init(bus: OpaquePointer) throws {
            _bus = sd_bus_ref(bus)
            _timerSource = DispatchSource.makeTimerSource()

            let fd = try throwingSystemdBusError {
                sd_bus_get_fd(_bus)
            }

            if try events & POLLIN != 0 {
                let readSource = DispatchSource.makeReadSource(fileDescriptor: fd)
                readSource.setEventHandler { [weak self] in
                    self?._processAll()
                }
                _readSource = readSource
                readSource.resume()
            }

            if try events & POLLOUT != 0 {
                let writeSource = DispatchSource.makeWriteSource(fileDescriptor: fd)
                writeSource.setEventHandler { [weak self] in
                    self?._processAll()
                }
                _writeSource = writeSource
                writeSource.resume()
            }

            _timerSource.setEventHandler { [weak self] in
                self?._processAll()
            }
            _timerSource.schedule(deadline: .distantFuture)
            _timerSource.resume()
        }

        public var isOpen: Bool {
            sd_bus_is_open(_bus) != 0
        }

        fileprivate func _resume(with message: SystemdMessage) -> Bool {
            var continuation: Continuation?

            guard let cookie = try? message.replyCookie else {
                return false
            }

            continuation = _continuations[cookie]
            _continuations[cookie] = nil

            if let continuation {
                if message.isMethodError {
                    continuation.resume(throwing: SystemdBusError(message: message))
                } else {
                    continuation.resume(returning: message)
                }
            }

            return true
        }

        private func _cancelAll() {
            for continuation in _continuations.values {
                continuation.resume(throwing: CancellationError())
            }
            _continuations.removeAll()
        }

        public func call(
            _ message: SystemdMessage,
            timeout: Duration? = nil
        ) async throws -> SystemdMessage {
            guard isOpen else {
                throw SystemdBusError(code: -ENOTCONN)
            }

            try message.withMessagePointer { m in
                sd_bus_call_async(
                    _bus,
                    nil,
                    m,
                    _sdBusMessageThunk,
                    Unmanaged.passRetained(self).toOpaque(),
                    timeout?.sdBusMicroseconds ?? 0
                )
            }
            _rearmTimer()

            return try await withCheckedThrowingContinuation { continuation in
                try! _continuations[message.cookie] = continuation
            }
        }

        func newMethodCall(
            destination: String,
            path: String,
            interface: String,
            member: String,
            autoStart: Bool
        ) throws -> SystemdMessage {
            var m: OpaquePointer!
            try throwingSystemdBusError {
                sd_bus_message_new_method_call(_bus, &m, destination, path, interface, member)
            }
            let message = SystemdMessage(consuming: m)
            if !autoStart {
                try message.withMessagePointer { sd_bus_message_set_auto_start($0, 0) }
            }
            return message
        }

        /// Calls a method and returns its first reply argument.
        ///
        /// - Parameters:
        ///   - autoStart: Whether the bus may start `destination` to deliver the call, if
        ///     it is activatable and not running. When false, the call fails instead.
        ///   - timeout: How long to wait for the reply; nil is sd-bus's default (25 s).
        public func callMethod(
            destination: String = "org.freedesktop.systemd1",
            path: String = "/org/freedesktop/systemd1",
            interface: String,
            member: String,
            fields: [any Sendable] = [],
            autoStart: Bool = true,
            timeout: Duration? = nil
        ) async throws -> (any Sendable)? {
            let message = try newMethodCall(
                destination: destination,
                path: path,
                interface: interface,
                member: member,
                autoStart: autoStart
            )

            var context = SystemdTypeContext(message: message)
            // SystemdTypeContext.append takes [Any]; the public signature
            // is the stricter [any Sendable]. Pass through as [Any] for
            // the internal serialiser; this is an upcast in spirit (every
            // `any Sendable` is also `Any`), allocating a single array.
            try context.append(fields.map { $0 as Any })

            let reply = try await call(message, timeout: timeout)
            context = SystemdTypeContext(message: reply)

            try context.rewind()
            return try context.next()
        }

        public func getProperties(
            destination: String,
            path: String,
            interface: String,
            autoStart: Bool = true,
            timeout: Duration? = nil
        ) async throws -> (any Sendable)? {
            try await callMethod(
                destination: destination,
                path: path,
                interface: "org.freedesktop.DBus.Properties",
                member: "GetAll",
                fields: [interface],
                autoStart: autoStart,
                timeout: timeout
            )
        }

        public func getProperty(
            destination: String,
            path: String,
            interface: String,
            member: String? = nil,
            autoStart: Bool = true,
            timeout: Duration? = nil
        ) async throws -> (any Sendable)? {
            try await callMethod(
                destination: destination,
                path: path,
                interface: "org.freedesktop.DBus.Properties",
                member: "Get",
                fields: [interface, member ?? ""],
                autoStart: autoStart,
                timeout: timeout
            )
        }

        deinit {
            // sd_bus_call_async retains self via Unmanaged.passRetained,
            // so deinit only runs once every outstanding callback has
            // fired and _continuations has drained — no need to cancel
            // here, and we wouldn't be able to from a nonisolated deinit.
            _readSource?.cancel()
            _writeSource?.cancel()
            _timerSource.cancel()
            sd_bus_unref(_bus)
        }
    }

    @_cdecl("_sdBusMessageThunk")
    private func _sdBusMessageThunk(
        _ m: OpaquePointer!,
        _ userdata: UnsafeMutableRawPointer!,
        _: UnsafeMutablePointer<sd_bus_error>!  // not used in async callback
    ) -> CInt {
        let bus = Unmanaged<SystemdBus>.fromOpaque(userdata!).takeRetainedValue()
        let message = SystemdMessage(borrowing: m)
        Task { await  bus._resume(with: message) }
        return 1
    }

    extension Duration {
        /// The duration as an sd-bus `usec_t` timeout, rounded up to whole microseconds.
        /// 0 means "the default" to sd-bus, so a zero or negative duration is 1 µs, and
        /// one too long for `usec_t` is `UINT64_MAX`, which sd-bus treats as no timeout.
        var sdBusMicroseconds: UInt64 {
            guard self > .zero else { return 1 }
            let (seconds, attoseconds) = components
            let attosecondsPerMicrosecond: Int64 = 1_000_000_000_000
            let fraction = (attoseconds + attosecondsPerMicrosecond - 1) / attosecondsPerMicrosecond
            let (whole, overflow) = UInt64(seconds).multipliedReportingOverflow(by: 1_000_000)
            let (usec, carry) = whole.addingReportingOverflow(UInt64(fraction))
            return overflow || carry ? .max : usec
        }
    }

#endif
