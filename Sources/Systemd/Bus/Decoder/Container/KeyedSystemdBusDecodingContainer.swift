// SPDX-License-Identifier: MIT

struct KeyedSystemdBusDecodingContainer<Key>: KeyedDecodingContainerProtocol
where Key: CodingKey {
    let context: SystemdBusTypeContext

    let codingPath: [any CodingKey]
    var allKeys: [Key] { [] }

    init(context: SystemdBusTypeContext, codingPath: [any CodingKey]) {
        self.context = context
        self.codingPath = codingPath
    }

    func contains(_ key: Key) -> Bool {
        // Since the binary representation is untagged, we accept every key
        true
    }

    func nestedContainer<NestedKey>(
        keyedBy type: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        .init(
            KeyedSystemdBusDecodingContainer<NestedKey>(
                context: context,
                codingPath: codingPath + [key]
            ))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        UnkeyedSystemdBusDecodingContainer(context: context, codingPath: codingPath, count: nil)
    }

    func superDecoder() throws -> any Decoder {
        SystemdBusDecoderImpl(context: context, codingPath: codingPath)
    }

    func superDecoder(forKey key: Key) throws -> any Decoder {
        SystemdBusDecoderImpl(context: context, codingPath: codingPath)
    }

    func decodeNil(forKey key: Key) throws -> Bool { try context.decodeNil() }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try _decode(type, forKey: key)
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try _decode(
            type,
            forKey: key
        )
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try _decode(
            type,
            forKey: key
        )
    }

    func decode(
        _ type: Float.Type,
        forKey key: Key
    ) throws -> Float { try Float(_decode(Double.self, forKey: key)) }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        if MemoryLayout<Int>.size == 8 {
            try Int(_decode(Int64.self, forKey: key))
        } else {
            try Int(_decode(Int32.self, forKey: key))
        }
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        try Int8(bitPattern: _decode(UInt8.self, forKey: key))
    }

    func decode(
        _ type: Int16.Type,
        forKey key: Key
    ) throws -> Int16 { try _decode(type, forKey: key) }

    func decode(
        _ type: Int32.Type,
        forKey key: Key
    ) throws -> Int32 { try _decode(type, forKey: key) }

    func decode(
        _ type: Int64.Type,
        forKey key: Key
    ) throws -> Int64 { try _decode(type, forKey: key) }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        if MemoryLayout<Int>.size == 8 {
            try UInt(_decode(UInt64.self, forKey: key))
        } else {
            try UInt(_decode(UInt32.self, forKey: key))
        }
    }

    func decode(
        _ type: UInt8.Type,
        forKey key: Key
    ) throws -> UInt8 { try _decode(type, forKey: key) }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try _decode(
            type,
            forKey: key
        )
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try _decode(
            type,
            forKey: key
        )
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try _decode(
            type,
            forKey: key
        )
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T
    where T: Decodable {
        try _decode(type, forKey: key)
    }

    private func _decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        return try context.decode(type, codingPath: codingPath + [key])
    }
}
