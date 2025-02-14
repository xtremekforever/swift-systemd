// SPDX-License-Identifier: MIT

#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

struct SystemdBusDictEntry<Key: Hashable & Codable, Value: Codable>: Codable, Hashable {
    static func == (
        lhs: SystemdBusDictEntry<Key, Value>,
        rhs: SystemdBusDictEntry<Key, Value>
    ) -> Bool {
        guard lhs.key == rhs.key else {
            return false
        }

        return true
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }

    let key: Key
    let value: Value

    init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }
}

extension SystemdBusDictEntry {
    var keyType: Key.Type { Key.self }
    var valueType: Value.Type { Value.self }
}

protocol SystemdBusDictRepresentable<Key, Value>: Collection, Codable {
    associatedtype Key: Codable & Hashable
    associatedtype Value: Codable

    init(setOfDictEntries: Set<SystemdBusDictEntry<Key, Value>>)
    init(from: SystemdBusDecoderImpl) throws

    var count: Int { get }
    func forEach(_ block: (Key, Value) throws -> Void) rethrows
}

extension SystemdBusDictRepresentable {
    var keyType: Key.Type { Key.self }
    var valueType: Value.Type { Value.self }
}

extension Dictionary: SystemdBusDictRepresentable where Key: Codable & Hashable, Value: Codable {
    init(setOfDictEntries set: Set<SystemdBusDictEntry<Key, Value>>) {
        self = Dictionary(
            uniqueKeysWithValues: set.map {
                ($0.key, $0.value)
            })
    }

    init(from systemdBusDecoder: SystemdBusDecoderImpl) throws {
        try self
            .init(setOfDictEntries: Set<SystemdBusDictEntry<Key, Value>>(from: systemdBusDecoder))
    }

    func forEach(_ block: (Key, Value) throws -> Void) rethrows {
        for (key, value) in self {
            try block(key, value)
        }
    }
}
