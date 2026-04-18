#if os(Linux)
public extension SystemdBus {
  /// Mode for starting/stopping systemd units
  enum JobMode: String, Sendable {
    case replace
    case fail
    case isolate
    case ignoreDependencies = "ignore-dependencies"
    case ignoreRequirements = "ignore-requirements"
  }

  /// Start a systemd service unit
  ///
  /// - Parameters:
  ///   - service: The name of the service to start (e.g., "nginx.service")
  ///   - mode: The mode to use when starting the service. Default is `.replace`.
  ///   - timeout: Optional timeout for the operation
  /// - Returns: The object path of the job
  /// - Throws: SystemdBusError if the operation fails
  @discardableResult
  func startUnit(
    service: String,
    mode: JobMode = .replace,
    timeout: Duration? = nil
  ) async throws -> Any? {
    try await callManagerMethod(
      "StartUnit",
      fields: [service, mode.rawValue],
      timeout: timeout
    )
  }

  /// Stop a systemd service unit
  ///
  /// - Parameters:
  ///   - service: The name of the service to stop (e.g., "nginx.service")
  ///   - mode: The mode to use when stopping the service. Default is `.replace`.
  ///   - timeout: Optional timeout for the operation
  /// - Returns: The object path of the job
  /// - Throws: SystemdBusError if the operation fails
  @discardableResult
  func stopUnit(
    service: String,
    mode: JobMode = .replace,
    timeout: Duration? = nil
  ) async throws -> Any? {
    try await callManagerMethod(
      "StopUnit",
      fields: [service, mode.rawValue],
      timeout: timeout
    )
  }

  /// Reload a systemd service unit
  ///
  /// - Parameters:
  ///   - service: The name of the service to reload (e.g., "nginx.service")
  ///   - mode: The mode to use when reloading the service. Default is `.replace`.
  ///   - timeout: Optional timeout for the operation
  /// - Returns: The object path of the job
  /// - Throws: SystemdBusError if the operation fails
  @discardableResult
  func reloadUnit(
    service: String,
    mode: JobMode = .replace,
    timeout: Duration? = nil
  ) async throws -> Any? {
    try await callManagerMethod(
      "ReloadUnit",
      fields: [service, mode.rawValue],
      timeout: timeout
    )
  }

  /// Restart a systemd service unit
  ///
  /// - Parameters:
  ///   - service: The name of the service to restart (e.g., "nginx.service")
  ///   - mode: The mode to use when restarting the service. Default is `.replace`.
  ///   - timeout: Optional timeout for the operation
  /// - Returns: The object path of the job
  /// - Throws: SystemdBusError if the operation fails
  @discardableResult
  func restartUnit(
    service: String,
    mode: JobMode = .replace,
    timeout: Duration? = nil
  ) async throws -> Any? {
    try await callManagerMethod(
      "RestartUnit",
      fields: [service, mode.rawValue],
      timeout: timeout
    )
  }

  /// Try to restart a systemd service unit (only if already running)
  ///
  /// - Parameters:
  ///   - service: The name of the service to try to restart (e.g., "nginx.service")
  ///   - mode: The mode to use when restarting the service. Default is `.replace`.
  ///   - timeout: Optional timeout for the operation
  /// - Returns: The object path of the job
  /// - Throws: SystemdBusError if the operation fails
  @discardableResult
  func tryRestartUnit(
    service: String,
    mode: JobMode = .replace,
    timeout: Duration? = nil
  ) async throws -> Any? {
    try await callManagerMethod(
      "TryRestartUnit",
      fields: [service, mode.rawValue],
      timeout: timeout
    )
  }

  /// Reload or restart a systemd service unit
  ///
  /// - Parameters:
  ///   - service: The name of the service to reload or restart (e.g., "nginx.service")
  ///   - mode: The mode to use when reloading or restarting the service. Default is `.replace`.
  ///   - timeout: Optional timeout for the operation
  /// - Returns: The object path of the job
  /// - Throws: SystemdBusError if the operation fails
  @discardableResult
  func reloadOrRestartUnit(
    service: String,
    mode: JobMode = .replace,
    timeout: Duration? = nil
  ) async throws -> Any? {
    try await callManagerMethod(
      "ReloadOrRestartUnit",
      fields: [service, mode.rawValue],
      timeout: timeout
    )
  }

  /// Reload or try to restart a systemd service unit (only if already running)
  ///
  /// - Parameters:
  ///   - service: The name of the service to reload or try to restart (e.g., "nginx.service")
  ///   - mode: The mode to use when reloading or restarting the service. Default is `.replace`.
  ///   - timeout: Optional timeout for the operation
  /// - Returns: The object path of the job
  /// - Throws: SystemdBusError if the operation fails
  @discardableResult
  func reloadOrTryRestartUnit(
    service: String,
    mode: JobMode = .replace,
    timeout: Duration? = nil
  ) async throws -> Any? {
    try await callManagerMethod(
      "ReloadOrTryRestartUnit",
      fields: [service, mode.rawValue],
      timeout: timeout
    )
  }
}

private extension SystemdBus {
  /// Invoke a method on the `org.freedesktop.systemd1.Manager` interface.
  @discardableResult
  func callManagerMethod(
    _ member: String,
    fields: [Any] = [],
    timeout: Duration? = nil
  ) async throws -> Any? {
    try await callMethod(
      interface: "org.freedesktop.systemd1.Manager",
      member: member,
      fields: fields,
      timeout: timeout
    )
  }
}
#endif
