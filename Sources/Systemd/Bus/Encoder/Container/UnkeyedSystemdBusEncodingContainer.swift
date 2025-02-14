// SPDX-License-Identifier: MIT

struct UnkeyedSystemdBusEncodingContainer: UnkeyedEncodingContainer {
    let context: SystemdBusTypeContext
    private(set) var count: Int = 0

    let codingPath: [any CodingKey]

    init(context: SystemdBusTypeContext, codingPath: [any CodingKey]) {
        self.context = context
        self.codingPath = codingPath
    }

    mutating func nestedContainer<NestedKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        .init(
            KeyedSystemdBusEncodingContainer<NestedKey>(
                context: context,
                codingPath: codingPath
            ))
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        UnkeyedSystemdBusEncodingContainer(context: context, codingPath: codingPath)
    }

    mutating func superEncoder() -> Encoder {
        SystemdBusEncoderImpl(context: context, codingPath: codingPath)
    }

    mutating func encodeNil() throws {
        try context.encodeNil()
        count += 1
    }

    mutating func encode(_ value: Bool) throws {
        try _encode(value)
    }

    mutating func encode(_ value: String) throws {
        try _encode(value)
    }

    mutating func encode(_ value: Double) throws {
        try _encode(value)
    }

    mutating func encode(_ value: Float) throws {
        try _encode(Double(value))
    }

    mutating func encode(_ value: Int) throws {
        if MemoryLayout<Int>.size == 8 {
            try _encode(Int64(value))
        } else {
            try _encode(Int32(value))
        }
    }

    mutating func encode(_ value: Int8) throws {
        try _encode(UInt8(bitPattern: value))
    }

    mutating func encode(_ value: Int16) throws {
        try _encode(value)
    }

    mutating func encode(_ value: Int32) throws {
        try _encode(value)
    }

    mutating func encode(_ value: Int64) throws {
        try _encode(value)
    }

    mutating func encode(_ value: UInt) throws {
        if MemoryLayout<UInt>.size == 8 {
            try _encode(UInt64(value))
        } else {
            try _encode(UInt32(value))
        }
    }

    mutating func encode(_ value: UInt8) throws {
        try _encode(value)
    }

    mutating func encode(_ value: UInt16) throws {
        try _encode(value)
    }

    mutating func encode(_ value: UInt32) throws {
        try _encode(value)
    }

    mutating func encode(_ value: UInt64) throws {
        try _encode(value)
    }

    mutating func encode(_ value: some Encodable) throws {
        try _encode(value)
    }

    private mutating func _encode(_ value: some Encodable) throws {
        try context.encode(value, codingPath: codingPath)
        count += 1
    }
}
