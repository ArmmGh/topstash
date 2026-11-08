import Foundation
import Testing
import TopstashCore

@MainActor
struct NotesStoreTests {
    let temp = TemporaryFolder()

    /// 2026-11-08T15:52:14Z, which is 19:52:14 in Asia/Yerevan (+04:00).
    static let fixedDate = Date(timeIntervalSince1970: 1_794_153_134)
    static let yerevan = TimeZone(identifier: "Asia/Yerevan")!

    func makeStore(folder: URL? = nil, timeZone: TimeZone = yerevan) -> NotesStore {
        NotesStore(folder: folder ?? temp.url, now: { Self.fixedDate }, timeZone: timeZone)
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

    @Test func savedNoteBecomesFirstInNotes() throws {
        let store = makeStore()

        let older = try savedNote(store.save("Older"))
        let newer = try savedNote(store.save("Newer"))

        #expect(store.notes == [newer, older])
    }

    @Test func createdMatchesTheSecondsWrittenToTheFile() throws {
        let store = NotesStore(folder: temp.url, now: { Self.fixedDate.addingTimeInterval(0.75) }, timeZone: Self.yerevan)

        let note = try savedNote(store.save("Sub-second clock"))

        #expect(note.created == Self.fixedDate)
    }
}
