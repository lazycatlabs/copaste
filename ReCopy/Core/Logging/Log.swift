import OSLog

/// ReCopy's loggers, one per area (`log stream --predicate 'subsystem == "com.lazycatlabs.recopy"'`). Use these, never `print`.
nonisolated enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.lazycatlabs.recopy"

    static let storage = Logger(subsystem: subsystem, category: "Storage")
    static let clipboard = Logger(subsystem: subsystem, category: "Clipboard")
    static let metadata = Logger(subsystem: subsystem, category: "Metadata")
}
