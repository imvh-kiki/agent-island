import Foundation

/// Parses Claude Code JSONL log entries into AgentActivity events
enum LogParser {

    /// Parse a single JSONL line (already deserialized) into activities
    static func parse(_ json: [String: Any], sessionId: String) -> [AgentActivity] {
        guard let type = json["type"] as? String else { return [] }

        switch type {
        case "assistant":
            return parseAssistantMessage(json, sessionId: sessionId)
        case "user":
            return parseUserMessage(json, sessionId: sessionId)
        case "system":
            return parseSystemMessage(json, sessionId: sessionId)
        default:
            return []
        }
    }

    /// Extract the current session status from a log entry
    static func extractStatus(_ json: [String: Any]) -> SessionStatus? {
        guard let type = json["type"] as? String else { return nil }

        switch type {
        case "assistant":
            if let message = json["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]] {

                // Check for tool_use blocks — means executing a tool
                for block in content {
                    if block["type"] as? String == "tool_use",
                       let name = block["name"] as? String {
                        return .executingTool(toolName: name)
                    }
                    if block["type"] as? String == "thinking" {
                        return .thinking
                    }
                }

                // Text-only response means Claude is outputting, not thinking
                return .idle
            }
        case "result":
            // A result entry means the turn is complete
            return .idle
        case "system":
            if let subtype = json["subtype"] as? String, subtype == "turn_duration" {
                return .idle
            }
        default:
            break
        }

        return nil
    }

    // MARK: - Private

    private static func parseAssistantMessage(_ json: [String: Any], sessionId: String) -> [AgentActivity] {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            return []
        }

        var activities: [AgentActivity] = []
        let timestamp = extractTimestamp(json)

        for block in content {
            guard let blockType = block["type"] as? String else { continue }

            switch blockType {
            case "thinking":
                activities.append(AgentActivity(
                    id: UUID(),
                    timestamp: timestamp,
                    sessionId: sessionId,
                    kind: .thinking
                ))

            case "tool_use":
                if let toolName = block["name"] as? String,
                   let input = block["input"] as? [String: Any] {
                    let activity = parseToolUse(toolName: toolName, input: input,
                                                 timestamp: timestamp, sessionId: sessionId)
                    activities.append(activity)
                }

            case "text":
                if let text = block["text"] as? String, !text.isEmpty {
                    activities.append(AgentActivity(
                        id: UUID(),
                        timestamp: timestamp,
                        sessionId: sessionId,
                        kind: .textOutput(preview: String(text.prefix(100)))
                    ))
                }

            default:
                break
            }
        }

        return activities
    }

    private static func parseUserMessage(_ json: [String: Any], sessionId: String) -> [AgentActivity] {
        // User messages contain tool_result blocks
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            return []
        }

        var activities: [AgentActivity] = []
        let timestamp = extractTimestamp(json)

        for block in content {
            if block["type"] as? String == "tool_result",
               let toolName = block["tool_name"] as? String ?? inferToolName(from: block) {
                let isError = block["is_error"] as? Bool ?? false
                activities.append(AgentActivity(
                    id: UUID(),
                    timestamp: timestamp,
                    sessionId: sessionId,
                    kind: .toolResult(toolName: toolName, isError: isError)
                ))
            }
        }

        return activities
    }

    private static func parseSystemMessage(_ json: [String: Any], sessionId: String) -> [AgentActivity] {
        // System messages are mostly turn_duration events
        return []
    }

    private static func parseToolUse(toolName: String, input: [String: Any],
                                      timestamp: Date, sessionId: String) -> AgentActivity {
        let kind: ActivityKind

        switch toolName {
        case "Read":
            let path = input["file_path"] as? String ?? "unknown"
            kind = .fileRead(path: path)

        case "Write":
            let path = input["file_path"] as? String ?? "unknown"
            kind = .fileWrite(path: path)

        case "Edit":
            let path = input["file_path"] as? String ?? "unknown"
            kind = .fileWrite(path: path)

        case "Bash":
            let command = input["command"] as? String ?? ""
            let desc = input["description"] as? String
            kind = .bashCommand(command: command, description: desc)

        case "TaskCreate":
            let subject = input["subject"] as? String ?? "task"
            kind = .taskCreated(subject: subject)

        case "TaskUpdate":
            let status = input["status"] as? String
            if status == "completed" {
                kind = .taskCompleted(subject: "task")
            } else {
                kind = .toolUse(name: toolName, description: nil)
            }

        default:
            let desc = input["description"] as? String
            kind = .toolUse(name: toolName, description: desc)
        }

        return AgentActivity(
            id: UUID(),
            timestamp: timestamp,
            sessionId: sessionId,
            kind: kind
        )
    }

    private static func extractTimestamp(_ json: [String: Any]) -> Date {
        if let ts = json["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: ts) ?? Date()
        }
        return Date()
    }

    private static func inferToolName(from block: [String: Any]) -> String? {
        // Sometimes tool_result doesn't have tool_name, try to infer
        if let content = block["content"] as? String {
            if content.contains("file_path") { return "Read" }
        }
        return nil
    }
}
