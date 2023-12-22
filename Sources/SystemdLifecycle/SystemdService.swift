
import AsyncAlgorithms
import ServiceLifecycle
import Systemd

public struct SystemdService: Service {
    public init() { }

    public func run() async throws {
        let notifier = SystemdNotifier()

        // Send ready signal at startup
        notifier.notify(ServiceState.Ready)

        // Run the task until cancelled
        for await _ in AsyncTimerSequence(interval: .seconds(5), clock: .continuous).cancelOnGracefulShutdown() {
            // TODO: Implement optional systemd watchdog support here
        }

        // Notify of stopping before exiting
        notifier.notify(ServiceState.Stopping)
    }
}
