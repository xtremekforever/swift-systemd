// SPDX-License-Identifier: MIT

#if os(Linux)
    import CSystemd
    import Glibc
    import SystemPackage

    #if canImport(FoundationEssentials)
        import FoundationEssentials
    #else
        import Foundation
    #endif

    public struct SystemdBusError: Error {
        public let code: Errno
        public let name: String?
        public let message: String?

        init(code: CInt, name: String? = nil, message: String? = nil) {
            self.code = Errno(rawValue: CInt(code.magnitude))
            self.name = name
            self.message = message
        }

        init(code: CInt, error e: UnsafePointer<sd_bus_error>?) {
            var _name: String?
            var _message: String?

            if let e {
                if let name = e.pointee.name { _name = String(cString: name) }
                if let message = e.pointee.message { _message = String(cString: message) }
            }

            self.init(code: code, name: _name, message: _message)
        }

        init(message: SystemdBusMessage) {
            self.init(
                code: sd_bus_message_get_errno(message._m),
                error: sd_bus_message_get_error(message._m)
            )
        }
    }

    @discardableResult
    func throwingSystemdBusError(_ body: () throws -> CInt) throws -> CInt {
        let r = try body()
        if r < 0 {
            throw SystemdBusError(code: r)
        }
        return r
    }

    func throwingSystemdBusError(
        _ body: (UnsafeMutablePointer<sd_bus_error>) -> CInt
    ) throws {
        var e = sd_bus_error()
        defer { sd_bus_error_free(&e) }
        let r = body(&e)
        if r < 0 {
            throw SystemdBusError(code: r, error: &e)
        }
    }

#endif
