#if os(Linux)
import Glibc
#endif
@_implementationOnly import CSystemd

public enum ServiceState: String {
    case Ready = "READY=1"
    case Stopping = "STOPPING=1"
}

public struct SystemdNotifier {
    public init() {
        // Do nothing
    }

    public func notify(_ state: ServiceState) {
        sd_notify(0, state.rawValue)
    }
}
