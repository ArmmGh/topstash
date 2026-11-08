import Foundation

/// A unique folder under the system temp directory. It's deleted when the value is released,
/// so a suite that stores one gets a fresh folder per test.
final class TemporaryFolder {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appending(path: "TopstashTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    /// Names of the files in the folder, sorted.
    func fileNames(in folder: URL? = nil) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: (folder ?? url).path(percentEncoded: false)).sorted()
    }
}
