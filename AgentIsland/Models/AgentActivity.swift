import Foundation

struct AgentActivity: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let sessionId: String
    let kind: ActivityKind

    static func == (lhs: AgentActivity, rhs: AgentActivity) -> Bool {
        lhs.id == rhs.id
    }
}

enum ActivityKind: Equatable {
    case toolUse(name: String, description: String?)
    case toolResult(toolName: String, isError: Bool)
    case fileRead(path: String)
    case fileWrite(path: String)
    case bashCommand(command: String, description: String?)
    case thinking
    case textOutput(preview: String)
    case taskCreated(subject: String)
    case taskCompleted(subject: String)

    var displayText: String {
        switch self {
        case .toolUse(let name, let desc):
            return desc ?? "Using \(name)"
        case .toolResult(let name, let isError):
            return isError ? "\(name) failed" : "\(name) done"
        case .fileRead(let path):
            return "Read \(shortenPath(path))"
        case .fileWrite(let path):
            return "Write \(shortenPath(path))"
        case .bashCommand(let cmd, _):
            let truncated = cmd.prefix(60)
            return "$ \(truncated)\(cmd.count > 60 ? "..." : "")"
        case .thinking:
            return "Thinking..."
        case .textOutput(let preview):
            return String(preview.prefix(80))
        case .taskCreated(let subject):
            return "Task: \(subject)"
        case .taskCompleted(let subject):
            return "Done: \(subject)"
        }
    }

    var iconSystemName: String {
        switch self {
        case .toolUse: return "wrench"
        case .toolResult(_, let isError): return isError ? "xmark.circle" : "checkmark.circle"
        case .fileRead: return "doc.text"
        case .fileWrite: return "pencil"
        case .bashCommand: return "terminal"
        case .thinking: return "brain"
        case .textOutput: return "text.bubble"
        case .taskCreated: return "plus.circle"
        case .taskCompleted: return "checkmark.seal"
        }
    }
}

private func shortenPath(_ path: String) -> String {
    let components = path.split(separator: "/")
    if components.count <= 2 {
        return path
    }
    return "../\(components.suffix(2).joined(separator: "/"))"
}
