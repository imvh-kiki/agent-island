import Foundation

/// Generic file system watcher using DispatchSource.
/// Monitors a file or directory for changes.
final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let path: String
    private let queue: DispatchQueue
    private var fileDescriptor: Int32 = -1

    init(path: String, queue: DispatchQueue = .global(qos: .utility)) {
        self.path = path
        self.queue = queue
    }

    deinit {
        stop()
    }

    /// Start watching for file write events
    func startWatching(onChange: @escaping () -> Void) {
        stop()

        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .rename],
            queue: queue
        )

        source.setEventHandler {
            onChange()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        self.source = source
        source.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}

/// Watches a directory for new/changed files
final class DirectoryWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let path: String
    private let queue: DispatchQueue
    private var fileDescriptor: Int32 = -1

    init(path: String, queue: DispatchQueue = .global(qos: .utility)) {
        self.path = path
        self.queue = queue
    }

    deinit {
        stop()
    }

    func startWatching(onChange: @escaping () -> Void) {
        stop()

        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write],
            queue: queue
        )

        source.setEventHandler {
            onChange()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        self.source = source
        source.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}
