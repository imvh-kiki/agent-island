import Foundation

struct AgentSession: Identifiable, Equatable {
    let id: String               // session UUID
    let agentType: AgentType
    let pid: Int
    let cwd: String
    let startedAt: Date
    var status: SessionStatus = .idle
    var currentTask: String?
    var lastActivity: AgentActivity?
    var sessionName: String?

    /// Elapsed time since session started, e.g. "5m", "2h 10m"
    var elapsedText: String {
        let seconds = Int(Date().timeIntervalSince(startedAt))
        if seconds < 60 { return "<1m" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 { return "\(hours)h" }
        return "\(hours)h \(remainingMinutes)m"
    }

    /// Display name priority: sessionName > cwd folder > agent type
    var displayName: String {
        if let name = sessionName, !name.isEmpty {
            return name
        }
        let shortened = cwd.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        let parts = shortened.split(separator: "/")
        if let last = parts.last, last != "~" {
            return "\(agentType.displayName) · \(last)"
        }
        return agentType.displayName
    }

    static func == (lhs: AgentSession, rhs: AgentSession) -> Bool {
        lhs.id == rhs.id &&
        lhs.status == rhs.status &&
        lhs.currentTask == rhs.currentTask
    }
}

enum SessionStatus: Equatable {
    case idle
    case thinking
    case executingTool(toolName: String)
    case waitingForPermission
    case waitingForInput
    case completed
    case error(String)

    var displayText: String {
        switch self {
        case .idle: return "Idle"
        case .thinking: return "Thinking..."
        case .executingTool(let name): return "Running \(name)"
        case .waitingForPermission: return "Waiting for approval"
        case .waitingForInput: return "Waiting for input"
        case .completed: return "Done"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var isActive: Bool {
        switch self {
        case .idle, .completed, .error: return false
        default: return true
        }
    }
}
