import Foundation
import Combine

/// Watches Claude Code JSONL log files for real-time updates.
/// Uses DispatchSource to detect file writes and parse new events.
/// All dictionary access is serialized on `queue` to prevent race conditions.
final class LogWatcher {
    private var watchers: [String: FileWatcher] = [:]      // sessionId -> watcher
    private var readers: [String: JSONLReader] = [:]         // sessionId -> reader
    private let queue = DispatchQueue(label: "log-watcher", qos: .utility)

    let activities = PassthroughSubject<AgentActivity, Never>()
    let statusUpdates = PassthroughSubject<(sessionId: String, status: SessionStatus), Never>()

    /// Start watching a session's log file
    func watchSession(id sessionId: String, logPath: URL) {
        queue.async { [weak self] in
            guard let self, self.watchers[sessionId] == nil else { return }

            let reader = JSONLReader(fileURL: logPath)
            reader.seekToEnd()
            self.readers[sessionId] = reader

            let watcher = FileWatcher(path: logPath.path, queue: self.queue)
            watcher.startWatching { [weak self] in
                self?.processNewLines(sessionId: sessionId)
            }
            self.watchers[sessionId] = watcher
        }
    }

    /// Stop watching a session
    func unwatchSession(id sessionId: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.watchers[sessionId]?.stop()
            self.watchers.removeValue(forKey: sessionId)
            self.readers.removeValue(forKey: sessionId)
        }
    }

    /// Stop all watchers
    func stopAll() {
        queue.async { [weak self] in
            guard let self else { return }
            for (_, watcher) in self.watchers { watcher.stop() }
            self.watchers.removeAll()
            self.readers.removeAll()
        }
    }

    // MARK: - Private (always called on `queue`)

    private func processNewLines(sessionId: String) {
        guard let reader = readers[sessionId] else { return }

        let lines = reader.readNewLines()
        for json in lines {
            let newActivities = LogParser.parse(json, sessionId: sessionId)
            for activity in newActivities {
                activities.send(activity)
            }

            UsageTracker.shared.processLogLine(json, sessionId: sessionId)

            if let status = LogParser.extractStatus(json) {
                statusUpdates.send((sessionId: sessionId, status: status))
            }
        }
    }
}
