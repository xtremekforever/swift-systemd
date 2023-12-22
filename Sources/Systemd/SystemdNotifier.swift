#if os(Linux)
@_implementationOnly import CSystemd
#endif

public enum ServiceState: String {
    case Ready = "READY=1"
    case Stopping = "STOPPING=1"
}

public struct SystemdNotifier {
    public init() {
        // Do nothing
    }

    public func notify(_ state: ServiceState) {
        #if os(Linux)
        sd_notify(0, state.rawValue)
        #endif
    }
}
