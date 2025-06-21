#if canImport(Glibc)
    import Glibc

    /// Compute the prefix sum of `seq`.
    private func scan<S: Sequence, U>(_ seq: S, _ initial: U, _ combine: (U, S.Element) -> U) -> [U] {
        var result: [U] = []
        result.reserveCapacity(seq.underestimatedCount)
        var runningResult = initial
        for element in seq {
            runningResult = combine(runningResult, element)
            result.append(runningResult)
        }
        return result
    }

    func withArrayOfIovecs<R>(_ args: [String], _ body: ([iovec]) -> R) -> R {
        let argsCounts = Array(args.map { $0.utf8.count + 1 })
        let argsOffsets = [0] + scan(argsCounts, 0, +)
        let argsBufferSize = argsOffsets.last!
        var argsBuffer: [UInt8] = []
        argsBuffer.reserveCapacity(argsBufferSize)
        for arg in args {
            argsBuffer.append(contentsOf: arg.utf8)
            argsBuffer.append(0)
        }
        return argsBuffer.withUnsafeMutableBufferPointer {
            argsBuffer in
            let ptr = UnsafeMutableRawPointer(argsBuffer.baseAddress!).bindMemory(
                to: CChar.self, capacity: argsBuffer.count
            )
            let iovecs: [iovec] = zip(argsCounts, argsOffsets).map { count, offset in
                iovec(iov_base: ptr + offset, iov_len: count - 1)
            }
            return body(iovecs)
        }
    }
#endif
