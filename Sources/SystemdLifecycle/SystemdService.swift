import AsyncAlgorithms
import ServiceLifecycle
import Systemd

/// Simple service to send standard systemd notifications as part of the application lifecycle.
///
/// This struct is implemented as a `ServiceLifecycle` service to be able to be run as part of
/// the service group and report that the application is `Ready`. Then, if the watchdog is enabled,
/// it can automatically send the `Watchdog` notification to systemd on the recommended interval.
/// Finally, during graceful shutdown, the `Stopping` notification is sent to systemd to let it
/// know that the application is shutting down.
///
public struct SystemdService: Service {
    public init() {}

    /// Run the service.
    public func run() async {
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
