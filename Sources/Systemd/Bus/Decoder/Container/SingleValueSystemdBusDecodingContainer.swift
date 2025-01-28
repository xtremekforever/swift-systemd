// SPDX-License-Identifier: MIT

struct SingleValueSystemdBusDecodingContainer: SingleValueDecodingContainer {
    let context: SystemdBusTypeContext
    let codingPath: [any CodingKey]

    init(context: SystemdBusTypeContext, codingPath: [any CodingKey] = []) {
        self.context = context
        self.codingPath = codingPath
    }

    func decodeNil() -> Bool { (try? context.decodeNil()) ?? false }

    func decode(_ type: Bool.Type) throws -> Bool { try context.decode(type) }

    func decode(_ type: String.Type) throws -> String { try context.decode(type) }

    func decode(_ type: Double.Type) throws -> Double { try context.decode(type) }

    func decode(_ type: Float.Type) throws -> Float { try Float(context.decode(Double.self)) }

    func decode(_ type: Int.Type) throws -> Int {
        if MemoryLayout<Int>.size == 8 {
            try Int(context.decode(Int64.self))
        } else {
            try Int(context.decode(Int32.self))
        }
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        try Int8(bitPattern: context.decode(UInt8.self))
    }

    func decode(_ type: Int16.Type) throws -> Int16 { try context.decode(type) }

    func decode(_ type: Int32.Type) throws -> Int32 { try context.decode(type) }

    func decode(_ type: Int64.Type) throws -> Int64 { try context.decode(type) }

    func decode(_ type: UInt.Type) throws -> UInt {
        if MemoryLayout<Int>.size == 8 {
            try UInt(context.decode(UInt64.self))
        } else {
            try UInt(context.decode(UInt32.self))
        }
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 { try context.decode(type) }

    func decode(_ type: UInt16.Type) throws -> UInt16 { try context.decode(type) }

    func decode(_ type: UInt32.Type) throws -> UInt32 { try context.decode(type) }

    func decode(_ type: UInt64.Type) throws -> UInt64 { try context.decode(type) }

    func decode<T>(_ type: T.Type) throws -> T
        where T: Decodable { try context.decode(type, codingPath: codingPath) }
}
