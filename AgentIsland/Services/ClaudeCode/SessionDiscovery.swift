import Foundation

/// Discovers active Claude Code sessions from ~/.claude/sessions/
final class SessionDiscovery {
    private let sessionsDir: URL

    init() {
        sessionsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/sessions")
    }

    /// Scan for active Claude Code sessions
    func discoverSessions() -> [AgentSession] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: nil) else {
            return []
        }

        var sessions: [AgentSession] = []

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            guard let pid = json["pid"] as? Int,
                  let sessionId = json["sessionId"] as? String,
                  let cwd = json["cwd"] as? String else {
                continue
            }

            // Check if process is still running
            guard ProcessUtils.isProcessRunning(pid: pid) else {
                continue
            }

            let startedAt: Date
            if let timestamp = json["startedAt"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                startedAt = formatter.date(from: timestamp) ?? Date()
            } else {
                startedAt = Date()
            }

            let session = AgentSession(
                id: sessionId,
                agentType: .claudeCode,
                pid: pid,
                cwd: cwd,
                startedAt: startedAt,
                status: .idle
            )
            sessions.append(session)
        }

        return sessions.sorted { $0.startedAt > $1.startedAt }
    }

    /// Get the JSONL log path for a session
    func logPath(for session: AgentSession) -> URL? {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        // Encode cwd to project directory name
        // e.g., "/Users/vickyhsu" -> "-Users-vickyhsu"
        let encodedCwd = session.cwd.replacingOccurrences(of: "/", with: "-")

        let projectDir = projectsDir.appendingPathComponent(encodedCwd)
        let logFile = projectDir.appendingPathComponent("\(session.id).jsonl")

        if FileManager.default.fileExists(atPath: logFile.path) {
            return logFile
        }

        // Fallback: search all project directories
        guard let dirs = try? FileManager.default.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else {
            return nil
        }

        for dir in dirs {
            let candidate = dir.appendingPathComponent("\(session.id).jsonl")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }
}
