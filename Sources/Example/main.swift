import Logging
import ServiceLifecycle
import Systemd
import SystemdLifecycle

let logger = Logger(label: "Example")

if SystemdHelpers.isSystemdService {
    logger.info("Running as systemd service!")
} else {
    logger.info("Not running as a systemd service...")
}

logger.info("Add SystemdService to run as part of a ServiceGroup...")
logger.info("Send SIGTERM signal to exit the service")
let serviceGroup = ServiceGroup(
    configuration: .init(
        services: [
            .init(service: SystemdService())
        ],
        gracefulShutdownSignals: [.sigterm],
        logger: logger
    )
)
try await serviceGroup.run()

logger.info("Exiting application...")
