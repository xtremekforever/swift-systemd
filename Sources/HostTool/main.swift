#if os(Linux)
    import Systemd

    let hostnameInterface = "org.freedesktop.hostname1"

    @main
    enum HostTool {
        static func main() async throws {
            do {
                let bus = try SystemdBus.system

                if let reply = try await bus.getProperty(
                    destination: hostnameInterface,
                    path: "/org/freedesktop/hostname1",
                    interface: hostnameInterface,
                    member: "Hostname"
                ) {
                    print("\(reply)")
                }
            } catch {
                print("error: \(error)")
            }
        }
    }
#else
    @main
    enum HostTool {
        static func main() async throws {
            fatalError("systemd not supported on non-Linux platforms")
        }
    }
#endif
