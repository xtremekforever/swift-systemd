// SPDX-License-Identifier: MIT

protocol SystemdBusArrayRepresentable: Collection, Codable where Element: Codable {
    var count: Int { get }

    init(_ elements: [Self.Element])

    func forEach(_ body: (Self.Element) throws -> ()) rethrows
}

extension SystemdBusArrayRepresentable {
    var elementType: Element.Type {
        Element.self
    }
}

extension Array: SystemdBusArrayRepresentable where Element: Codable {}
