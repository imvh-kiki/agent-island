import SwiftUI

enum IslandSpring {
    /// Primary expand/collapse — matches Apple Dynamic Island feel
    static let expand = Animation.spring(
        response: 0.35,
        dampingFraction: 0.78,
        blendDuration: 0.1
    )

    /// Permission/question prompt — snappy with subtle bounce to feel alive
    static let alert = Animation.spring(
        response: 0.3,
        dampingFraction: 0.72,
        blendDuration: 0.05
    )

    /// System response dismiss — fast, no bounce (Kowalski: fast where system is responding)
    static let dismiss = Animation.spring(
        response: 0.22,
        dampingFraction: 0.9,
        blendDuration: 0
    )

    /// Subtle size changes (status text update)
    static let micro = Animation.spring(
        response: 0.2,
        dampingFraction: 0.88,
        blendDuration: 0
    )
}
