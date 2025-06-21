#if os(Linux)
    import CSystemd
    import Glibc
    import SystemPackage

    final class SystemdTypeContext {
        private let _message: SystemdMessage
        private var _level = 1
        private var _currentType: CChar = 0
        private var _contents: [CChar]?  // must be NUL terminated

        init(message: SystemdMessage) {
            _message = message
        }

        @discardableResult
        func withMessagePointer(_ body: (OpaquePointer) -> CInt) throws -> CInt {
            try _message.withMessagePointer(body)
        }

        func rewind() throws {
            try withMessagePointer { m in
                sd_bus_message_rewind(m, 1)
            }
        }

        private func _peekType() throws -> (CInt, CChar, [CChar]?) {
            var type: CChar = 0
            var contentsPtr: UnsafePointer<CChar>?
            let contents: [CChar]?

            let r = try withMessagePointer { m in
                sd_bus_message_peek_type(m, &type, &contentsPtr)
            }

            if r > 0, let contentsPtr {
                contents = Array(
                    UnsafeBufferPointer(
                        start: contentsPtr,
                        count: strlen(contentsPtr) + 1
                    ))
            } else {
                contents = nil
            }

            return (r, type, contents)
        }

        private var _isDictionary: Bool {
            if let _contents {
                _contents[0] == SD_BUS_TYPE_DICT_ENTRY_BEGIN
            } else {
                false
            }
        }

        private func _readArray() throws -> [Any] {
            var array = [Any]()

            try enterContainer()

            repeat {
                guard let element = try next() else { break }
                array.append(element)
            } while true

            try exitContainer()

            return array
        }

        private func _readDictionary() throws -> [AnyHashable: Any] {
            let contents = _contents!
            let dictEntrySignature = contents[1..<contents.count - 2] + [0]
            var dict = [AnyHashable: Any]()

            try enterContainer()

            repeat {
                guard
                    try enterContainer(
                        type: CChar(SD_BUS_TYPE_DICT_ENTRY),
                        contents: Array(dictEntrySignature)
                    ) > 0
                else {
                    break
                }
                defer { try? exitContainer() }
                guard let key = try next() as? any Hashable, let value = try next() else {
                    throw SystemdBusError(code: EBADMSG)
                }

                dict[AnyHashable(key)] = value
            } while true

            try exitContainer()

            return dict
        }

        func next() throws -> Any? {
            let r: CInt

            (r, _currentType, _contents) = try _peekType()

            if r == 0 {
                return nil
            }

            var value: Any?

            if _currentType == SD_BUS_TYPE_ARRAY {
                if _isDictionary {
                    value = try _readDictionary()
                } else {
                    value = try _readArray()
                }
            } else {
                guard let swiftType = _systemdTypeToSwiftType(_currentType) else {
                    throw SystemdBusError(code: EBADMSG)
                }

                value = try swiftType.read(context: self)
            }

            // unwrap variants
            if let _value = value as? AnyVariant { value = _value.value }

            return value
        }

        @discardableResult
        func enterContainer(type: CChar? = nil, contents: [CChar]? = nil) throws -> CInt {
            let r = try withMessagePointer { m in
                sd_bus_message_enter_container(m, type ?? _currentType, contents ?? _contents)
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

        private func _appendArray(_ array: [Any]) throws {
            var firstElement = true

            guard !array.isEmpty else {
                throw SystemdBusError(code: EINVAL)
            }

            for element in array {
                guard let element = element as? SystemdTypeRepresentable else {
                    throw SystemdBusError(code: EINVAL)
                }

                if firstElement {
                    guard let elementType = _swiftTypeToSystemdType(element) else {
                        throw SystemdBusError(code: EINVAL)
                    }
                    try openContainer(type: CChar(SD_BUS_TYPE_ARRAY), contents: [elementType])
                    firstElement = false
                }

                try element.append(context: self)
            }

            try closeContainer()
        }

        private func _appendDictionary(_ dict: [AnyHashable: Any]) throws {
            var firstElement = true

            guard !dict.isEmpty else {
                throw SystemdBusError(code: EINVAL)
            }

            for (key, value) in dict {
                guard let key = key.base as? SystemdTypeRepresentable,
                    let keyType = _swiftTypeToSystemdType(key),
                    let value = value as? SystemdTypeRepresentable,
                    let valueType = _swiftTypeToSystemdType(value)
                else {
                    throw SystemdBusError(code: EINVAL)
                }

                if firstElement {
                    try openContainer(
                        type: CChar(SD_BUS_TYPE_ARRAY),
                        contents: [
                            CChar(SD_BUS_TYPE_DICT_ENTRY_BEGIN),
                            keyType,
                            valueType,
                            CChar(SD_BUS_TYPE_DICT_ENTRY_END),
                        ]
                    )
                    firstElement = false
                }

                try openContainer(
                    type: CChar(SD_BUS_TYPE_DICT_ENTRY),
                    contents: [keyType, valueType]
                )
                try key.append(context: self)
                try value.append(context: self)
                try closeContainer()
            }

            try closeContainer()
        }

        func append(_ fields: [Any]) throws {
            for field in fields {
                if let dict = field as? [AnyHashable: Any] {
                    try _appendDictionary(dict)
                } else if let array = field as? [Any] {
                    try _appendArray(array)
                } else if let value = field as? SystemdTypeRepresentable {
                    try value.append(context: self)
                }
            }
        }

        func openContainer(type: CChar, contents: [CChar]) throws {
            try withMessagePointer { m in
                sd_bus_message_open_container(m, type, contents)
            }
            _level += 1
        }

        func closeContainer() throws {
            try withMessagePointer { m in
                sd_bus_message_close_container(m)
            }
            _level -= 1
        }
    }

    protocol SystemdTypeRepresentable {
        static func read(context: SystemdTypeContext) throws -> Self

        func append(context: SystemdTypeContext) throws
    }

    private func _swiftTypeToSystemdType(_ type: SystemdTypeRepresentable) -> CChar? {
        switch type {
        case is UInt8:
            CChar(SD_BUS_TYPE_BYTE)
        case is Bool:
            CChar(SD_BUS_TYPE_INT32)
        case is UInt32:
            CChar(SD_BUS_TYPE_UINT32)
        case is FileDescriptor:
            CChar(SD_BUS_TYPE_UNIX_FD)
        case is Int16:
            CChar(SD_BUS_TYPE_INT16)
        case is UInt16:
            CChar(SD_BUS_TYPE_UINT16)
        case is Int64:
            CChar(SD_BUS_TYPE_INT64)
        case is UInt64:
            CChar(SD_BUS_TYPE_UINT64)
        case is Double:
            CChar(SD_BUS_TYPE_DOUBLE)
        case is String:
            CChar(SD_BUS_TYPE_STRING)
        case is ObjectPath:
            CChar(SD_BUS_TYPE_OBJECT_PATH)
        case is Signature:
            CChar(SD_BUS_TYPE_SIGNATURE)
        case is AnyVariant:
            CChar(SD_BUS_TYPE_VARIANT)
        default:
            nil
        }
    }

    private func _systemdTypeToSwiftType(_ type: CChar) -> SystemdTypeRepresentable.Type? {
        let type = Int(type)

        switch type {
        case SD_BUS_TYPE_BYTE:
            return UInt8.self
        case SD_BUS_TYPE_BOOLEAN:
            return Bool.self
        case SD_BUS_TYPE_INT32:
            return Int32.self
        case SD_BUS_TYPE_UINT32:
            return UInt32.self
        case SD_BUS_TYPE_UNIX_FD:
            return FileDescriptor.self
        case SD_BUS_TYPE_INT16:
            return Int16.self
        case SD_BUS_TYPE_UINT16:
            return UInt16.self
        case SD_BUS_TYPE_INT64:
            return Int64.self
        case SD_BUS_TYPE_UINT64:
            return UInt64.self
        case SD_BUS_TYPE_DOUBLE:
            return Double.self
        case SD_BUS_TYPE_STRING:
            return String.self
        case SD_BUS_TYPE_OBJECT_PATH:
            return ObjectPath.self
        case SD_BUS_TYPE_SIGNATURE:
            return Signature.self
        case SD_BUS_TYPE_VARIANT:
            return AnyVariant.self
        default:
            return nil
        }
    }

    extension AnyHashable: SystemdTypeRepresentable {
        static func read(context: SystemdTypeContext) throws -> Self {
            guard let value = try context.next() as? any Hashable else {
                throw SystemdBusError(code: EBADMSG)
            }
            return Self(value)
        }

        func append(context: SystemdTypeContext) throws {
            guard let value = base as? SystemdTypeRepresentable else {
                throw SystemdBusError(code: EINVAL)
            }
            try value.append(context: context)
        }
    }

    extension UInt8: SystemdTypeRepresentable {
        static func read(context: SystemdTypeContext) throws -> Self {
            var tmp = UInt8(0)
            try context.withMessagePointer { m in
                sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_BYTE), &tmp)
            }
            return Self(tmp)
        }

        func append(context: SystemdTypeContext) throws {
            var tmp = self
            try context.withMessagePointer { m in
                sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_BYTE), &tmp)
            }
        }
    }

    extension Bool: SystemdTypeRepresentable {
        static func read(context: SystemdTypeContext) throws -> Self {
            var tmp = UInt32(0)
            try context.withMessagePointer { m in
                sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_BOOLEAN), &tmp)
            }
            return Self(tmp != 0)
        }

        func append(context: SystemdTypeContext) throws {
            var tmp = UInt32(self ? 1 : 0)
            try context.withMessagePointer { m in
                sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_BOOLEAN), &tmp)
            }
        }
    }

    extension Int32: SystemdTypeRepresentable {
        static func read(context: SystemdTypeContext) throws -> Self {
            var tmp = Int32(0)
            try context.withMessagePointer { m in
                sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_INT32), &tmp)
            }
            return Self(tmp)
        }

        func append(context: SystemdTypeContext) throws {
            var tmp = self
            try context.withMessagePointer { m in
                sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_INT32), &tmp)
            }
        }
    }

    extension UInt32: SystemdTypeRepresentable {
        static func read(context: SystemdTypeContext) throws -> Self {
            var tmp = UInt32(0)
            try context.withMessagePointer { m in
                sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_UINT32), &tmp)
            }
            return Self(tmp)
        }

        func append(context: SystemdTypeContext) throws {
            var tmp = self
            try context.withMessagePointer { m in
                sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_UINT32), &tmp)
            }
        }
    }

    extension FileDescriptor: SystemdTypeRepresentable {
        static func read(context: SystemdTypeContext) throws -> Self {
            var tmp = CInt(0)
            try context.withMessagePointer { m in
                sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_UNIX_FD), &tmp)
            }
            return Self(rawValue: tmp)
        }

        func append(context: SystemdTypeContext) throws {
            var tmp = rawValue
            try context.withMessagePointer { m in
                sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_UNIX_FD), &tmp)
            }
        }
    }

    extension Int16: SystemdTypeRepresentable {
        static func read(context: SystemdTypeContext) throws -> Self {
            var tmp = Int16(0)
            try context.withMessagePointer { m in
                sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_INT16), &tmp)
            }
            return Self(tmp)
        }

        func append(context: SystemdTypeContext) throws {
            var tmp = self
            try context.withMessagePointer { m in
                sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_INT16), &tmp)
            }
        }
    }

    extension UInt16: SystemdTypeRepresentable {
        static func read(context: SystemdTypeContext) throws -> Self {
            var tmp = UInt16(0)
            try context.withMessagePointer { m in
                sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_UINT16), &tmp)
            }
            return Self(tmp)
        }

        func append(context: SystemdTypeContext) throws {
            var tmp = self
            try context.withMessagePointer { m in
                sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_UINT16), &tmp)
            }
        }
    }

    extension Int64: SystemdTypeRepresentable {
        static func read(context: SystemdTypeContext) throws -> Self {
            var tmp = Int64(0)
            try context.withMessagePointer { m in
                sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_INT64), &tmp)
            }
            return Self(tmp)
        }

        func append(context: SystemdTypeContext) throws {
            var tmp = self
            try context.withMessagePointer { m in
                sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_INT64), &tmp)
            }
        }
    }

    extension UInt64: SystemdTypeRepresentable {
        static func read(context: SystemdTypeContext) throws -> Self {
            var tmp = UInt64(0)
            try context.withMessagePointer { m in
                sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_UINT64), &tmp)
            }
            return Self(tmp)
        }

        func append(context: SystemdTypeContext) throws {
            var tmp = self
            try context.withMessagePointer { m in
                sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_UINT64), &tmp)
            }
        }
    }

    extension Double: SystemdTypeRepresentable {
        static func read(context: SystemdTypeContext) throws -> Self {
            var tmp = Double(0.0)
            try context.withMessagePointer { m in
                sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_DOUBLE), &tmp)
            }
            return Self(tmp)
        }

        func append(context: SystemdTypeContext) throws {
            var tmp = self
            try context.withMessagePointer { m in
                sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_DOUBLE), &tmp)
            }
        }
    }

    extension String: SystemdTypeRepresentable {
        static func read(context: SystemdTypeContext) throws -> Self {
            var tmp: UnsafeMutablePointer<CChar>!
            try context.withMessagePointer { m in
                sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_STRING), &tmp)
            }
            return String(cString: tmp)
        }

        func append(context: SystemdTypeContext) throws {
            _ = try withCString { tmp in
                try context.withMessagePointer { m in
                    sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_STRING), tmp)
                }
            }
        }
    }

    public struct ObjectPath: SystemdTypeRepresentable {
        public let path: String

        static func read(context: SystemdTypeContext) throws -> Self {
            var tmp: UnsafeMutablePointer<CChar>!
            try context.withMessagePointer { m in
                sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_OBJECT_PATH), &tmp)
            }
            return Self(path: String(cString: tmp))
        }

        func append(context: SystemdTypeContext) throws {
            _ = try path.withCString { tmp in
                try context.withMessagePointer { m in
                    sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_OBJECT_PATH), tmp)
                }
            }
        }
    }

    public struct Signature: SystemdTypeRepresentable {
        let signature: String

        static func read(context: SystemdTypeContext) throws -> Self {
            var tmp: UnsafeMutablePointer<CChar>!
            try context.withMessagePointer { m in
                sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_SIGNATURE), &tmp)
            }
            return Self(signature: String(cString: tmp))
        }

        func append(context: SystemdTypeContext) throws {
            _ = try signature.withCString { tmp in
                try context.withMessagePointer { m in
                    sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_SIGNATURE), tmp)
                }
            }
        }
    }

    struct AnyVariant: SystemdTypeRepresentable {
        let value: Any

        init(value: Any) {
            self.value = value
        }

        static func read(context: SystemdTypeContext) throws -> Self {
            try context.enterContainer()
            guard let value = try context.next() else { throw SystemdBusError(code: EBADMSG) }
            try context.exitContainer()

            return Self(value: value)
        }

        func append(context: SystemdTypeContext) throws {
            guard let value = value as? SystemdTypeRepresentable,
                let typeOfElement = _swiftTypeToSystemdType(value)
            else {
                throw SystemdBusError(code: EBADMSG)
            }

            try context.openContainer(type: CChar(SD_BUS_TYPE_VARIANT), contents: [typeOfElement])
            try value.append(context: context)
            try context.closeContainer()
        }
    }

#endif
