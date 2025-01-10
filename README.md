# Systemd

A simple Swift library to interface with systemd on Linux.

## Compatibility

This library is designed to be API-compatible on non-Linux platforms (like macOS), so if an
application uses this package it will still compile and run on non-Linux platforms. However,
systemd-specific calls will have no effect. For example, `SystemdHelpers.isSystemdService` will
always return `false` on Windows or macOS.

To use this library in Linux, however, the `systemd` libraries are required. These can be installed
with the following commands on different distributions:

* Debian/Ubuntu: `sudo apt install libsystemd-dev`
* RHEL/Fedora: `sudo dnf install systemd-devel`
* SUSE/OpenSUSE: `sudo zypper install systemd-devel`

For other distributions, look in the package repositories for a systemd dev package and install it.

NOTE: This library is *NOT* compatible with Musl as it appears that systemd libraries are still
[not fully ported to Musl yet](https://catfox.life/2024/09/05/porting-systemd-to-musl-libc-powered-linux/).
Please open a ticket if this changes so that support can be added for Musl, once this configuration
is supported.

## Installation

Add the following dependency to your `Package.swift` file:

```swift
.package(url: "https://github.com/xtremekforever/swift-systemd.git", from: "0.1.0")
```

Then, add it to your target `dependencies` section like this:

```swift
.product(name: "Systemd", package: "swift-systemd")
```

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
