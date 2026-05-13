import Foundation

enum AgentType: String, Codable, CaseIterable, Identifiable {
    case claudeCode = "claude_code"
    // Future agents
    // case cursor = "cursor"
    // case codex = "codex"
    // case geminiCLI = "gemini_cli"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        }
    }

    var iconName: String {
        switch self {
        case .claudeCode: return "claude-8bit"
        }
    }

    var accentColor: String {
        switch self {
        case .claudeCode: return "ClaudeOrange"
        }
    }
}
