// SPDX-License-Identifier: MIT

struct KeyedSystemdBusEncodingContainer<Key>: KeyedEncodingContainerProtocol
where Key: CodingKey {
    let context: SystemdBusTypeContext
    let codingPath: [any CodingKey]

    init(context: SystemdBusTypeContext, codingPath: [any CodingKey]) {
        self.context = context
        self.codingPath = codingPath
    }

    mutating func nestedContainer<NestedKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        .init(
            KeyedSystemdBusEncodingContainer<NestedKey>(
                context: context,
                codingPath: codingPath + [key]
            ))
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
        UnkeyedSystemdBusEncodingContainer(context: context, codingPath: codingPath + [key])
    }

    mutating func superEncoder() -> Encoder {
        SystemdBusEncoderImpl(context: context, codingPath: codingPath)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        SystemdBusEncoderImpl(context: context, codingPath: codingPath)
    }

    mutating func encodeNil(forKey key: Key) throws { try context.encodeNil() }

    mutating func encode(_ value: Bool, forKey key: Key) throws { try context.encode(value) }

    mutating func encode(_ value: String, forKey key: Key) throws { try context.encode(value) }

    mutating func encode(_ value: Double, forKey key: Key) throws { try context.encode(value) }

    mutating func encode(_ value: Float, forKey key: Key) throws {
        try context.encode(Double(value))
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
        if MemoryLayout<Int>.size == 8 {
            try context.encode(Int64(value))
        } else {
            try context.encode(Int32(value))
        }
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
        try context.encode(UInt8(bitPattern: value))
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws { try context.encode(value) }

    mutating func encode(_ value: Int32, forKey key: Key) throws { try context.encode(value) }

    mutating func encode(_ value: Int64, forKey key: Key) throws { try context.encode(value) }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
        if MemoryLayout<UInt>.size == 8 {
            try context.encode(UInt64(value))
        } else {
            try context.encode(UInt32(value))
        }
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws { try context.encode(value) }

    mutating func encode(_ value: UInt16, forKey key: Key) throws { try context.encode(value) }

    mutating func encode(_ value: UInt32, forKey key: Key) throws { try context.encode(value) }

    mutating func encode(_ value: UInt64, forKey key: Key) throws { try context.encode(value) }

    mutating func encode(_ value: some Encodable, forKey key: Key) throws {
        try context.encode(value, codingPath: codingPath + [key])
    }

    mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeIfPresent(_ value: (some Encodable)?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}
