import Foundation

/// UserDefaults keys and default values.
enum Preferences {
    /// String, absolute path. Default `~/Documents/Topstash`.
    static let notesFolderPathKey = "notesFolderPath"
    /// Int. Default 250.
    static let hoverDelayMillisecondsKey = "hoverDelayMilliseconds"

    static let defaultHoverDelayMilliseconds = 250

    static func notesFolder(_ defaults: UserDefaults = .standard) -> URL {
        if let path = defaults.string(forKey: notesFolderPathKey), !path.isEmpty {
            return URL(filePath: path, directoryHint: .isDirectory)
        }
        return URL.documentsDirectory.appending(path: "Topstash", directoryHint: .isDirectory)
    }

    static func hoverDelay(_ defaults: UserDefaults = .standard) -> Duration {
        let milliseconds = defaults.object(forKey: hoverDelayMillisecondsKey) as? Int ?? defaultHoverDelayMilliseconds
        return .milliseconds(max(0, milliseconds))
    }
}
