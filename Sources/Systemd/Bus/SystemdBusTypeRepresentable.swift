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

// A Swift type that can be represented as a DBus type
protocol SystemdBusTypeRepresentable {
    init(context: SystemdBusTypeContext) throws

    func append(context: SystemdBusTypeContext) throws
}

extension UInt8: SystemdBusTypeRepresentable {
    init(context: SystemdBusTypeContext) throws {
        var tmp = UInt8(0)
        try context.withMessagePointer { m in
            sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_BYTE), &tmp)
        }
        self.init(tmp)
    }

    func append(context: SystemdBusTypeContext) throws {
        var tmp = self
        try context.withMessagePointer { m in
            sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_BYTE), &tmp)
        }
    }
}

extension Bool: SystemdBusTypeRepresentable {
    init(context: SystemdBusTypeContext) throws {
        var tmp = UInt32(0)
        try context.withMessagePointer { m in
            sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_BOOLEAN), &tmp)
        }
        self.init(tmp != 0)
    }

    func append(context: SystemdBusTypeContext) throws {
        var tmp = UInt32(self ? 1 : 0)
        try context.withMessagePointer { m in
            sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_BOOLEAN), &tmp)
        }
    }
}

extension Int32: SystemdBusTypeRepresentable {
    init(context: SystemdBusTypeContext) throws {
        var tmp = Int32(0)
        try context.withMessagePointer { m in
            sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_INT32), &tmp)
        }
        self.init(tmp)
    }

    func append(context: SystemdBusTypeContext) throws {
        var tmp = self
        try context.withMessagePointer { m in
            sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_INT32), &tmp)
        }
    }
}

extension UInt32: SystemdBusTypeRepresentable {
    init(context: SystemdBusTypeContext) throws {
        var tmp = UInt32(0)
        try context.withMessagePointer { m in
            sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_UINT32), &tmp)
        }
        self.init(tmp)
    }

    func append(context: SystemdBusTypeContext) throws {
        var tmp = self
        try context.withMessagePointer { m in
            sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_UINT32), &tmp)
        }
    }
}

extension FileDescriptor: SystemdBusTypeRepresentable {
    init(context: SystemdBusTypeContext) throws {
        var tmp = CInt(0)
        try context.withMessagePointer { m in
            sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_UNIX_FD), &tmp)
        }
        self.init(rawValue: tmp)
    }

    func append(context: SystemdBusTypeContext) throws {
        var tmp = rawValue
        try context.withMessagePointer { m in
            sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_UNIX_FD), &tmp)
        }
    }
}

extension Int16: SystemdBusTypeRepresentable {
    init(context: SystemdBusTypeContext) throws {
        var tmp = Int16(0)
        try context.withMessagePointer { m in
            sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_INT16), &tmp)
        }
        self.init(tmp)
    }

    func append(context: SystemdBusTypeContext) throws {
        var tmp = self
        try context.withMessagePointer { m in
            sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_INT16), &tmp)
        }
    }
}

extension UInt16: SystemdBusTypeRepresentable {
    init(context: SystemdBusTypeContext) throws {
        var tmp = UInt16(0)
        try context.withMessagePointer { m in
            sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_UINT16), &tmp)
        }
        self.init(tmp)
    }

    func append(context: SystemdBusTypeContext) throws {
        var tmp = self
        try context.withMessagePointer { m in
            sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_UINT16), &tmp)
        }
    }
}

extension Int64: SystemdBusTypeRepresentable {
    init(context: SystemdBusTypeContext) throws {
        var tmp = Int64(0)
        try context.withMessagePointer { m in
            sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_INT64), &tmp)
        }
        self.init(tmp)
    }

    func append(context: SystemdBusTypeContext) throws {
        var tmp = self
        try context.withMessagePointer { m in
            sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_INT64), &tmp)
        }
    }
}

extension UInt64: SystemdBusTypeRepresentable {
    init(context: SystemdBusTypeContext) throws {
        var tmp = UInt64(0)
        try context.withMessagePointer { m in
            sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_UINT64), &tmp)
        }
        self.init(tmp)
    }

    func append(context: SystemdBusTypeContext) throws {
        var tmp = self
        try context.withMessagePointer { m in
            sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_UINT64), &tmp)
        }
    }
}

extension Double: SystemdBusTypeRepresentable {
    init(context: SystemdBusTypeContext) throws {
        var tmp = Double(0.0)
        try context.withMessagePointer { m in
            sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_DOUBLE), &tmp)
        }
        self.init(tmp)
    }

    func append(context: SystemdBusTypeContext) throws {
        var tmp = self
        try context.withMessagePointer { m in
            sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_DOUBLE), &tmp)
        }
    }
}

extension String: SystemdBusTypeRepresentable {
    init(context: SystemdBusTypeContext) throws {
        var tmp: UnsafeMutablePointer<CChar>!
        try context.withMessagePointer { m in
            sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_STRING), &tmp)
        }
        self.init(cString: tmp)
    }

    func append(context: SystemdBusTypeContext) throws {
        _ = try withCString { tmp in
            try context.withMessagePointer { m in
                sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_STRING), tmp)
            }
        }
    }
}

public struct ObjectPath: SystemdBusTypeRepresentable, Codable {
    public let path: String

    public init(path: String) {
        self.path = path
    }

    init(context: SystemdBusTypeContext) throws {
        var tmp: UnsafeMutablePointer<CChar>!
        try context.withMessagePointer { m in
            sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_OBJECT_PATH), &tmp)
        }
        self.init(path: String(cString: tmp))
    }

    func append(context: SystemdBusTypeContext) throws {
        _ = try path.withCString { tmp in
            try context.withMessagePointer { m in
                sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_OBJECT_PATH), tmp)
            }
        }
    }
}

public struct Signature: SystemdBusTypeRepresentable, Codable {
    public let signature: String

    public init(signature: String) {
        self.signature = signature
    }

    init(context: SystemdBusTypeContext) throws {
        var tmp: UnsafeMutablePointer<CChar>!
        try context.withMessagePointer { m in
            sd_bus_message_read_basic(m, CChar(SD_BUS_TYPE_SIGNATURE), &tmp)
        }
        self.init(signature: String(cString: tmp))
    }

    func append(context: SystemdBusTypeContext) throws {
        _ = try signature.withCString { tmp in
            try context.withMessagePointer { m in
                sd_bus_message_append_basic(m, CChar(SD_BUS_TYPE_SIGNATURE), tmp)
            }
        }
    }
}

fileprivate extension SystemdBusTypeContext {
    func _peekSwiftType() throws -> SystemdBusTypeRepresentable.Type? {
        let (_, systemdBusType, _) = try _peekType()
        return _systemdTypeToSwiftType(systemdBusType)
    }
}

public struct Variant: SystemdBusTypeRepresentable, Codable {
    public let value: any Codable

    public init(value: any Codable) {
        self.value = value
    }

    init(context: SystemdBusTypeContext) throws {
        try context.enterContainer()
        defer { try? context.exitContainer() }

        guard let swiftType = try context._peekSwiftType() as? any Codable.Type else {
            throw SystemdBusError(code: EBADMSG)
        }

        try self.init(value: SystemdBusTypeContext.decode(
            swiftType,
            context: context,
            codingPath: []
        ))
    }

    func append(context: SystemdBusTypeContext) throws {
        let typeOfElement = _typeOfAnyValue(value)

        try context.openContainer(type: .variant, contents: [typeOfElement])
        try SystemdBusTypeContext.encode(value, context: context, codingPath: [])
        try context.closeContainer()
    }

    // TODO: implement for other encoders

    public func encode(to encoder: Encoder) throws {
        throw SystemdBusError(code: ENOSYS)
    }

    public init(from decoder: Decoder) throws {
        throw SystemdBusError(code: ENOSYS)
    }
}

func _typeOfAnyValue(_ value: some Any) -> SystemdBusType {
    if let value = value as? SystemdBusTypeRepresentable {
        _typeOfSystemdValue(value)
    } else {
        .struct
    }
}

func _typeOfSystemdValue(_ value: some SystemdBusTypeRepresentable) -> SystemdBusType {
    _swiftTypeToSystemdType(type(of: value))
}

func _swiftTypeToSystemdType<T: Codable>(_ type: T.Type) -> SystemdBusType {
    if let type = T.self as? SystemdBusTypeRepresentable.Type {
        _swiftTypeToSystemdType(type)
    } else if type is (any SystemdBusArrayRepresentable).Type {
        .array
    } else {
        .struct
    }
}

func _swiftTypeToSystemdType(_ type: (some SystemdBusTypeRepresentable).Type) -> SystemdBusType {
    switch type {
    case is UInt8.Type:
        .byte
    case is Bool.Type:
        .boolean
    case is Int32.Type:
        .int32
    case is UInt32.Type:
        .uint32
    case is FileDescriptor.Type:
        .unixFd
    case is Int16.Type:
        .int16
    case is UInt16.Type:
        .uint16
    case is Int64.Type:
        .int64
    case is UInt64.Type:
        .uint64
    case is Double.Type:
        .double
    case is String.Type:
        .string
    case is ObjectPath.Type:
        .objectPath
    case is Signature.Type:
        .signature
    case is Variant.Type:
        .variant
    default:
        .struct
    }
}

func _systemdTypeToSwiftType(_ type: SystemdBusType) -> SystemdBusTypeRepresentable.Type? {
    switch type {
    case .byte:
        UInt8.self
    case .boolean:
        Bool.self
    case .int32:
        Int32.self
    case .uint32:
        UInt32.self
    case .unixFd:
        FileDescriptor.self
    case .int16:
        Int16.self
    case .uint16:
        UInt16.self
    case .int64:
        Int64.self
    case .uint64:
        UInt64.self
    case .double:
        Double.self
    case .string:
        String.self
    case .objectPath:
        ObjectPath.self
    case .signature:
        Signature.self
    case .variant:
        Variant.self
    default:
        nil
    }
}

#endif
