#if os(Linux)
    import CSystemd

    public final class SystemdMessage: @unchecked Sendable {
        let _m: OpaquePointer

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
        func withMessagePointer(_ body: (OpaquePointer) -> CInt) throws -> CInt {
            try throwingSystemdBusError {
                body(_m)
            }
        }

        var isMethodError: Bool {
            sd_bus_message_is_method_error(_m, nil) != 0
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

        fileprivate func _dump() {
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
