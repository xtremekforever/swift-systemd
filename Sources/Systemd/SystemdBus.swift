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

public struct SystemdBusError: Error {
    public let code: Errno
    public let name: String?
    public let message: String?

    fileprivate init(code: CInt, name: String? = nil, message: String? = nil) {
        self.code = Errno(rawValue: CInt(code.magnitude))
        self.name = name
        self.message = message
    }

    fileprivate init(code: CInt, error e: UnsafePointer<sd_bus_error>?) {
        var _name: String?
        var _message: String?

        if let e {
            if let name = e.pointee.name { _name = String(cString: name) }
            if let message = e.pointee.message { _message = String(cString: message) }
        }

        self.init(code: code, name: _name, message: _message)
    }

    fileprivate init(message: SystemdMessage) {
        self.init(
            code: sd_bus_message_get_errno(message._m),
            error: sd_bus_message_get_error(message._m)
        )
    }
}

@discardableResult
fileprivate func throwingSystemdBusError(_ body: () -> CInt) throws -> CInt {
    let r = body()
    if r < 0 {
        throw SystemdBusError(code: r)
    }
    return r
}

fileprivate func throwingSystemdBusError(
    _ body: (UnsafeMutablePointer<sd_bus_error>) -> CInt
) throws {
    var e = sd_bus_error()
    defer { sd_bus_error_free(&e) }
    let r = body(&e)
    if r < 0 {
        throw SystemdBusError(code: r, error: &e)
    }
}

final class SystemdSlot: Hashable {
    private let _s: OpaquePointer

    init(consuming s: OpaquePointer) {
        _s = s
    }

    init(borrowing s: OpaquePointer) {
        sd_bus_slot_ref(s)
        _s = s
    }

    deinit {
        sd_bus_slot_unref(_s)
    }

    public func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }

    static func == (_ lhs: SystemdSlot, _ rhs: SystemdSlot) -> Bool {
        lhs === rhs
    }
}

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

final class SystemdTypeContext {
    private let _message: SystemdMessage
    private var _level = 1
    private var _currentType: CChar = 0
    private var _contents: [CChar]? // must be NUL terminated

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
            contents = Array(UnsafeBufferPointer(
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
            guard try enterContainer(
                type: CChar(SD_BUS_TYPE_DICT_ENTRY),
                contents: Array(dictEntrySignature)
            ) > 0 else {
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

            try openContainer(type: CChar(SD_BUS_TYPE_DICT_ENTRY), contents: [keyType, valueType])
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

public final class SystemdBus {
    private typealias Continuation = CheckedContinuation<SystemdMessage, Error>

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
            let r = sd_bus_message_new_method_call(_bus, &m, destination, path, interface, member)
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
        _readSource.cancel()
        _writeSource.cancel()
        sd_bus_unref(_bus)
    }
}

@_cdecl("_sdBusMessageThunk")
fileprivate func _sdBusMessageThunk(
    _ m: OpaquePointer!,
    _ userdata: UnsafeMutableRawPointer!,
    _ ret_error: UnsafeMutablePointer<sd_bus_error>! // not used in async callback
) -> CInt {
    let bus = Unmanaged<SystemdBus>.fromOpaque(userdata!).takeRetainedValue()
    return bus._resume(with: SystemdMessage(borrowing: m)) ? 1 : 0
}

fileprivate extension Duration {
    var usec: Double {
        let v = components
        return Double(v.seconds) * 10_000_000 + Double(v.attoseconds) * 1e-12
    }
}

#endif
