import SwiftUI

/// Animated thinking/working dots indicator
struct ProgressDots: View {
    @State private var animating = false
    let count: Int = 3
    let color: Color

    init(color: Color = .white.opacity(0.8)) {
        self.color = color
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
                    .scaleEffect(animating ? 1.0 : 0.6)
                    .opacity(animating ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.12),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - Button Styles

/// Press feedback: scale(0.97) on press — buttons must feel responsive (Emil Kowalski)
struct IslandButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .brightness(isHovered && !configuration.isPressed ? 0.05 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

/// Primary action button (indigo Allow / Send / Approve) with glow shadow
struct IslandPrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : (isHovered ? 0.05 : 0))
            .shadow(color: .indigo.opacity(isHovered ? 0.5 : 0.3), radius: isHovered ? 12 : 8, y: 2)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

/// Color-coded status indicator dot
struct StatusBadge: View {
    let status: SessionStatus

    var color: Color {
        switch status {
        case .idle: return .gray
        case .thinking: return .yellow
        case .executingTool: return .green
        case .waitingForPermission: return .orange
        case .waitingForInput: return .blue
        case .completed: return .green
        case .error: return .red
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .shadow(color: color.opacity(status.isActive ? 0.5 : 0.2), radius: status.isActive ? 4 : 2)
            .overlay(
                Circle()
                    .fill(color.opacity(0.35))
                    .frame(width: 12, height: 12)
                    .opacity(status.isActive ? 1 : 0)
                    .scaleEffect(status.isActive ? 1.3 : 0.9)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                        value: status.isActive
                    )
            )
    }
}
