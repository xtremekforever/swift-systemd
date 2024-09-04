
import AsyncAlgorithms
import ServiceLifecycle
import Systemd

public struct SystemdService: Service {
    public init() {}

    public func run() async throws {
        let notifier = SystemdNotifier()

        // Send ready signal at startup
        notifier.notify(ServiceState.Ready)


        // Run the task until cancelled
        let watchdogEnabled = SystemdHelpers.watchdogEnabled
        let interval = SystemdHelpers.watchdogRecommendedNotifyInterval ?? .seconds(3600)
        for await _ in AsyncTimerSequence(interval: interval, clock: .continuous).cancelOnGracefulShutdown() {
            if watchdogEnabled {
                notifier.notify(ServiceState.Watchdog)
            }
        }

        // Notify of stopping before exiting
        notifier.notify(ServiceState.Stopping)
    }
}
