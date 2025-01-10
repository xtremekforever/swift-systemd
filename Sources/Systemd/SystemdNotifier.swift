#if os(Linux)
    import CSystemd
#endif

/// Enumeration for state strings that can be sent to systemd.
public enum ServiceState: String {
    /// Send when the service is "ready" or in normal operation state.
    case Ready = "READY=1"
    /// Send when the application is exiting, such as during graceful shutdown.
    case Stopping = "STOPPING=1"
    /// Send to kick the systemd watchdog timer. Only useful if `WatchdogSec` is configured.
    case Watchdog = "WATCHDOG=1"
}

/// Send notifications to systemd.
public struct SystemdNotifier {
    public init() {}

    /// Send a notification to systemd.
    ///
    /// For now, all that is supported is calling `sd_notify` to send notifications to systemd.
    ///
    /// - Parameter state: the `ServiceState` string to send in the notification.
    public func notify(_ state: ServiceState) {
        #if os(Linux)
            sd_notify(0, state.rawValue)
        #endif
    }
}
