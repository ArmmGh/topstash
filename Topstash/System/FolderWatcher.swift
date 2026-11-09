import CoreServices
import Foundation
import os
import TopstashCore

/// Watches the notes folder with FSEvents and calls `onChange` once per batch of changes that
/// `NotesStore` reads: a visible `.md` file in the top level of the folder. FSEvents streams are
/// recursive, so changes in subfolders (`.git`, `.obsidian`) are filtered out here.
/// File-level events catch in-place edits (`echo >> note.md`) that a directory `DispatchSource` misses.
/// The stream latency is the debounce. If the folder itself is deleted or moved, or FSEvents asks for
/// a rescan, `onChange` is called too.
@MainActor
final class FolderWatcher {
    let folder: URL
    private static let latency: TimeInterval = 0.3
    private let onChange: @MainActor () -> Void
    private var stream: FSEventStreamRef?
    /// `folder` with symlinks resolved, as FSEvents reports paths (`/private/var`, not `/var`).
    private let resolvedFolderPath: String

    private static let logger = Logger(category: "FolderWatcher")

    init(folder: URL, onChange: @escaping @MainActor () -> Void) {
        self.folder = folder
        self.onChange = onChange
        resolvedFolderPath = Self.comparablePath(folder.resolvingSymlinksInPath())
    }

    /// The standardized path without a trailing slash, so a folder URL and a file's parent compare equal.
    private static func comparablePath(_ url: URL) -> String {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    /// Flags that mean the events don't say which files changed, or that the folder itself did.
    private static let rescanFlags = FSEventStreamEventFlags(
        kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagUserDropped
            | kFSEventStreamEventFlagKernelDropped | kFSEventStreamEventFlagRootChanged
    )

    /// Whether a batch of events touches anything `NotesStore.reload()` reads.
    private func isRelevant(paths: [String], flags: [FSEventStreamEventFlags]) -> Bool {
        zip(paths, flags).contains { path, flags in
            if flags & Self.rescanFlags != 0 { return true }
            let url = URL(filePath: path, directoryHint: .notDirectory)
            guard NotesStore.isNoteFile(named: url.lastPathComponent) else { return false }
            return Self.comparablePath(url.deletingLastPathComponent()) == resolvedFolderPath
        }
    }

    /// Starts watching. Does nothing if it's already watching.
    func start() {
        guard stream == nil else { return }
        // The stream retains the watcher until `stop()` releases the stream, so the callback never sees a freed object.
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: { info in
                guard let info else { return nil }
                _ = Unmanaged<FolderWatcher>.fromOpaque(info).retain()
                return UnsafeRawPointer(info)
            },
            release: { info in
                guard let info else { return }
                Unmanaged<FolderWatcher>.fromOpaque(info).release()
            },
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, count, eventPaths, eventFlags, _ in
            guard let info else { return }
            // `kFSEventStreamCreateFlagUseCFTypes` makes `eventPaths` a CFArray of CFStrings.
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            let flags = Array(UnsafeBufferPointer(start: eventFlags, count: count))
            // Delivered on the main queue (see `FSEventStreamSetDispatchQueue` below).
            MainActor.assumeIsolated {
                let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
                if watcher.isRelevant(paths: paths, flags: flags) {
                    watcher.onChange()
                }
            }
        }
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagUseCFTypes
        )
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [folder.path(percentEncoded: false)] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            Self.latency,
            flags
        ) else {
            Self.logger.error("Couldn't create an FSEvents stream for \(self.folder.path(percentEncoded: false), privacy: .public)")
            return
        }
        FSEventStreamSetDispatchQueue(stream, .main)
        guard FSEventStreamStart(stream) else {
            Self.logger.error("Couldn't start watching \(self.folder.path(percentEncoded: false), privacy: .public)")
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return
        }
        self.stream = stream
    }

    /// Stops watching. Safe to call more than once. The owner calls it before dropping the watcher.
    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
