#if os(Linux)
    import CSystemd
    import XCTest

    @testable import Systemd

    final class TypeTests: XCTestCase {
        private func char(_ c: Unicode.Scalar) -> CChar { CChar(UInt8(ascii: c)) }

        /// A sealed message holding a variant of `a(isb)` and one of `a(iiay)`, as
        /// systemd-resolved's Domains and DNS properties are.
        private func message() async throws -> SystemdMessage {
            let bus: SystemdBus
            do {
                bus = try SystemdBus.system
            } catch {
                throw XCTSkip("no system bus: \(error)")
            }
            let message = try await bus.newMethodCall(
                destination: "a.b", path: "/a/b", interface: "a.b", member: "C", autoStart: true
            )
            try message.withMessagePointer { m in
                var r = sd_bus_message_open_container(m, char("v"), "a(isb)")
                r = r < 0 ? r : sd_bus_message_open_container(m, char("a"), "(isb)")
                for (ifindex, name, routeOnly) in [(0, "example.com", false), (3, "~.", true)] {
                    var i = Int32(ifindex), b = Int32(routeOnly ? 1 : 0)
                    r = r < 0 ? r : sd_bus_message_open_container(m, char("r"), "isb")
                    r = r < 0 ? r : sd_bus_message_append_basic(m, char("i"), &i)
                    r = r < 0 ? r : name.withCString { sd_bus_message_append_basic(m, char("s"), $0) }
                    r = r < 0 ? r : sd_bus_message_append_basic(m, char("b"), &b)
                    r = r < 0 ? r : sd_bus_message_close_container(m)
                }
                r = r < 0 ? r : sd_bus_message_close_container(m)
                r = r < 0 ? r : sd_bus_message_close_container(m)

                r = r < 0 ? r : sd_bus_message_open_container(m, char("v"), "a(iiay)")
                r = r < 0 ? r : sd_bus_message_open_container(m, char("a"), "(iiay)")
                var i = Int32(2), family = Int32(AF_INET)
                let address: [UInt8] = [192, 0, 2, 1]
                r = r < 0 ? r : sd_bus_message_open_container(m, char("r"), "iiay")
                r = r < 0 ? r : sd_bus_message_append_basic(m, char("i"), &i)
                r = r < 0 ? r : sd_bus_message_append_basic(m, char("i"), &family)
                r = r < 0 ? r : address.withUnsafeBytes {
                    sd_bus_message_append_array(m, char("y"), $0.baseAddress, $0.count)
                }
                r = r < 0 ? r : sd_bus_message_close_container(m)
                r = r < 0 ? r : sd_bus_message_close_container(m)
                r = r < 0 ? r : sd_bus_message_close_container(m)
                return r < 0 ? r : sd_bus_message_seal(m, 1, 0)
            }
            return message
        }

        func testArraysOfStructs() async throws {
            let context = SystemdTypeContext(message: try await message())
            try context.rewind()

            let domains = try XCTUnwrap(context.next() as? [any Sendable])
            XCTAssertEqual(domains.count, 2)
            let first = try XCTUnwrap(domains[0] as? [any Sendable])
            XCTAssertEqual(first[0] as? Int32, 0)
            XCTAssertEqual(first[1] as? String, "example.com")
            XCTAssertEqual(first[2] as? Bool, false)
            let second = try XCTUnwrap(domains[1] as? [any Sendable])
            XCTAssertEqual(second[0] as? Int32, 3)
            XCTAssertEqual(second[1] as? String, "~.")
            XCTAssertEqual(second[2] as? Bool, true)

            let servers = try XCTUnwrap(context.next() as? [any Sendable])
            let server = try XCTUnwrap(servers.first as? [any Sendable])
            XCTAssertEqual(server[0] as? Int32, 2)
            XCTAssertEqual(server[1] as? Int32, Int32(AF_INET))
            XCTAssertEqual(server[2] as? [UInt8], [192, 0, 2, 1])

            XCTAssertNil(try context.next())
        }
    }
#endif
