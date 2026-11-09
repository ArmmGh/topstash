import Foundation
import Testing

@testable import Topstash

/// Opening the notes folder at startup and switching it in Settings (`AppModel.setFolder`).
@MainActor
struct NotesFolderTests {
    let first = TemporaryFolder()
    let second = TemporaryFolder()

    func makeAppModel(folder: URL) -> (AppModel, UserDefaults) {
        let defaults = UserDefaults(suiteName: "TopstashTests-\(UUID().uuidString)")!
        defaults.set(folder.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        return (AppModel(defaults: defaults, clipboard: FakeClipboard(text: nil)), defaults)
    }

    func writeNote(_ body: String, named name: String, in folder: URL) throws {
        try body.write(to: folder.appending(path: name), atomically: true, encoding: .utf8)
    }

    /// Polls until `condition` holds, for changes that arrive through the folder watcher.
    func waitUntil(timeout: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }

    @Test func startupCreatesAMissingFolder() {
        let missing = first.url.appending(path: "Notes", directoryHint: .isDirectory)

        let (appModel, _) = makeAppModel(folder: missing)

        #expect(FileManager.default.fileExists(atPath: missing.path(percentEncoded: false)))
        #expect(appModel.store.folder == missing)
    }

    @Test func switchingLoadsTheNewFoldersNotesRightAway() throws {
        try writeNote("Old note", named: "old.md", in: first.url)
        try writeNote("New note", named: "new.md", in: second.url)
        let (appModel, defaults) = makeAppModel(folder: first.url)

        try appModel.setFolder(second.url)

        #expect(appModel.store.notes.map(\.body) == ["New note"])
        #expect(defaults.string(forKey: Preferences.notesFolderPathKey) == second.url.path(percentEncoded: false))
    }

    @Test func switchingCreatesAMissingFolder() throws {
        let missing = second.url.appending(path: "Notes", directoryHint: .isDirectory)
        let (appModel, _) = makeAppModel(folder: first.url)

        try appModel.setFolder(missing)

        #expect(FileManager.default.fileExists(atPath: missing.path(percentEncoded: false)))
        #expect(appModel.store.folder == missing)
    }

    @Test func aFolderThatCantBeCreatedLeavesTheOldFolderActive() throws {
        try writeNote("Old note", named: "old.md", in: first.url)
        // A folder can't be created inside a regular file.
        try writeNote("", named: "file", in: second.url)
        let impossible = second.url.appending(path: "file/Notes", directoryHint: .isDirectory)
        let (appModel, defaults) = makeAppModel(folder: first.url)

        #expect(throws: (any Error).self) { try appModel.setFolder(impossible) }

        #expect(appModel.store.folder == first.url)
        #expect(appModel.store.notes.map(\.body) == ["Old note"])
        #expect(defaults.string(forKey: Preferences.notesFolderPathKey) == first.url.path(percentEncoded: false))
    }

    @Test func filesAddedByHandToTheNewFolderShowUp() async throws {
        let (appModel, _) = makeAppModel(folder: first.url)
        try appModel.setFolder(second.url)
        // Give the new FSEvents stream a moment to start before the change it should see.
        try await Task.sleep(for: .milliseconds(200))

        try writeNote("Added by hand", named: "by-hand.md", in: second.url)

        #expect(await waitUntil { appModel.store.notes.map(\.body) == ["Added by hand"] })
    }

    @Test func filesAddedToTheFolderOpenedAtStartupShowUp() async throws {
        let (appModel, _) = makeAppModel(folder: first.url)
        try await Task.sleep(for: .milliseconds(200))

        try writeNote("Added by hand", named: "by-hand.md", in: first.url)

        #expect(await waitUntil { appModel.store.notes.map(\.body) == ["Added by hand"] })
    }
}
