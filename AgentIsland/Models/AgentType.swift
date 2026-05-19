import SwiftUI

enum AgentType: String, Codable, CaseIterable, Identifiable {
    case claudeCode = "claude_code"
    case codex = "codex"
    case geminiCLI = "gemini_cli"
    case cursor = "cursor"
    case openCode = "open_code"
    case droid = "droid"
    case qoder = "qoder"
    case qwen = "qwen"
    case kimiCode = "kimi_code"
    case deepseek = "deepseek"
    case copilot = "copilot"
    case codeBuddy = "code_buddy"
    case kiro = "kiro"
    case hermes = "hermes"
    case amp = "amp"
    case piAgent = "pi_agent"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeCode:  return "Claude Code"
        case .codex:       return "Codex"
        case .geminiCLI:   return "Gemini CLI"
        case .cursor:      return "Cursor"
        case .openCode:    return "OpenCode"
        case .droid:       return "Droid"
        case .qoder:       return "Qoder"
        case .qwen:        return "Qwen"
        case .kimiCode:    return "Kimi Code"
        case .deepseek:    return "DeepSeek"
        case .copilot:     return "Copilot"
        case .codeBuddy:   return "CodeBuddy"
        case .kiro:        return "Kiro"
        case .hermes:      return "Hermes"
        case .amp:         return "Amp"
        case .piAgent:     return "Pi Agent"
        }
    }

    /// Emoji icon — only for agents that use emoji instead of SF Symbols
    var emojiIcon: String? {
        switch self {
        case .claudeCode: return "\u{1F47E}"  // 👾
        default: return nil
        }
    }

    var sfSymbolName: String {
        switch self {
        case .claudeCode:  return "sparkles"
        case .codex:       return "terminal.fill"
        case .geminiCLI:   return "diamond.fill"
        case .cursor:      return "cursorarrow.rays"
        case .openCode:    return "chevron.left.forwardslash.chevron.right"
        case .droid:       return "cpu.fill"
        case .qoder:       return "qrcode"
        case .qwen:        return "brain.head.profile"
        case .kimiCode:    return "moon.stars.fill"
        case .deepseek:    return "magnifyingglass"
        case .copilot:     return "airplane"
        case .codeBuddy:   return "person.2.fill"
        case .kiro:        return "bolt.fill"
        case .hermes:      return "paperplane.fill"
        case .amp:         return "bolt.circle.fill"
        case .piAgent:     return "circle.hexagongrid.fill"
        }
    }

    /// Accent color for this agent
    var accentColor: Color {
        switch self {
        case .claudeCode:  return Color(red: 0.87, green: 0.47, blue: 0.36) // orange
        case .codex:       return Color(red: 0.20, green: 0.80, blue: 0.50) // green
        case .geminiCLI:   return Color(red: 0.30, green: 0.50, blue: 0.95) // blue
        case .cursor:      return Color(red: 0.60, green: 0.40, blue: 0.95) // purple
        case .openCode:    return Color(red: 0.95, green: 0.60, blue: 0.20) // amber
        case .deepseek:    return Color(red: 0.25, green: 0.65, blue: 0.90) // cyan
        case .copilot:     return Color(red: 0.30, green: 0.70, blue: 0.90) // sky
        case .kimiCode:    return Color(red: 0.85, green: 0.35, blue: 0.50) // rose
        case .kiro:        return Color(red: 0.30, green: 0.50, blue: 0.95) // blue
        default:           return Color(red: 0.60, green: 0.60, blue: 0.65) // gray
        }
    }

    /// Session directory path for this agent (where to discover sessions)
    var sessionDirectory: String? {
        switch self {
        case .claudeCode:  return "~/.claude/sessions"
        case .codex:       return "~/.codex/sessions"
        case .geminiCLI:   return "~/.gemini/sessions"
        default:           return nil // not yet supported for auto-discovery
        }
    }
}
