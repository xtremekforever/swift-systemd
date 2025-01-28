extension Duration {
    var usec: Double {
        let v = components
        return Double(v.seconds) * 10_000_000 + Double(v.attoseconds) * 1e-12
    }
}
