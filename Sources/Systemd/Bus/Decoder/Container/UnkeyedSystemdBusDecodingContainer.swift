// SPDX-License-Identifier: MIT

struct UnkeyedSystemdBusDecodingContainer: UnkeyedDecodingContainer {
    let context: SystemdBusTypeContext
    let codingPath: [any CodingKey]
    var count: Int?  // currently this is not set but it could be for trivial types

    private(set) var currentIndex: Int = 0

    var isAtEnd: Bool {
        if let count {
            currentIndex == count
        } else {
            context.isAtEnd
        }
    }

    init(context: SystemdBusTypeContext, codingPath: [any CodingKey], count: Int?) {
        self.context = context
        self.codingPath = codingPath
        self.count = count
    }

    mutating func nestedContainer<NestedKey>(
        keyedBy type: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        .init(
            KeyedSystemdBusDecodingContainer<NestedKey>(
                context: context,
                codingPath: codingPath
            ))
    }

    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        UnkeyedSystemdBusDecodingContainer(context: context, codingPath: codingPath, count: nil)
    }

    mutating func superDecoder() throws -> any Decoder {
        SystemdBusDecoderImpl(context: context, codingPath: codingPath)
    }

    mutating func decodeNil() throws -> Bool {
        try context.decodeNil()
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool {
        try _decode(type)
    }

    mutating func decode(_ type: String.Type) throws -> String {
        try _decode(type)
    }

    mutating func decode(_ type: Double.Type) throws -> Double {
        try _decode(type)
    }

    mutating func decode(_ type: Float.Type) throws -> Float {
        try Float(_decode(Double.self))
    }

    mutating func decode(_ type: Int.Type) throws -> Int {
        if MemoryLayout<Int>.size == 8 {
            try Int(decode(Int64.self))
        } else {
            try Int(decode(Int32.self))
        }
    }

    mutating func decode(_ type: Int8.Type) throws -> Int8 {
        try Int8(bitPattern: decode(UInt8.self))
    }

    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        try context.decode(type)
    }

    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        try context.decode(type)
    }

    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        try context.decode(type)
    }

    mutating func decode(_ type: UInt.Type) throws -> UInt {
        if MemoryLayout<UInt>.size == 8 {
            try UInt(decode(UInt64.self))
        } else {
            try UInt(decode(UInt32.self))
        }
    }

    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        try _decode(type)
    }

    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        try _decode(type)
    }

    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        try _decode(type)
    }

    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        try _decode(type)
    }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try SystemdBusTypeContext.decode(type, context: context, codingPath: codingPath)
    }

    private mutating func _decode<T: SystemdBusTypeRepresentable>(_ type: T.Type) throws -> T {
        let value: T

        value = try context.decode(type)
        currentIndex += 1

        return value
    }
}
