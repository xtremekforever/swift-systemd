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

public final class SystemdBusMessage: @unchecked Sendable {
    let _m: OpaquePointer

    convenience init(_bus: OpaquePointer) throws {
        var m: OpaquePointer!

        try throwingSystemdBusError {
            sd_bus_message_new(_bus, &m, UInt8(SD_BUS_MESSAGE_METHOD_CALL))
        }

        self.init(consuming: m)
    }

    init(consuming m: OpaquePointer) {
        _m = m
    }

    init(borrowing m: OpaquePointer) {
        sd_bus_message_ref(m)
        _m = m
    }

    deinit {
        sd_bus_message_unref(_m)
    }

    @discardableResult
    func withMessagePointer(_ body: (OpaquePointer) throws -> CInt) throws -> CInt {
        try throwingSystemdBusError {
            try body(_m)
        }
    }

    var isMethodError: Bool {
        sd_bus_message_is_method_error(_m, nil) != 0
    }

    var isEmpty: Bool {
        sd_bus_message_is_empty(_m) > 0
    }

    var cookie: UInt64 {
        get throws {
            var cookie = UInt64(0)

            _ = try withMessagePointer { m in
                sd_bus_message_get_cookie(m, &cookie)
            }

            return cookie
        }
    }

    var replyCookie: UInt64 {
        get throws {
            var replyCookie = UInt64(0)

            _ = try withMessagePointer { m in
                sd_bus_message_get_reply_cookie(m, &replyCookie)
            }

            return replyCookie
        }
    }

    func dump() {
        _ = try? withMessagePointer {
            sd_bus_message_dump(
                $0,
                nil,
                UInt64(SD_BUS_MESSAGE_DUMP_WITH_HEADER | SD_BUS_MESSAGE_DUMP_SUBTREE_ONLY)
            )
        }
    }
}

#endif
