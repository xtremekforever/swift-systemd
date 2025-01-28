// SPDX-License-Identifier: MIT

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A decoder that decodes Swift structures from a flat binary representation.
public struct SystemdBusDecoder {
    /// Decodes a value from a flat binary representation.
    public func decode<Value>(_ type: Value.Type, from message: SystemdBusMessage) throws -> Value
        where Value: Decodable
    {
        let context = SystemdBusTypeContext(message: message)
        return try SystemdBusTypeContext.decode(type, context: context, codingPath: [])
    }
}
