
#if os(Linux)
import Glibc
import CSystemd
#endif

import Foundation

public struct SystemdHelpers {
    public static let isSystemdService: Bool = getIsSystemdService()
    public static let watchdogTimeout: Duration? = getWatchdogTimeout()

    public static var watchdogEnabled: Bool { watchdogTimeout != nil }
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
            return nil // Watchdog disabled
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
