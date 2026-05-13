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
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
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
            .overlay(
                Circle()
                    .fill(color.opacity(0.4))
                    .frame(width: 12, height: 12)
                    .opacity(status.isActive ? 1 : 0)
                    .scaleEffect(status.isActive ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: status.isActive
                    )
            )
    }
}
