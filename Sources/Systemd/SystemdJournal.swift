import Logging

#if os(Linux)
    import CSystemd
#endif

public struct SystemdJournalLogHandler: LogHandler {
    public var logLevel: Logger.Level = .info
    public var metadataProvider: Logger.MetadataProvider?

    private let label: String

    @Sendable
    public init(
        label: String,
        metadataProvider: Logger.MetadataProvider? = nil
    ) {
        self.label = label
        self.metadataProvider = metadataProvider
    }

    @Sendable
    public init(
        label: String
    ) {
        self.init(label: label, metadataProvider: nil)
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata explicitMetadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        #if os(Linux)
            let effectiveMetadata = Self.prepareMetadata(
                label: label,
                level: level,
                message: message,
                base: metadata,
                provider: metadataProvider,
                explicit: explicitMetadata,
                source: source,
                file: file,
                function: function,
                line: line
            )

            withArrayOfIovecs(effectiveMetadata.map { "\($0)=\($1)" }) { iov in
                _ = sd_journal_sendv(iov, Int32(iov.count))
            }
        #endif
    }

    public var metadata = Logger.Metadata()

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            metadata[metadataKey]
        }
        set(newValue) {
            metadata[metadataKey] = newValue
        }
    }

    private static func prepareMetadata(
        label: String,
        level: Logger.Level,
        message: Logger.Message,
        base: Logger.Metadata,
        provider: Logger.MetadataProvider?,
        explicit: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) -> Logger.Metadata {
        var metadata = base
        let provided = provider?.get() ?? [:]

        if !provided.isEmpty {
            metadata.merge(provided, uniquingKeysWith: { _, provided in provided })
        }

        if let explicit = explicit, !explicit.isEmpty {
            metadata.merge(explicit, uniquingKeysWith: { _, explicit in explicit })
        }

        // The human-readable message string for this entry
        metadata["MESSAGE"] = .string(message.description)

        // A priority value between 0 ("emerg") and 7 ("debug")
        metadata["PRIORITY"] = .string("\(level.syslogPriority)")

        // The code location generating this message, if known.
        metadata["CODE_FILE"] = .string(file)
        metadata["CODE_FUNC"] = .string(function)
        metadata["CODE_LINE"] = .string("\(line)")

        // The name of a unit.
        metadata["UNIT"] = .string(source)
        metadata["SYSLOG_IDENTIFIER"] = .string(label)

        return metadata
    }
}
