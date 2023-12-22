import Systemd

if SystemdHelpers.isSystemdService {
    print("Running as systemd service!")
} else {
    print("Not running as a systemd service...")
}
