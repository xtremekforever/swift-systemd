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

    public final class SystemdBusTypeContext {
        private let _message: SystemdBusMessage
        private var _level = 1

        // TODO: split out encoding and decoding context into an enum or separate class

        private var _currentType: SystemdBusType = ._invalid
        private var _contents: [SystemdBusType]?

        var currentType: SystemdBusType? { _currentType == ._invalid ? nil : _currentType }
        var contents: [SystemdBusType]? { _contents }

        convenience init(parentContext: SystemdBusTypeContext) throws {
            try self.init(_bus: sd_bus_message_get_bus(parentContext._message._m))
        }

        private convenience init(_bus: OpaquePointer) throws {
            try self.init(message: SystemdBusMessage(_bus: _bus))
        }

        init(message: SystemdBusMessage) {
            _message = message
        }

        @discardableResult
        func withMessagePointer(_ body: (OpaquePointer) throws -> CInt) throws -> CInt {
            try _message.withMessagePointer(body)
        }

        func rewindContainer() throws {
            try withMessagePointer { m in
                sd_bus_message_rewind(m, 0)
            }
        }

        func rewind() throws {
            try withMessagePointer { m in
                sd_bus_message_rewind(m, 1)
            }
        }

        var isAtEnd: Bool {
            do {
                let r = try withMessagePointer { m in
                    sd_bus_message_at_end(m, 0)
                }
                return r > 0
            } catch {
                return true
            }
        }

        func _peekType() throws -> (CInt, SystemdBusType, [SystemdBusType]?) {
            var type: CChar = 0
            var contentsPtr: UnsafePointer<CChar>?
            var contents: [SystemdBusType]?

            let r = try withMessagePointer { m in
                sd_bus_message_peek_type(m, &type, &contentsPtr)
            }

            if r > 0, let contentsPtr {
                contents = Array(
                    UnsafeBufferPointer(
                        start: contentsPtr,
                        count: strlen(contentsPtr) + 1
                    )
                ).map { SystemdBusType(rawValue: $0)! }
            } else {
                contents = nil
            }

            contents?.removeLast()  // remove NUL terminator

            return (r, SystemdBusType(rawValue: type)!, contents)
        }

        func _skip(types: [SystemdBusType]) throws {
            try withMessagePointer { m in
                sd_bus_message_skip(m, _mapSystemdBusTypesToString(types)!)
            }
        }
    }

    extension SystemdBusTypeContext {
        @discardableResult
        func enterContainer(
            type: SystemdBusType? = nil,
            contents: [SystemdBusType]? = nil
        ) throws -> CInt {
            let _type: CChar
            let _contentsStr: String?

            (_, _currentType, _contents) = try _peekType()

            _type = (type ?? _currentType).rawValue
            _contentsStr = _mapSystemdBusTypesToString(contents ?? _contents)

            let r = try withMessagePointer { m in
                sd_bus_message_enter_container(m, _type, _contentsStr)
            }
            if r > 0 { _level += 1 }
            return r
        }

        func exitContainer() throws {
            try withMessagePointer { m in
                sd_bus_message_exit_container(m)
            }
            _level -= 1
        }
    }

    extension SystemdBusTypeContext {
        func openContainer(type: SystemdBusType, contents: [SystemdBusType]) throws {
            try withMessagePointer { m in
                sd_bus_message_open_container(m, type.rawValue, _mapSystemdBusTypesToString(contents))
            }
            _level += 1
            _contents = contents
        }

        func closeContainer() throws {
            try withMessagePointer { m in
                sd_bus_message_close_container(m)
            }
            _contents = nil
            _level -= 1
        }
    }

    extension SystemdBusTypeContext {
        private func _copy(from source: SystemdBusTypeContext, all: Bool) throws {
            try withMessagePointer { m in
                try source.withMessagePointer { s in
                    sd_bus_message_copy(m, s, all ? 1 : 0)
                }
            }
        }

        func merge(structContext: SystemdBusTypeContext) throws {
            var types = [SystemdBusType]()

            repeat {
                // TODO: what do we do with the contents?
                let (r, type, _) = try _peekType()
                if r == 0 { break }
                types.append(type)
                try _skip(types: [type])
            } while true

            try openContainer(type: .struct, contents: types)
            try _copy(from: structContext, all: true)
            try closeContainer()
        }
    }

    func _mapSystemdBusTypesToString(_ types: [SystemdBusType]?) -> String? {
        guard let types else { return nil }
        let characters: [UnicodeScalar] =
            types
            .map { UnicodeScalar(UInt8($0.rawValue)) } + [UnicodeScalar(0)]
        return String(String.UnicodeScalarView(characters))
    }

#endif
