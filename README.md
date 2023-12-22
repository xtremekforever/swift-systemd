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

For now, the library only has the ability to see if the app is running under systemd. To do this,
`import Systemd` in your app, then use `SystemdHelpers` to get a true or false value:

```swift
if SystemdHelpers.isSystemdService {
    print("This app is running as a systemd service!")

    // do things like modify logging format (if using swift-log) or whatever else is needed.
}
```
