// SPDX-License-Identifier: MIT

#if os(Linux)
    import CSystemd
    import Dispatch
    import Glibc
    import SystemPackage

    #if canImport(FoundationEssentials)
        import FoundationEssentials
    #else
        import Foundation
    #endif

    public final class SystemdBus {
        private typealias Continuation = CheckedContinuation<SystemdBusMessage, Error>

        private let _bus: OpaquePointer
        private var _continuations = ManagedCriticalState<[UInt64: Continuation]>([:])
        private var _readSource: DispatchSourceRead!
        private var _writeSource: DispatchSourceWrite!

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
                _readSource = DispatchSource.makeReadSource(fileDescriptor: fd)
                _readSource.setEventHandler { [self] in
                    while (try? _process()) ?? false {}
                }
                _readSource.resume()
            }

            if try events & POLLOUT != 0 {
                _writeSource = DispatchSource.makeWriteSource(fileDescriptor: fd)
                _writeSource.setEventHandler { [self] in
                    while (try? _process()) ?? false {}
                }
                _writeSource.resume()
            }
        }

        public var isOpen: Bool {
            sd_bus_is_open(_bus) != 0
        }

        fileprivate func _resume(with message: SystemdBusMessage) -> Bool {
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
            _ message: SystemdBusMessage,
            timeout: Duration? = nil
        ) async throws -> SystemdBusMessage {
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

        public func callMethod<Reply: Decodable>(
            destination: String,
            path: String,
            interface: String,
            member: String,
            fields: [some Encodable]? = nil,
            timeout: Duration? = nil
        ) async throws -> Reply? {
            var message: SystemdBusMessage!

            try throwingSystemdBusError {
                var m: OpaquePointer!
                let r = sd_bus_message_new_method_call(_bus, &m, destination, path, interface, member)
                guard r >= 0 else { return r }
                message = SystemdBusMessage(consuming: m)
                return 0
            }

            precondition(message != nil)

            if let fields {
                let encoder = SystemdBusEncoder()
                for field in fields {
                    try encoder.encode(field, into: message)
                }
            }

            let reply = try await call(message, timeout: timeout)
            guard !reply.isEmpty else { return nil }

            let context = SystemdBusTypeContext(message: reply)
            try context.rewind()

            let decoder = SystemdBusDecoder()
            return try decoder.decode(Reply.self, from: reply)
        }

        public func getProperties<Reply: Decodable>(
            destination: String,
            path: String,
            interface: String
        ) async throws -> Reply? {
            try await callMethod(
                destination: destination,
                path: path,
                interface: "org.freedesktop.DBus.Properties",
                member: "GetAll",
                fields: [interface]
            )
        }

        public func getProperty<Reply: Decodable>(
            destination: String,
            path: String,
            interface: String,
            member: String? = nil
        ) async throws -> Reply? {
            try await callMethod(
                destination: destination,
                path: path,
                interface: "org.freedesktop.DBus.Properties",
                member: "Get",
                fields: [interface, member ?? ""]
            )
        }

        deinit {
            _cancelAll()
            _readSource.cancel()
            _writeSource.cancel()
            sd_bus_unref(_bus)
        }
    }

    @_cdecl("_sdBusMessageThunk")
    private func _sdBusMessageThunk(
        _ m: OpaquePointer!,
        _ userdata: UnsafeMutableRawPointer!,
        _ ret_error: UnsafeMutablePointer<sd_bus_error>!  // not used in async callback
    ) -> CInt {
        let bus = Unmanaged<SystemdBus>.fromOpaque(userdata!).takeRetainedValue()
        return bus._resume(with: SystemdBusMessage(borrowing: m)) ? 1 : 0
    }

#endif
