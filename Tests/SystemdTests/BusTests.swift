#if os(Linux)
    import CSystemd
    import SystemPackage
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

        /// A peer that never answers, so a call to it can only end by timing out.
        private final class SilentPeer: @unchecked Sendable {
            let bus: OpaquePointer
            let name: String

            init() throws {
                var bus: OpaquePointer!
                guard sd_bus_open_user(&bus) >= 0 else { throw XCTSkip("no user bus") }
                var unique: UnsafePointer<CChar>!
                guard sd_bus_get_unique_name(bus, &unique) >= 0 else { throw XCTSkip("no unique name") }
                self.bus = bus
                name = String(cString: unique)
            }

            deinit { sd_bus_flush_close_unref(bus) }
        }

        func testCallsTimeOut() async throws {
            let peer = try SilentPeer()
            let bus = try SystemdBus.user
            let start = ContinuousClock.now
            do {
                _ = try await bus.callMethod(
                    destination: peer.name,
                    path: "/",
                    interface: "org.freedesktop.DBus.Peer",
                    member: "Ping",
                    timeout: .milliseconds(200)
                )
                XCTFail("a silent peer replied")
            } catch let error as SystemdBusError {
                XCTAssertEqual(error.code, .timedOut)
            }
            XCTAssertLessThan(ContinuousClock.now - start, .seconds(2))
            withExtendedLifetime(peer) {}
        }

        func testPrivateConnection() async throws {
            let bus: SystemdBus
            do {
                bus = try SystemdBus.openSystem()
            } catch {
                throw XCTSkip("no system bus: \(error)")
            }
            let id = try await bus.getProperty(
                destination: "org.freedesktop.DBus",
                path: "/org/freedesktop/DBus",
                interface: "org.freedesktop.DBus",
                member: "Features",
                autoStart: false,
                timeout: .seconds(1)
            )
            XCTAssertNotNil(id as? [any Sendable])

            // an idle connection must not keep the process busy
            var before = rusage(), after = rusage()
            getrusage(RUSAGE_SELF.rawValue, &before)
            try await Task.sleep(for: .milliseconds(500))
            getrusage(RUSAGE_SELF.rawValue, &after)
            let cpu = (after.ru_utime.tv_sec - before.ru_utime.tv_sec) * 1_000_000
                + (after.ru_utime.tv_usec - before.ru_utime.tv_usec)
                + (after.ru_stime.tv_sec - before.ru_stime.tv_sec) * 1_000_000
                + (after.ru_stime.tv_usec - before.ru_stime.tv_usec)
            XCTAssertLessThan(cpu, 100_000, "µs of CPU while idle")
            withExtendedLifetime(bus) {}
        }
    }
#endif
