import Foundation
import Combine

/// Watches Claude Code JSONL log files for real-time updates.
/// Uses DispatchSource to detect file writes and parse new events.
final class LogWatcher {
    private var watchers: [String: FileWatcher] = [:]      // sessionId -> watcher
    private var readers: [String: JSONLReader] = [:]         // sessionId -> reader
    private let queue = DispatchQueue(label: "log-watcher", qos: .utility)

    let activities = PassthroughSubject<AgentActivity, Never>()
    let statusUpdates = PassthroughSubject<(sessionId: String, status: SessionStatus), Never>()

    /// Start watching a session's log file
    func watchSession(id sessionId: String, logPath: URL) {
        // Don't double-watch
        guard watchers[sessionId] == nil else { return }

        let reader = JSONLReader(fileURL: logPath)
        // Seek to end — only process new events
        reader.seekToEnd()
        readers[sessionId] = reader

        let watcher = FileWatcher(path: logPath.path, queue: queue)
        watcher.startWatching { [weak self] in
            self?.processNewLines(sessionId: sessionId)
        }
        watchers[sessionId] = watcher
    }

    /// Stop watching a session
    func unwatchSession(id sessionId: String) {
        watchers[sessionId]?.stop()
        watchers.removeValue(forKey: sessionId)
        readers.removeValue(forKey: sessionId)
    }

    /// Stop all watchers
    func stopAll() {
        for (_, watcher) in watchers {
            watcher.stop()
        }
        watchers.removeAll()
        readers.removeAll()
    }

    // MARK: - Private

    private func processNewLines(sessionId: String) {
        guard let reader = readers[sessionId] else { return }

        let lines = reader.readNewLines()
        for json in lines {
            // Parse activities
            let newActivities = LogParser.parse(json, sessionId: sessionId)
            for activity in newActivities {
                activities.send(activity)
            }

            // Extract status updates
            if let status = LogParser.extractStatus(json) {
                statusUpdates.send((sessionId: sessionId, status: status))
            }
        }
    }
}
