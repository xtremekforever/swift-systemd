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

## Usage

Add `import Systemd` to the app use the modules provided by this library.

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
