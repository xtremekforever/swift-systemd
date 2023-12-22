import Systemd

if SystemdHelpers.isSystemdService {
    print("Running as systemd service!")
} else {
    print("Not running as a systemd service...")
}

print("Sending Ready state to systemd...")
let notifier = SystemdNotifier()
notifier.notify(ServiceState.Ready)

print("Waiting for a few seconds before exiting...")
try await Task.sleep(nanoseconds: 3 * 1000 * 1000)

print("Sending Stopping state to systemd...")
notifier.notify(ServiceState.Stopping)
