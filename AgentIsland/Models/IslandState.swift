import SwiftUI

enum IslandState: Equatable {
    case hidden
    case collapsed(AgentSession)
    case expanded(AgentSession)
    case permissionPrompt(AgentSession, PermissionRequest)
    case multiSession([AgentSession])

    static func == (lhs: IslandState, rhs: IslandState) -> Bool {
        switch (lhs, rhs) {
        case (.hidden, .hidden):
            return true
        case (.collapsed(let a), .collapsed(let b)):
            return a.id == b.id
        case (.expanded(let a), .expanded(let b)):
            return a.id == b.id
        case (.permissionPrompt(let a, let p1), .permissionPrompt(let b, let p2)):
            return a.id == b.id && p1.id == p2.id
        case (.multiSession(let a), .multiSession(let b)):
            return a.map(\.id) == b.map(\.id)
        default:
            return false
        }
    }

    var isInteractive: Bool {
        switch self {
        case .hidden, .collapsed: return false
        case .expanded, .permissionPrompt, .multiSession: return true
        }
    }

    var panelSize: CGSize {
        switch self {
        case .hidden:
            return .zero
        case .collapsed:
            return CGSize(width: IslandSize.collapsedWidth, height: IslandSize.collapsedHeight)
        case .expanded:
            return CGSize(width: IslandSize.expandedWidth, height: IslandSize.expandedHeight)
        case .permissionPrompt:
            return CGSize(width: IslandSize.permissionWidth, height: IslandSize.permissionHeight)
        case .multiSession:
            return CGSize(width: IslandSize.expandedWidth, height: IslandSize.expandedHeight)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .hidden, .collapsed:
            return IslandSize.cornerRadius
        case .expanded, .permissionPrompt, .multiSession:
            return IslandSize.expandedCornerRadius
        }
    }
}

enum IslandSize {
    static let collapsedWidth: CGFloat = 220
    static let collapsedHeight: CGFloat = 36
    static let expandedWidth: CGFloat = 380
    static let expandedHeight: CGFloat = 260
    static let permissionWidth: CGFloat = 380
    static let permissionHeight: CGFloat = 200
    static let cornerRadius: CGFloat = 18
    static let expandedCornerRadius: CGFloat = 24
}
