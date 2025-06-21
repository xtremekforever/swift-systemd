#if os(Linux)
    import CSystemd
    import Dispatch
    import Glibc

    public final class SystemdBus {
        private typealias Continuation = CheckedContinuation<SystemdMessage, Error>

        private let _bus: OpaquePointer
        private let _continuations = ManagedCriticalState<[UInt64: Continuation]>([:])
        private var _readSource: DispatchSourceRead?
        private var _writeSource: DispatchSourceWrite?

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

        private var events: CInt {
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

        init(bus: OpaquePointer) throws {
            _bus = sd_bus_ref(bus)

            let fd = try throwingSystemdBusError {
                sd_bus_get_fd(_bus)
            }

            if try events & POLLIN != 0 {
                let readSource = DispatchSource.makeReadSource(fileDescriptor: fd)
                readSource.setEventHandler { [weak self] in
                    while (try? self?._process()) ?? false {}
                }
                _readSource = readSource
                readSource.resume()
            }

            if try events & POLLOUT != 0 {
                let writeSource = DispatchSource.makeWriteSource(fileDescriptor: fd)
                writeSource.setEventHandler { [weak self] in
                    while (try? self?._process()) ?? false {}
                }
                _writeSource = writeSource
                writeSource.resume()
            }
        }

        public var isOpen: Bool {
            sd_bus_is_open(_bus) != 0
        }

        fileprivate func _resume(with message: SystemdMessage) -> Bool {
            var continuation: Continuation?

            guard let cookie = try? message.replyCookie else {
                return false
            }

            _continuations.withCriticalRegion { continuations in
                continuation = continuations[cookie]
                continuations[cookie] = nil
            }

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
            _continuations.withCriticalRegion { continuations in
                for continuation in continuations.values {
                    continuation.resume(throwing: CancellationError())
                }
                continuations.removeAll()
            }
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
                    UInt64(timeout?.usec ?? 0)
                )
            }

            return try await withCheckedThrowingContinuation { continuation in
                _continuations.withCriticalRegion { continuations in
                    try! continuations[message.cookie] = continuation
                }
            }
        }

        public func callMethod(
            destination: String,
            path: String,
            interface: String,
            member: String,
            fields: [Any] = [],
            timeout: Duration? = nil
        ) async throws -> Any? {
            var message: SystemdMessage!

            try throwingSystemdBusError {
                var m: OpaquePointer!
                let r = sd_bus_message_new_method_call(
                    _bus,
                    &m,
                    destination,
                    path,
                    interface,
                    member
                )
                guard r >= 0 else { return r }
                message = SystemdMessage(consuming: m)
                return 0
            }

            precondition(message != nil)

            var context = SystemdTypeContext(message: message)
            try context.append(fields)

            let reply = try await call(message, timeout: timeout)
            context = SystemdTypeContext(message: reply)

            try context.rewind()
            return try context.next()
        }

        public func getProperties(
            destination: String,
            path: String,
            interface: String
        ) async throws -> Any? {
            let properties = try await callMethod(
                destination: destination,
                path: path,
                interface: "org.freedesktop.DBus.Properties",
                member: "GetAll",
                fields: [interface]
            )
            return properties
        }

        public func getProperty(
            destination: String,
            path: String,
            interface: String,
            member: String? = nil
        ) async throws -> Any? {
            let properties = try await callMethod(
                destination: destination,
                path: path,
                interface: "org.freedesktop.DBus.Properties",
                member: "Get",
                fields: [interface, member ?? ""]
            )
            return properties
        }

        deinit {
            _cancelAll()
            _readSource?.cancel()
            _writeSource?.cancel()
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
        return bus._resume(with: SystemdMessage(borrowing: m)) ? 1 : 0
    }

    extension Duration {
        fileprivate var usec: Double {
            let v = components
            return Double(v.seconds) * 10_000_000 + Double(v.attoseconds) * 1e-12
        }
    }

#endif
