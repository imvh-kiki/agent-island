import SwiftUI

enum IslandSpring {
    /// Primary expand/collapse — matches Apple Dynamic Island feel
    static let expand = Animation.spring(
        response: 0.35,
        dampingFraction: 0.75,
        blendDuration: 0.1
    )

    /// Permission prompt urgency — slightly faster
    static let alert = Animation.spring(
        response: 0.28,
        dampingFraction: 0.7,
        blendDuration: 0.05
    )

    /// Subtle size changes (status text update)
    static let micro = Animation.spring(
        response: 0.2,
        dampingFraction: 0.85,
        blendDuration: 0
    )
}
