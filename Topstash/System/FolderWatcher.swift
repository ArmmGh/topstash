import CoreServices
import Foundation
import os
import TopstashCore

/// Watches the notes folder with FSEvents and calls `onChange` once per batch of changes.
/// File-level events catch in-place edits (`echo >> note.md`) that a directory `DispatchSource` misses.
/// The stream latency is the debounce. If the folder itself is deleted or moved, `onChange` is called too.
@MainActor
final class FolderWatcher {
    let folder: URL
    private let latency: TimeInterval
    private let onChange: @MainActor () -> Void
    private var stream: FSEventStreamRef?

    private static let logger = Logger(category: "FolderWatcher")

    init(folder: URL, latency: TimeInterval = 0.3, onChange: @escaping @MainActor () -> Void) {
        self.folder = folder
        self.latency = latency
        self.onChange = onChange
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
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            // Delivered on the main queue (see `FSEventStreamSetDispatchQueue` below).
            MainActor.assumeIsolated {
                Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().onChange()
            }
        }
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [folder.path(percentEncoded: false)] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
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
