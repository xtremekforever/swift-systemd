import Foundation

#if os(Linux)
    import CSystemd
#endif

#if canImport(Glibc)
    import Glibc
#endif

/// Helpers to determine if an app is running as a systemd service and get watchdog information.
public struct SystemdHelpers {
    /// Whether or not the application is running as a systemd service.
    ///
    /// - Returns: `true` if application is supervised by systemd, `false` otherwise.
    public static let isSystemdService: Bool = getIsSystemdService()

    /// Watchdog timeout that is configured in the systemd service file.
    ///
    /// Example: `WatchdogSec=30s`
    ///
    /// - Returns: Watchdog interval as a `Duration`. `nil` if watchdog is not configured.
    public static let watchdogTimeout: Duration? = getWatchdogTimeout()

    /// Whether or not the watchdog is enabled.
    ///
    /// This is a simple variable computed from the `watchdogTimeout` to determine if the
    /// watchdog is enabled for this service.
    ///
    /// - Returns: `true` if watchdog is enabled/configured, `false` otherwise.
    public static var watchdogEnabled: Bool { watchdogTimeout != nil }

    /// Recommended interval to send watchdog notification.
    ///
    /// Defaults to half of the configured watchdog timeout.
    ///
    /// - Returns: `Duration` with the recommended interval, `nil` if not configured.
    public static var watchdogRecommendedNotifyInterval: Duration? { watchdogTimeout.map { $0 / 2 } }

    private static func getIsSystemdService() -> Bool {
        #if os(Linux)
            let pid = Glibc.getppid()
            do {
                let name = try String(contentsOfFile: "/proc/\(pid)/comm")
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                return name == "systemd"
            } catch {
                print("Unable to determine if running systemd: \(error)")
            }
        #endif

        return false
    }

    private static func getWatchdogTimeout() -> Duration? {
        #if os(Linux)
            var usec: UInt64 = 0
            let ret = sd_watchdog_enabled(0, &usec)
            if ret > 0 {
                return .microseconds(usec)
            } else if ret == 0 {
                return nil  // Watchdog disabled
            } else {
                let error = String(cString: strerror(-ret))
                print("Unable to get watchdog configuration: \(error)")
                return nil
            }
        #else
            return nil
        #endif
    }
}
