
import AsyncAlgorithms
import ServiceLifecycle
import Systemd

public struct SystemdService: Service {
    private let _watchdogEnabled: Bool
    private let _watchdogInterval: Duration

    public init(watchdogEnabled: Bool = false,
                watchdogInterval: Duration = .seconds(5)) {
        _watchdogEnabled = watchdogEnabled
        _watchdogInterval = watchdogInterval
    }

    public func run() async throws {
        let notifier = SystemdNotifier()

        // Send ready signal at startup
        notifier.notify(ServiceState.Ready)

        // Run the task until cancelled
        for await _ in AsyncTimerSequence(interval: _watchdogInterval, clock: .continuous).cancelOnGracefulShutdown() {
            if _watchdogEnabled {
                notifier.notify(ServiceState.Watchdog)
            }
        }

        // Notify of stopping before exiting
        notifier.notify(ServiceState.Stopping)
    }
}
