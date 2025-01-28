// SPDX-License-Identifier: MIT

struct SystemdBusEncoderImpl: Encoder {
    private let context: SystemdBusTypeContext

    let codingPath: [any CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    init(context: SystemdBusTypeContext, codingPath: [any CodingKey]) {
        self.context = context
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key>
        where Key: CodingKey
    {
        .init(KeyedSystemdBusEncodingContainer(context: context, codingPath: codingPath))
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        UnkeyedSystemdBusEncodingContainer(context: context, codingPath: codingPath)
    }

    func singleValueContainer() -> any SingleValueEncodingContainer {
        SingleValueSystemdBusEncodingContainer(context: context, codingPath: codingPath)
    }
}

extension SystemdBusTypeContext {
    func encode(_ value: SystemdBusTypeRepresentable) throws {
        try value.append(context: self)
    }

    func encodeNil() throws {}

    func encode(_ value: some Encodable, codingPath: [any CodingKey]) throws {
        try Self.encode(value, context: self, codingPath: codingPath)
    }

    // TODO: remove this
    private func encodeDict<T: SystemdBusDictRepresentable>(
        _ value: T,
        codingPath: [CodingKey]
    ) throws {
        let (keyType, valueType) = (
            _typeOfAnyValue(T.Key.self),
            _typeOfAnyValue(T.Value.self)
        )

        try openContainer(type: .array, contents: [
            .dictEntryBegin,
            keyType,
            valueType,
            .dictEntryEnd,
        ])

        try value.forEach { key, value in
            try openContainer(type: .dictEntry, contents: [keyType, valueType])
            try Self.encode(key, context: self, codingPath: codingPath)
            try Self.encode(value, context: self, codingPath: codingPath)
            try closeContainer()
        }

        try closeContainer()
    }

    static func encode(
        _ value: some Encodable,
        context: SystemdBusTypeContext,
        codingPath: [any CodingKey]
    ) throws {
        switch value {
        case let value as any SystemdBusTypeRepresentable:
            try context.encode(value)
        case let value as any SystemdBusDictRepresentable:
            let (keyType, valueType) = (
                _typeOfAnyValue(value.keyType),
                _typeOfAnyValue(value.valueType)
            )
            try context.openContainer(
                type: .array,
                contents: [.dictEntryBegin, keyType, valueType, .dictEntryEnd]
            )
            try value.encode(to: SystemdBusEncoderImpl(context: context, codingPath: codingPath))
            try context.closeContainer()
        case let value as any SystemdBusArrayRepresentable:
            // TODO: does this work with nested types?
            try context.openContainer(
                type: .array,
                contents: [_swiftTypeToSystemdType(value.elementType)]
            )
            try value.encode(to: SystemdBusEncoderImpl(context: context, codingPath: codingPath))
            try context.closeContainer()
        default:
            let structContext = try SystemdBusTypeContext(parentContext: context)
            try value.encode(to: SystemdBusEncoderImpl(
                context: structContext,
                codingPath: codingPath
            ))
            try context.merge(structContext: structContext)
        }
    }
}
