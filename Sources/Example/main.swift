import Logging
import ServiceLifecycle
import Systemd
import SystemdLifecycle

let label = "SystemdExample"
let handler = MultiplexLogHandler([
    StreamLogHandler.standardOutput(label: label),
    SystemdJournalLogHandler(label: label),
])
let logger = Logger(label: label, factory: { _ in handler })

if SystemdHelpers.isSystemdService {
    logger.info("Running as systemd service!")
} else {
    logger.info("Not running as a systemd service...")
}

logger.info("Adding SystemdService to run as part of a ServiceGroup...")
let serviceGroup = ServiceGroup(
    configuration: .init(
        services: [
            .init(service: SystemdService())
        ],
        gracefulShutdownSignals: [.sigterm],
        logger: logger
    )
)

logger.info("Send SIGTERM signal to exit the service")
try await serviceGroup.run()

logger.info("Exiting application...")
