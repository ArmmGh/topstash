import Foundation
import Testing
import TopstashCore

@MainActor
struct NotesStoreTests {
    let temp = TemporaryFolder()

    /// 2026-11-08T15:52:14Z, which is 19:52:14 in Asia/Yerevan (+04:00).
    static let fixedDate = Date(timeIntervalSince1970: 1_794_153_134)
    static let yerevan = TimeZone(identifier: "Asia/Yerevan")!

    func makeStore(folder: URL? = nil, timeZone: TimeZone = yerevan, clock: Clock? = nil) -> NotesStore {
        let now: () -> Date = if let clock { { clock.now } } else { { Self.fixedDate } }
        return NotesStore(folder: folder ?? temp.url, now: now, timeZone: timeZone)
    }

    /// A clock that starts at `fixedDate` and moves only when told to.
    @MainActor
    final class Clock {
        var now = NotesStoreTests.fixedDate

        func advance(seconds: TimeInterval) {
            now.addTimeInterval(seconds)
        }
    }

    struct NotSaved: Error {
        let result: SaveResult
    }

    func savedNote(_ result: SaveResult) throws -> Note {
        guard case .saved(let note) = result else { throw NotSaved(result: result) }
        return note
    }

    func fileBytes(_ note: Note) throws -> Data {
        try Data(contentsOf: note.fileURL)
    }

    @Test func savedFileHasFrontmatterThenBodyByteForByte() throws {
        let store = makeStore()

        let note = try savedNote(store.save("Refactor this module"))

        let expected = "---\nid: \(note.noteID)\ncreated: 2026-11-08T19:52:14+04:00\ntype: text\n---\nRefactor this module"
        #expect(try fileBytes(note) == Data(expected.utf8))
        #expect(try temp.fileNames() == [note.fileURL.lastPathComponent])
        #expect(note.noteID.count == 8)
        #expect(note.noteID.allSatisfy { "0123456789abcdef".contains($0) })
        #expect(note.type == "text")
        #expect(note.body == "Refactor this module")
        #expect(note.created == Self.fixedDate)
    }

    @Test(arguments: [
        "  leading and trailing whitespace \t ",
        "\n\nfirst\n\n\nafter blank lines\n\n",
        "```swift\nlet x = 1\n```",
        "windows\r\nline\r\nendings\r\n",
        "ends with a newline\n",
        "no trailing newline",
        "emoji 🚀👩‍💻 and Привет",
    ])
    func bodyIsKeptExactly(body: String) throws {
        let store = makeStore()

        let note = try savedNote(store.save(body))

        let header = "---\nid: \(note.noteID)\ncreated: 2026-11-08T19:52:14+04:00\ntype: text\n---\n"
        #expect(try fileBytes(note) == Data((header + body).utf8))
        #expect(note.body == body)
    }

    @Test func filenameUsesCreatedInStoreTimeZoneAndTitleSlug() throws {
        let store = makeStore()

        let note = try savedNote(store.save("Refactor this module"))

        #expect(note.fileURL.lastPathComponent == "2026-11-08-1952-refactor-this-module.md")
        #expect(note.fileURL.deletingLastPathComponent().standardizedFileURL == temp.url.standardizedFileURL)
    }

    @Test func utcStoreWritesZAndUTCFilename() throws {
        let store = makeStore(timeZone: TimeZone(identifier: "UTC")!)

        let note = try savedNote(store.save("Hello"))

        #expect(note.fileURL.lastPathComponent == "2026-11-08-1552-hello.md")
        let text = String(decoding: try fileBytes(note), as: UTF8.self)
        #expect(text.contains("\ncreated: 2026-11-08T15:52:14Z\n"))
    }

    @Test(arguments: [
        (body: "\n  \n\nSecond line is the title\nmore", title: "Second line is the title", slug: "second-line-is-the-title"),
        (body: "```bash\nnpm test\n```", title: "npm test", slug: "npm-test"),
        (body: "~~~\nplain fence\n~~~", title: "plain fence", slug: "plain-fence"),
        (body: "## Review the diff\nbody", title: "Review the diff", slug: "review-the-diff"),
        (body: "Привет мир", title: "Привет мир", slug: "privet-mir"),
        (body: "Café au lait", title: "Café au lait", slug: "cafe-au-lait"),
        (body: "🚀🚀", title: "🚀🚀", slug: "note"),
        (body: "```\n```", title: "Untitled", slug: "note"),
    ])
    func titleAndSlug(body: String, title: String, slug: String) throws {
        let store = makeStore()

        let note = try savedNote(store.save(body))

        #expect(note.title == title)
        #expect(note.fileURL.lastPathComponent == "2026-11-08-1952-\(slug).md")
    }

    @Test(arguments: [
        (body: "Just a title", preview: ""),
        (body: "  Title with trailing blank lines  \n\n \n", preview: ""),
        (body: "Title\n  second   line\n\n\tthird\r\nfourth  ", preview: "second line third fourth"),
        (body: "\n\n## Heading\nbody text", preview: "body text"),
        (body: "```bash\nnpm test\n```", preview: "```"),
        (body: "Title\n" + String(repeating: "abcdefghij", count: 20), preview: String(repeating: "abcdefghij", count: 14)),
    ])
    func previewIsTheTextAfterTheTitleLineOnOneLine(body: String, preview: String) throws {
        let store = makeStore()

        let note = try savedNote(store.save(body))

        #expect(note.preview == preview)
    }

    @Test func longFirstLineCutsTitleAt80AndSlugAt50() throws {
        let store = makeStore()
        let line = String(repeating: "abcdefghij", count: 30)

        let note = try savedNote(store.save(line + "\nsecond line"))

        #expect(note.title == String(repeating: "abcdefghij", count: 8) + "…")
        #expect(note.fileURL.lastPathComponent == "2026-11-08-1952-\(String(repeating: "abcdefghij", count: 5)).md")
    }

    @Test func slugCutAt50DoesNotEndWithHyphen() throws {
        let store = makeStore()

        let note = try savedNote(store.save(String(repeating: "Abcd ", count: 60)))

        let slug = String(repeating: "abcd-", count: 10).dropLast()
        #expect(note.fileURL.lastPathComponent == "2026-11-08-1952-\(slug).md")
    }

    @Test func savesWithTheSameSlugAtTheSameTimeGetNumberedSuffixes() throws {
        let store = makeStore()

        let first = try savedNote(store.save("Same title\nfirst body"))
        let second = try savedNote(store.save("Same title\nsecond body"))
        let third = try savedNote(store.save("# Same title\nthird body"))

        #expect(first.fileURL.lastPathComponent == "2026-11-08-1952-same-title.md")
        #expect(second.fileURL.lastPathComponent == "2026-11-08-1952-same-title-2.md")
        #expect(third.fileURL.lastPathComponent == "2026-11-08-1952-same-title-3.md")
        #expect(try temp.fileNames().count == 3)
        #expect(String(decoding: try fileBytes(first), as: UTF8.self).hasSuffix("first body"))
    }

    @Test(arguments: ["", " ", "\n\n", " \t\r\n  "])
    func emptyOrWhitespaceOnlyTextIsNotSaved(text: String) throws {
        let store = makeStore()

        #expect(try store.save(text) == .empty)
        #expect(try temp.fileNames().isEmpty)
        #expect(store.notes.isEmpty)
    }

    @Test func missingNestedFolderIsCreatedOnFirstSave() throws {
        let folder = temp.url.appending(path: "a/b/Topstash", directoryHint: .isDirectory)
        let store = makeStore(folder: folder)

        let note = try savedNote(store.save("First note"))

        #expect(try temp.fileNames(in: folder) == [note.fileURL.lastPathComponent])
    }

    @Test func notesAreNewestFirstWhenSavedAndWhenLoaded() throws {
        let clock = Clock()
        let store = makeStore(clock: clock)

        // Same minute, so the filenames alone would put "older" before "newer".
        let older = try savedNote(store.save("Older"))
        clock.advance(seconds: 10)
        let newer = try savedNote(store.save("Newer"))
        clock.advance(seconds: 10)
        let newest = try savedNote(store.save("Newest"))

        #expect(store.notes == [newest, newer, older])
        #expect(makeStore().notes == [newest, newer, older])
    }

    // MARK: - Loading

    @Test func newStoreLoadsNotesSavedByAnotherStore() throws {
        let clock = Clock()
        let writer = makeStore(clock: clock)
        let bodies = [
            "Refactor this module",
            "  leading and trailing whitespace \t ",
            "\n\nfirst\n\n\nafter blank lines\n\n",
            "```swift\nlet x = 1\n```",
            "windows\r\nline\r\nendings\r\n",
            "---\nlooks like frontmatter\n---\nbody",
            "emoji 🚀👩‍💻 and Привет",
        ]
        for body in bodies {
            _ = try savedNote(writer.save(body))
            clock.advance(seconds: 60)
        }

        let reader = makeStore()

        #expect(reader.notes.count == bodies.count)
        #expect(reader.notes == writer.notes)
    }

    @Test func onlyVisibleTopLevelMarkdownFilesAreLoaded() throws {
        let note = try savedNote(makeStore().save("Top level"))
        let data = try fileBytes(note)
        let fileManager = FileManager.default
        func write(_ path: String) throws {
            let url = temp.url.appending(path: path, directoryHint: .notDirectory)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        }
        try write("UPPER.MD")
        try write("not-markdown.txt")
        try write(".hidden.md")
        try write("sub/nested.md")
        try write(".obsidian/hidden-dir.md")
        try write("looks-like-a-note.md/inside.md")

        let names = makeStore().notes.map(\.fileURL.lastPathComponent)

        #expect(names == ["UPPER.MD", note.fileURL.lastPathComponent])
    }

    @Test func storeOnAMissingFolderHasNoNotesAndDoesNotCreateIt() throws {
        let folder = temp.url.appending(path: "missing", directoryHint: .isDirectory)

        let store = makeStore(folder: folder)
        store.reload()

        #expect(store.notes.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)))
    }

    @Test func notesWithTheSameCreatedAreOrderedByFilenameDescending() throws {
        let store = makeStore()

        let charlie = try savedNote(store.save("Charlie"))
        let alpha = try savedNote(store.save("Alpha"))
        let bravo = try savedNote(store.save("Bravo"))

        #expect(store.notes == [charlie, bravo, alpha])
        #expect(makeStore().notes == [charlie, bravo, alpha])
    }

    @Test(arguments: [
        (limit: 2, expectedCount: 2),
        (limit: 3, expectedCount: 3),
        (limit: 5, expectedCount: 3),
        (limit: 0, expectedCount: 0),
        (limit: -1, expectedCount: 0),
    ])
    func recentReturnsTheNewestNotesUpToTheLimit(limit: Int, expectedCount: Int) throws {
        let clock = Clock()
        let store = makeStore(clock: clock)
        let first = try savedNote(store.save("First"))
        clock.advance(seconds: 60)
        let second = try savedNote(store.save("Second"))
        clock.advance(seconds: 60)
        let third = try savedNote(store.save("Third"))

        let recent = store.recent(limit: limit)

        #expect(recent == Array([third, second, first].prefix(expectedCount)))
    }

    @Test func createdMatchesTheSecondsWrittenToTheFile() throws {
        let store = NotesStore(folder: temp.url, now: { Self.fixedDate.addingTimeInterval(0.75) }, timeZone: Self.yerevan)

        let note = try savedNote(store.save("Sub-second clock"))

        #expect(note.created == Self.fixedDate)
    }
}

// MARK: - Files written outside the app (#7)

extension NotesStoreTests {
    /// Writes `contents` to `name` in the temp folder, as another program would.
    @discardableResult
    func writeExternal(_ name: String, _ contents: String) throws -> URL {
        try writeExternal(name, Data(contents.utf8))
    }

    @discardableResult
    func writeExternal(_ name: String, _ data: Data) throws -> URL {
        let url = temp.url.appending(path: name, directoryHint: .notDirectory)
        try data.write(to: url)
        return url
    }

    @Test func fileWithoutFrontmatterLoadsWithItsWholeContentAsTheBody() throws {
        let contents = "# Imported prompt\n\nExplain this code.\n"
        try writeExternal("imported.md", contents)

        let notes = makeStore().notes

        #expect(notes.count == 1)
        #expect(notes.first?.body == contents)
        #expect(notes.first?.type == "text")
        #expect(notes.first?.title == "Imported prompt")
    }

    @Test func fileWithoutFrontmatterUsesItsCreationDateAndAStableHexID() throws {
        let url = try writeExternal("imported.md", "Explain this code.")
        let creationDate = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.creationDate: creationDate], ofItemAtPath: url.path(percentEncoded: false))
        let store = makeStore()

        let first = try #require(store.notes.first)
        store.reload()
        let second = try #require(store.notes.first)

        #expect(first.created == creationDate)
        #expect(first.noteID.count == 8)
        #expect(first.noteID.allSatisfy { "0123456789abcdef".contains($0) })
        #expect(second.noteID == first.noteID)
    }

    @Test func frontmatterWithoutCreatedUsesTheCreationDate() throws {
        let url = try writeExternal("partial.md", "---\nid: abcd1234\ntitle: ignored\nno colon here\n---\nThe body")
        let creationDate = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.creationDate: creationDate], ofItemAtPath: url.path(percentEncoded: false))

        let note = try #require(makeStore().notes.first)

        #expect(note.created == creationDate)
        #expect(note.noteID == "abcd1234")
        #expect(note.type == "text")
        #expect(note.body == "The body")
    }

    @Test func frontmatterWithCRLFLineEndingsIsParsed() throws {
        try writeExternal("windows.md", "---\r\nid: abcd1234\r\ncreated: 2026-11-08T19:52:14+04:00\r\ntype: text\r\n---\r\nLine one\r\nLine two")

        let note = try #require(makeStore().notes.first)

        #expect(note.noteID == "abcd1234")
        #expect(note.created == Self.fixedDate)
        #expect(note.body == "Line one\r\nLine two")
    }

    @Test func fileWithANonTextTypeIsSkipped() throws {
        try writeExternal("image.md", "---\nid: abcd1234\ncreated: 2026-11-08T19:52:14+04:00\ntype: image\n---\nimage.png")

        #expect(makeStore().notes.isEmpty)
    }

    @Test(arguments: [
        (name: "unclosed.md", contents: Data("---\nid: abcd1234\nThe body never starts".utf8)),
        (name: "latin1.md", contents: Data([0x63, 0x61, 0x66, 0xE9, 0x0A])),
        (name: "zero-bytes.md", contents: Data()),
        (name: "whitespace.md", contents: Data(" \n\t\r\n ".utf8)),
        (name: "frontmatter-only.md", contents: Data("---\nid: abcd1234\n---\n  \n".utf8)),
        (name: "notes.txt", contents: Data("Plain text that isn't Markdown".utf8)),
    ])
    func brokenOrUnrelatedFilesAreSkipped(name: String, contents: Data) throws {
        let good = try writeExternal("good.md", "A good note")
        try writeExternal(name, contents)

        let notes = makeStore().notes

        #expect(notes.map(\.fileURL.lastPathComponent) == [good.lastPathComponent])
    }

    @Test func upperCaseMDExtensionLoads() throws {
        try writeExternal("PROMPT.MD", "Upper case extension")

        #expect(makeStore().notes.map(\.body) == ["Upper case extension"])
    }

    @Test func loadingNeverChangesTheFiles() throws {
        let files: [(name: String, contents: Data)] = [
            ("plain.md", Data("No frontmatter\r\nat all   \n".utf8)),
            ("partial.md", Data("---\nid: abcd1234\n---\nNo created".utf8)),
            ("unclosed.md", Data("---\nnever closed".utf8)),
            ("image.md", Data("---\ntype: image\n---\nimage.png".utf8)),
        ]
        var before: [String: (data: Data, modified: Date?)] = [:]
        for file in files {
            let url = try writeExternal(file.name, file.contents)
            before[file.name] = (file.contents, try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        }

        let store = makeStore()
        store.reload()

        #expect(try temp.fileNames() == files.map(\.name).sorted())
        for file in files {
            let url = temp.url.appending(path: file.name, directoryHint: .notDirectory)
            #expect(try Data(contentsOf: url) == before[file.name]?.data)
            #expect(try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate == before[file.name]?.modified)
        }
    }

    // MARK: Changes on disk

    @Test func fileAddedOnDiskAppearsAfterReload() throws {
        let store = makeStore()
        #expect(store.notes.isEmpty)

        try writeExternal("added.md", "Added by another program")
        store.reload()

        #expect(store.notes.map(\.body) == ["Added by another program"])
    }

    @Test func fileDeletedOnDiskDisappearsAfterReload() throws {
        let store = makeStore()
        let kept = try savedNote(store.save("Kept"))
        let deleted = try savedNote(store.save("Deleted"))

        try FileManager.default.removeItem(at: deleted.fileURL)
        store.reload()

        #expect(store.notes == [kept])
    }

    @Test func bodyEditedOnDiskShowsTheNewBodyAfterReload() throws {
        let store = makeStore()
        let note = try savedNote(store.save("old prompt"))

        // An in-place edit, like `sed -i` or an editor saving over the file.
        let edited = String(decoding: try fileBytes(note), as: UTF8.self)
            .replacingOccurrences(of: "old prompt", with: "new prompt")
        try Data(edited.utf8).write(to: note.fileURL)
        store.reload()

        let reloaded = try #require(store.notes.first)
        #expect(store.notes.count == 1)
        #expect(reloaded.body.contains("new prompt"))
        #expect(!reloaded.body.contains("old prompt"))
        #expect(reloaded.noteID == note.noteID)
    }

    @Test func appendedTextShowsAfterReload() throws {
        let store = makeStore()
        let url = try writeExternal("appended.md", "first line\n")
        store.reload()

        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("more\n".utf8))
        try handle.close()
        store.reload()

        #expect(store.notes.map(\.body) == ["first line\nmore\n"])
    }
}
