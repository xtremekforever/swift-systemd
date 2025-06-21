import Systemd

@main
enum HostTool {
    static func main() async throws {
        #if os(Linux)
            let hostnameInterface = "org.freedesktop.hostname1"
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
        #else
            fatalError("systemd not supported on non-Linux platforms")
        #endif
    }
}
