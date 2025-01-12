import Logging

// Only available on Linux
#if os(Linux)
    import CSystemd

    extension Logger.Level {
        var syslogPriority: CInt {
            switch self {
            case .trace, .debug:
                return LOG_DEBUG
            case .info:
                return LOG_INFO
            case .notice:
                return LOG_NOTICE
            case .warning:
                return LOG_WARNING
            case .error:
                return LOG_ERR
            case .critical:
                return LOG_CRIT
            }
        }
    }
#endif
