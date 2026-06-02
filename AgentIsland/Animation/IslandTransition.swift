import SwiftUI

struct IslandTransition {
    static func transition(from oldState: IslandState, to newState: IslandState) -> Animation {
        switch (oldState, newState) {
        case (.hidden, .collapsed), (.hidden, .multiSession):
            return IslandSpring.expand
        case (.collapsed, .midExpanded), (.collapsed, .expanded), (.multiSession, .expandedMulti):
            return IslandSpring.expand
        case (.midExpanded, .collapsed), (.expanded, .collapsed), (.expandedMulti, .multiSession):
            return IslandSpring.dismiss
        case (.midExpanded, .expanded):
            return IslandSpring.expand
        case (.expanded, .midExpanded):
            return IslandSpring.dismiss
        case (.expanded, .multiSession), (.collapsed, .multiSession):
            return IslandSpring.expand
        case (.multiSession, .collapsed), (.expandedMulti, .collapsed):
            return IslandSpring.expand
        case (_, .permissionPrompt), (_, .askQuestion), (_, .planReview):
            return IslandSpring.alert
        case (.permissionPrompt, .collapsed), (.permissionPrompt, .multiSession),
             (.askQuestion, .collapsed), (.askQuestion, .multiSession),
             (.planReview, .collapsed), (.planReview, .multiSession):
            return IslandSpring.dismiss
        case (.collapsed, .hidden), (.multiSession, .hidden):
            return IslandSpring.micro
        default:
            return IslandSpring.micro
        }
    }
}
