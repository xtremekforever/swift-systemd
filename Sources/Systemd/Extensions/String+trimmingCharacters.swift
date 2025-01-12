//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

extension String {
    // NOTE: This is copied from the FoundationEssentials module while we still don't
    // have an official .trimmingCharacters method provided by FoundationEssentials.
    // https://github.com/swiftlang/swift-foundation/tree/main/Sources/FoundationEssentials/String/BidirectionalCollection.swift#L37
    func trimmingCharacters(while predicate: (Element) -> Bool) -> SubSequence {
        var idx = startIndex
        while idx < endIndex && predicate(self[idx]) {
            formIndex(after: &idx)
        }

        let startOfNonTrimmedRange = idx  // Points at the first char not in the set
        guard startOfNonTrimmedRange != endIndex else {
            return self[endIndex...]
        }

        let beforeEnd = index(before: endIndex)
        guard startOfNonTrimmedRange < beforeEnd else {
            return self[startOfNonTrimmedRange..<endIndex]
        }

        var backIdx = beforeEnd
        // No need to bound-check because we've already trimmed from the beginning, so we'd definitely break off of this loop before `backIdx` rewinds before `startIndex`
        while predicate(self[backIdx]) {
            formIndex(before: &backIdx)
        }
        return self[startOfNonTrimmedRange...backIdx]
    }
}
