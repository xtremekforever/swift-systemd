#if os(Linux)
import CSystemd
#endif

public enum ServiceState: String {
    case Ready = "READY=1"
    case Stopping = "STOPPING=1"
    case Watchdog = "WATCHDOG=1"
}

public struct SystemdNotifier {
    public init() { }

    public func notify(_ state: ServiceState) {
        #if os(Linux)
        sd_notify(0, state.rawValue)
        #endif
    }
}
