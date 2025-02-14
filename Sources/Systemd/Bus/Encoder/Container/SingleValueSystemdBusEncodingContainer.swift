// SPDX-License-Identifier: MIT

struct SingleValueSystemdBusEncodingContainer: SingleValueEncodingContainer {
    let context: SystemdBusTypeContext

    let codingPath: [any CodingKey]

    init(context: SystemdBusTypeContext, codingPath: [any CodingKey]) {
        self.context = context
        self.codingPath = codingPath
    }

    mutating func encodeNil() throws { try context.encodeNil() }

    mutating func encode(_ value: Bool) throws { try context.encode(value) }

    mutating func encode(_ value: String) throws { try context.encode(value) }

    mutating func encode(_ value: Double) throws { try context.encode(value) }

    mutating func encode(_ value: Float) throws { try context.encode(Double(value)) }

    mutating func encode(_ value: Int) throws {
        if MemoryLayout<Int>.size == 8 {
            try context.encode(Int64(value))
        } else {
            try context.encode(Int32(value))
        }
    }

    mutating func encode(_ value: Int8) throws {
        try context.encode(UInt8(bitPattern: value))
    }

    mutating func encode(_ value: Int16) throws { try context.encode(value) }

    mutating func encode(_ value: Int32) throws { try context.encode(value) }

    mutating func encode(_ value: Int64) throws { try context.encode(value) }

    mutating func encode(_ value: UInt) throws {
        if MemoryLayout<UInt>.size == 8 {
            try context.encode(UInt64(value))
        } else {
            try context.encode(UInt32(value))
        }
    }

    mutating func encode(_ value: UInt8) throws { try context.encode(value) }

    mutating func encode(_ value: UInt16) throws { try context.encode(value) }

    mutating func encode(_ value: UInt32) throws { try context.encode(value) }

    mutating func encode(_ value: UInt64) throws { try context.encode(value) }

    mutating func encode(_ value: some Encodable) throws { try context.encode(value, codingPath: codingPath) }
}
