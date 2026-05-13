import SwiftUI

struct IslandTransition {
    static func transition(from oldState: IslandState, to newState: IslandState) -> Animation {
        switch (oldState, newState) {
        case (.hidden, .collapsed):
            return IslandSpring.expand
        case (.collapsed, .expanded):
            return IslandSpring.expand
        case (.expanded, .collapsed):
            return IslandSpring.expand
        case (_, .permissionPrompt):
            return IslandSpring.alert
        case (.permissionPrompt, .collapsed):
            return IslandSpring.expand
        case (.collapsed, .hidden):
            return IslandSpring.micro
        default:
            return IslandSpring.micro
        }
    }
}
