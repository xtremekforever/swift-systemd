#if os(Linux)
    import CSystemd
    import XCTest

    @testable import Systemd

    final class BusTests: XCTestCase {
        private func systemBus() throws -> SystemdBus {
            do {
                return try SystemdBus.system
            } catch {
                throw XCTSkip("no system bus: \(error)")
            }
        }

        func testMethodCallsAutoStartUnlessTold() async throws {
            let bus = try systemBus()
            for autoStart in [true, false] {
                let message = try await bus.newMethodCall(
                    destination: "org.freedesktop.DBus",
                    path: "/org/freedesktop/DBus",
                    interface: "org.freedesktop.DBus.Peer",
                    member: "Ping",
                    autoStart: autoStart
                )
                let flag = try message.withMessagePointer { sd_bus_message_get_auto_start($0) }
                XCTAssertEqual(flag != 0, autoStart)
            }
        }

        func testGetPropertyWithoutAutoStart() async throws {
            let bus = try systemBus()
            let features = try await bus.getProperty(
                destination: "org.freedesktop.DBus",
                path: "/org/freedesktop/DBus",
                interface: "org.freedesktop.DBus",
                member: "Features",
                autoStart: false,
                timeout: .seconds(1)
            )
            XCTAssertNotNil(features as? [any Sendable])
        }
    }
#endif
