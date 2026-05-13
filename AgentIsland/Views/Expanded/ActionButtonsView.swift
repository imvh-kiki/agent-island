import SwiftUI

struct ActionButtonsView: View {
    let onJumpToTerminal: () -> Void
    let onMarkComplete: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            IslandButton(
                title: "Terminal",
                icon: "terminal",
                action: onJumpToTerminal
            )

            if let onMarkComplete {
                IslandButton(
                    title: "Complete",
                    icon: "checkmark.circle",
                    style: .accent,
                    action: onMarkComplete
                )
            }
        }
    }
}

struct IslandButton: View {
    let title: String
    let icon: String
    var style: ButtonStyle = .normal
    let action: () -> Void

    enum ButtonStyle {
        case normal
        case accent
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(backgroundColor, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch style {
        case .normal: return .white.opacity(0.8)
        case .accent: return .black
        }
    }

    private var backgroundColor: some ShapeStyle {
        switch style {
        case .normal: return AnyShapeStyle(.white.opacity(0.1))
        case .accent: return AnyShapeStyle(.green)
        }
    }
}
