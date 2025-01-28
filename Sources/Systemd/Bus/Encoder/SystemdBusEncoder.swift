// SPDX-License-Identifier: MIT

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct SystemdBusEncoder {
    public func encode(_ value: some Encodable, into message: SystemdBusMessage) throws {
        let context = SystemdBusTypeContext(message: message)
        try context.encode(value, codingPath: [])
    }
}
