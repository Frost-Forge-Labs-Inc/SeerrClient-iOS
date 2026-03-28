// Logger.swift
// SeerrClient
//
// Lightweight debug logger that only emits output in DEBUG builds.
// Uses os.Logger (unified logging) so messages appear in Xcode console
// and Console.app with subsystem/category filtering.

import Foundation
import os.log

// MARK: - AppLogger

/// A thin wrapper around `os.Logger` that:
/// - Only emits output in `DEBUG` builds.
/// - Groups messages under the `"com.seerrclient"` subsystem.
/// - Exposes convenience static methods (`debug`, `info`, `warning`, `error`).
///
/// Usage:
/// ```swift
/// AppLogger.debug("Fetching search results for query: \(query)")
/// AppLogger.info("AppState: active server set to '\(server.displayName)'")
/// AppLogger.warning("TrustManager: fingerprint mismatch for \(serverURL)")
/// AppLogger.error("Decoding failed: \(error)")
/// ```
public enum AppLogger {

    // MARK: - Subsystem / Category

    private static let subsystem = "com.seerrclient"

    // MARK: - Loggers (one per category)

    private static let networkingLogger = Logger(
        subsystem: subsystem,
        category: "Networking"
    )

    private static let storageLogger = Logger(
        subsystem: subsystem,
        category: "Storage"
    )

    private static let appLogger = Logger(
        subsystem: subsystem,
        category: "App"
    )

    private static let defaultLogger = Logger(
        subsystem: subsystem,
        category: "General"
    )

    // MARK: - Public API

    /// Logs a debug-level message. Only visible in `DEBUG` builds.
    ///
    /// - Parameters:
    ///   - message: The message to log. String interpolation is supported.
    ///   - category: Routing hint for the log category. Defaults to `"General"`.
    public static func debug(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        file: String = #file,
        line: Int = #line
    ) {
        #if DEBUG
        let msg = message()
        logger(for: category).debug("\(msg, privacy: .public) [\(sourceLocation(file: file, line: line))]")
        #endif
    }

    /// Logs an info-level message. Only visible in `DEBUG` builds.
    public static func info(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        file: String = #file,
        line: Int = #line
    ) {
        #if DEBUG
        let msg = message()
        logger(for: category).info("\(msg, privacy: .public) [\(sourceLocation(file: file, line: line))]")
        #endif
    }

    /// Logs a warning-level message. Only visible in `DEBUG` builds.
    public static func warning(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        file: String = #file,
        line: Int = #line
    ) {
        #if DEBUG
        let msg = message()
        logger(for: category).warning("\(msg, privacy: .public) [\(sourceLocation(file: file, line: line))]")
        #endif
    }

    /// Logs an error-level message.
    ///
    /// Error messages are retained in the unified log even in release builds
    /// for crash diagnostics, but are not printed to the console.
    public static func error(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        file: String = #file,
        line: Int = #line
    ) {
        let msg = message()
        logger(for: category).error("\(msg, privacy: .public) [\(sourceLocation(file: file, line: line))]")
    }

    // MARK: - Private Helpers

    private static func logger(for category: LogCategory) -> Logger {
        switch category {
        case .networking: return networkingLogger
        case .storage:    return storageLogger
        case .app:        return appLogger
        case .general:    return defaultLogger
        }
    }

    private static func sourceLocation(file: String, line: Int) -> String {
        let filename = URL(fileURLWithPath: file).lastPathComponent
        return "\(filename):\(line)"
    }
}

// MARK: - LogCategory

/// Routing categories for `AppLogger`.
///
/// Each category maps to a separate `os.Logger` instance with a distinct
/// `category` label, making it easy to filter in Console.app.
public enum LogCategory {
    /// Network requests, responses, and errors.
    case networking
    /// Keychain, UserDefaults, and ServerStore operations.
    case storage
    /// App lifecycle, AppState, and navigation.
    case app
    /// Everything else.
    case general
}
