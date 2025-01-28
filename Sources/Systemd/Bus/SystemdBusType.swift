// SPDX-License-Identifier: MIT

public enum SystemdBusType: CChar, Codable, Sendable {
    case _invalid = 0
    case byte = 121
    case boolean = 98
    case int16 = 110
    case uint16 = 113
    case int32 = 105
    case uint32 = 117
    case int64 = 120
    case uint64 = 116
    case double = 100
    case unixFd = 104
    case string = 115
    case objectPath = 111
    case signature = 103
    case array = 97
    case `struct` = 114
    case structBegin = 40
    case structEnd = 41
    case variant = 118
    case dictEntry = 101
    case dictEntryBegin = 123
    case dictEntryEnd = 125

    var isContainer: Bool {
        switch self {
        case .array: true
        case .variant: true
        case .struct: true
        case .dictEntry: true
        default: false
        }
    }

    var isBasic: Bool {
        switch self {
        case .string: true
        case .objectPath: true
        case .signature: true
        case .unixFd: true
        default: isTrivial
        }
    }

    var isTrivial: Bool {
        switch self {
        case .byte: true
        case .boolean: true
        case .int16: true
        case .uint16: true
        case .int32: true
        case .uint32: true
        case .int64: true
        case .uint64: true
        case .double: true
        default: false
        }
    }
}
