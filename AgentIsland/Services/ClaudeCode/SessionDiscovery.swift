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
            if let ms = json["startedAt"] as? Double {
                startedAt = Date(timeIntervalSince1970: ms / 1000)
            } else if let ms = json["startedAt"] as? Int {
                startedAt = Date(timeIntervalSince1970: Double(ms) / 1000)
            } else {
                startedAt = Date()
            }

            var sessionName = json["name"] as? String

            // Fallback: extract first user message from JSONL log as session context
            if sessionName == nil || sessionName?.isEmpty == true {
                sessionName = extractFirstUserMessage(sessionId: sessionId, cwd: cwd)
            }

            let session = AgentSession(
                id: sessionId,
                agentType: .claudeCode,
                pid: pid,
                cwd: cwd,
                startedAt: startedAt,
                status: .idle,
                sessionName: sessionName
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
        // e.g., "/Users/jane" -> "-Users-jane"
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

    /// Read the first user message from a session's JSONL log as a fallback display name.
    /// This tells users what the session is working on (e.g., "幫我建立 Agent Island").
    private func extractFirstUserMessage(sessionId: String, cwd: String) -> String? {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        let encodedCwd = cwd.replacingOccurrences(of: "/", with: "-")
        let logFile = projectsDir.appendingPathComponent(encodedCwd)
            .appendingPathComponent("\(sessionId).jsonl")

        guard let handle = try? FileHandle(forReadingFrom: logFile) else {
            // Fallback: search all project dirs
            guard let dirs = try? FileManager.default.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else {
                return nil
            }
            for dir in dirs {
                let candidate = dir.appendingPathComponent("\(sessionId).jsonl")
                if let result = readFirstUserMessage(from: candidate) {
                    return result
                }
            }
            return nil
        }
        defer { handle.closeFile() }

        return readFirstUserMessage(from: logFile)
    }

    /// Parse first user message from a JSONL file (reads only the first ~8KB for speed)
    private func readFirstUserMessage(from url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }

        // Read only the first chunk — user message is typically in the first few lines
        let chunk = handle.readData(ofLength: 8192)
        guard let text = String(data: chunk, encoding: .utf8) else { return nil }

        for line in text.components(separatedBy: "\n") {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let msg = json["message"] as? [String: Any]
            guard msg?["role"] as? String == "user" else { continue }

            let content = msg?["content"]

            // String content (simple user message)
            if let text = content as? String, !text.isEmpty {
                return truncateMessage(text)
            }

            // Array content (may contain text blocks)
            if let parts = content as? [[String: Any]] {
                for part in parts {
                    if part["type"] as? String == "text",
                       let text = part["text"] as? String, !text.isEmpty {
                        return truncateMessage(text)
                    }
                }
            }
        }

        return nil
    }

    /// Truncate to a clean, readable summary (max ~50 chars, break at word boundary)
    private func truncateMessage(_ text: String) -> String {
        // Remove newlines and excess whitespace
        let cleaned = text.components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        guard cleaned.count > 50 else { return cleaned }

        // Break at word boundary
        let prefix = String(cleaned.prefix(50))
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[prefix.startIndex..<lastSpace]) + "…"
        }
        return prefix + "…"
    }
}
