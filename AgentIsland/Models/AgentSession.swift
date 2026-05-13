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
