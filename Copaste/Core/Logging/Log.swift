import OSLog

/// Copaste's loggers, one per area (`log stream --predicate 'subsystem == "com.lazycatlabs.copaste"'`). Use these, never `print`.
nonisolated enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.lazycatlabs.copaste"

    static let storage = Logger(subsystem: subsystem, category: "Storage")
    static let clipboard = Logger(subsystem: subsystem, category: "Clipboard")
    static let metadata = Logger(subsystem: subsystem, category: "Metadata")
}
