import SwiftUI

enum IslandState: Equatable {
    case hidden
    case collapsed(AgentSession)
    case expanded(AgentSession)
    case permissionPrompt(AgentSession, PermissionRequest)
    case askQuestion(AgentSession, UserQuestion)
    case planReview(AgentSession, PlanReview)
    case multiSession([AgentSession])
    case expandedMulti([AgentSession])

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
        case (.askQuestion(let a, let q1), .askQuestion(let b, let q2)):
            return a.id == b.id && q1.id == q2.id
        case (.planReview(let a, let p1), .planReview(let b, let p2)):
            return a.id == b.id && p1.id == p2.id
        case (.multiSession(let a), .multiSession(let b)):
            return a.map(\.id) == b.map(\.id)
        case (.expandedMulti(let a), .expandedMulti(let b)):
            return a.map(\.id) == b.map(\.id)
        default:
            return false
        }
    }

    var isInteractive: Bool {
        switch self {
        case .hidden, .collapsed, .multiSession: return false
        case .expanded, .permissionPrompt, .askQuestion, .planReview, .expandedMulti: return true
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
        case .askQuestion:
            return CGSize(width: IslandSize.questionWidth, height: IslandSize.questionHeight)
        case .planReview:
            return CGSize(width: IslandSize.planReviewWidth, height: IslandSize.planReviewHeight)
        case .multiSession(let sessions):
            let count = max(sessions.count, 2)
            let height = IslandSize.collapsedHeight + CGFloat(count - 1) * IslandSize.multiSessionRowHeight
            return CGSize(width: IslandSize.collapsedWidth, height: height)
        case .expandedMulti(let sessions):
            let count = max(sessions.count, 2)
            let height = min(IslandSize.expandedMultiMaxHeight,
                             IslandSize.expandedMultiHeaderHeight + CGFloat(count) * IslandSize.expandedMultiRowHeight)
            return CGSize(width: IslandSize.expandedWidth, height: height)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .hidden, .collapsed, .multiSession:
            return IslandSize.cornerRadius
        case .expanded, .permissionPrompt, .askQuestion, .planReview, .expandedMulti:
            return IslandSize.expandedCornerRadius
        }
    }
}

enum IslandSize {
    static let collapsedWidth: CGFloat = 280
    static let collapsedHeight: CGFloat = 48
    static let expandedWidth: CGFloat = 380
    static let expandedHeight: CGFloat = 280
    static let permissionWidth: CGFloat = 380
    static let permissionHeight: CGFloat = 220
    static let questionWidth: CGFloat = 380
    static let questionHeight: CGFloat = 300
    static let planReviewWidth: CGFloat = 380
    static let planReviewHeight: CGFloat = 380
    static let cornerRadius: CGFloat = 24
    static let expandedCornerRadius: CGFloat = 24

    // Multi-session sizes
    static let multiSessionRowHeight: CGFloat = 34
    static let expandedMultiHeaderHeight: CGFloat = 80
    static let expandedMultiRowHeight: CGFloat = 60
    static let expandedMultiMaxHeight: CGFloat = 380
}
