# Systemd

A simple Swift library to interface with systemd on Linux.

## Installation

Add the following dependency to your `Package.swift` file:

```swift
.package(url: "https://github.com/xtremekforever/swift-systemd.git", from: "0.0.1")
```

Then, add it to your target `dependencies` section like this:

```swift
.product(name: "Systemd", package: "swift-systemd")
```

## Dependencies

Since `systemd` is only supported in Linux, this package is only useable on Linux systems.
It depends on the `libsystemd` headers and library to be built. These can be installed with
the following commands on different distributions:

* Debian/Ubuntu: `sudo apt install libsystemd-dev`
* RHEL/Fedora: `sudo dnf install systemd-devel`
* SUSE/OpenSUSE: `sudo zypper install systemd-devel`

For other distributions, look in the package repositories for a systemd dev package and install it.

## Usage

Take this example systemd service file:

```ini
[Unit]
Description=My Systemd Service

[Service]
Type=notify
WorkingDirectory=/usr/local/bin
ExecStart=/usr/local/bin/MyService
WatchdogSec=30

[Install]
WantedBy=multi-user.target
```

First, add `import Systemd` to the app use the modules provided by this library.

To see if the app is running under systemd, use the `SystemdHelpers` interface:

```swift
if SystemdHelpers.isSystemdService {
    print("This app is running as a systemd service!")

    // do things like modify logging format (if using swift-log) or whatever else is needed.
}
```

To send signals to systemd about the state of the app, use the `SystemdNotifier` interface:

```swift
let notifier = SystemdNotifier()

// Call after starting up app (sends READY=1)
notifier.notify(ServiceState.Ready)

// Call before exiting app (sends STOPPING=1)
notifier.notify(ServiceState.Stopping)
```

### Systemd Lifecycle

This repo also contains a separate `SystemdLifecycle` product that can be used by projects that employ the [swift-service-lifecycle](https://github.com/swift-server/swift-service-lifecycle) library to run and manage application services. It is a simple service that sends the `READY=1` and `STOPPING=1` signals above from the service `run()` method.

It can be used by adding the `SystemdLifecycle` target `dependencies` section like this:

```swift
.product(name: "SystemdLifecycle", package: "swift-systemd")
```

Then, once the product is imported with `import SystemdLifecycle`, it can be added to a `ServiceGroup`:

```swift
let serviceGroup = ServiceGroup(
    configuration: .init(
        services: [
            .init(service: SystemdService())
        ]
    )
)
try await serviceGroup.run()
```

`SystemdService` does not have any dependencies on other services, so it can be constructed and started at any point in the application's service lifecycle.
