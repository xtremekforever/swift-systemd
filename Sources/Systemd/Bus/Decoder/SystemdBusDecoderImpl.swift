// SPDX-License-Identifier: MIT

import Glibc
import SystemPackage

/// A (contextful) binary decoder.
struct SystemdBusDecoderImpl: Decoder {
    let context: SystemdBusTypeContext
    let codingPath: [any CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }
    var count: Int?  // TODO: implement for trivial types

    init(context: SystemdBusTypeContext, codingPath: [any CodingKey], count: Int? = nil) {
        self.context = context
        self.codingPath = codingPath
        self.count = count
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
    where Key: CodingKey {
        .init(KeyedSystemdBusDecodingContainer(context: context, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        UnkeyedSystemdBusDecodingContainer(context: context, codingPath: codingPath, count: count)
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        SingleValueSystemdBusDecodingContainer(context: context, codingPath: codingPath)
    }
}

extension SystemdBusTypeContext {
    func decode<T: SystemdBusTypeRepresentable>(_ type: T.Type) throws -> T {
        try T(context: self)
    }

    func decodeNil() throws -> Bool {
        // TODO: what do we do here?
        false
    }

    func assertType(_ type: SystemdBusType) throws {
        guard try _peekType().1 == type else {
            throw SystemdBusError(code: EBADMSG)
        }
    }

    var isDecodingDict: Bool {
        currentType == .array && contents?.first == .dictEntryBegin
    }

    func decode<T: Decodable>(_ type: T.Type, codingPath: [any CodingKey]) throws -> T {
        try Self.decode(type, context: self, codingPath: codingPath)
    }

    static func decode<T: Decodable>(
        _ type: T.Type,
        context: SystemdBusTypeContext,
        codingPath: [any CodingKey]
    ) throws -> T {
        let value: T

        if let type = type as? SystemdBusTypeRepresentable.Type {
            value = try context.decode(type) as! T
        } else {
            try context.enterContainer()
            if context.isDecodingDict {
                fatalError()
            } else {
                value = try T(from: SystemdBusDecoderImpl(context: context, codingPath: codingPath))
            }
            try context.exitContainer()
        }

        return value
    }
}
