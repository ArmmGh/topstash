import Foundation

/// UserDefaults keys and default values.
enum Preferences {
    /// String, absolute path. Default `~/Documents/Topstash`.
    static let notesFolderPathKey = "notesFolderPath"
    /// Int. Default 250.
    static let hoverDelayMillisecondsKey = "hoverDelayMilliseconds"
    /// Bool. Default false. Whether ⌥Return in search pastes the note into the previous app.
    static let pastesOnOptionReturnKey = "pastesOnOptionReturn"

    static let defaultHoverDelayMilliseconds = 250

    static func notesFolder(_ defaults: UserDefaults = .standard) -> URL {
        if let path = defaults.string(forKey: notesFolderPathKey), !path.isEmpty {
            return URL(filePath: path, directoryHint: .isDirectory)
        }
        return URL.documentsDirectory.appending(path: "Topstash", directoryHint: .isDirectory)
    }

    static func pastesOnOptionReturn(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: pastesOnOptionReturnKey)
    }

    /// In seconds.
    static func hoverDelay(_ defaults: UserDefaults = .standard) -> Double {
        let milliseconds = defaults.object(forKey: hoverDelayMillisecondsKey) as? Int ?? defaultHoverDelayMilliseconds
        return Double(max(0, milliseconds)) / 1000
    }
}
