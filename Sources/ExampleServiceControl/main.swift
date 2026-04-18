#if os(Linux)
import ArgumentParser
import Foundation
import Systemd

extension SystemdBus.JobMode: ExpressibleByArgument {}

@main
struct SystemdServiceControlExample: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "systemd-service-control",
    abstract: "Control systemd services via D-Bus",
    subcommands: [Start.self, Stop.self]
  )

  struct Start: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Start a systemd service"
    )

    @Argument(help: "The service name to start (e.g., wpa_supplicant.service)")
    var service: String

    @Option(
      help: "The mode to use (replace, fail, isolate, ignoreDependencies, ignoreRequirements)"
    )
    var mode: SystemdBus.JobMode = .replace

    @Flag(help: "Show verbose output")
    var verbose: Bool = false

    func run() async throws {
      let bus = try SystemdBus.system

      if verbose {
        print("Starting service '\(service)' with mode '\(mode.rawValue)'...")
      }

      let result = try await bus.startUnit(service: service, mode: mode)

      if verbose {
        print("Service started successfully")
        if let jobPath = result {
          print("Job path: \(jobPath)")
        }
      } else {
        print("Started \(service)")
      }
    }
  }

  struct Stop: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Stop a systemd service"
    )

    @Argument(help: "The service name to stop (e.g., wpa_supplicant.service)")
    var service: String

    @Option(
      help: "The mode to use (replace, fail, isolate, ignoreDependencies, ignoreRequirements)"
    )
    var mode: SystemdBus.JobMode = .replace

    @Flag(help: "Show verbose output")
    var verbose: Bool = false

    func run() async throws {
      let bus = try SystemdBus.system

      if verbose {
        print("Stopping service '\(service)' with mode '\(mode.rawValue)'...")
      }

      let result = try await bus.stopUnit(service: service, mode: mode)

      if verbose {
        print("Service stopped successfully")
        if let jobPath = result {
          print("Job path: \(jobPath)")
        }
      } else {
        print("Stopped \(service)")
      }
    }
  }
}
#else
@main
struct SystemdServiceControlExample {
  static func main() {
    print("This tool is only available on Linux")
  }
}
#endif
