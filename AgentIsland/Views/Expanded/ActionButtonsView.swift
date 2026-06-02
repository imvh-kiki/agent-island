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
    var style: ButtonVariant = .normal
    let action: () -> Void
    @State private var isHovered = false

    enum ButtonVariant {
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
                .background(currentBackground, in: Capsule())
                .shadow(
                    color: style == .accent ? .indigo.opacity(isHovered ? 0.5 : 0.3) : .clear,
                    radius: isHovered ? 12 : 8, y: 2
                )
                .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .brightness(isHovered ? 0.05 : 0)
        .onHover { isHovered = $0 }
    }

    private var foregroundColor: Color {
        switch style {
        case .normal: return isHovered ? .white.opacity(0.9) : .white.opacity(0.8)
        case .accent: return .white
        }
    }

    private var currentBackground: AnyShapeStyle {
        switch style {
        case .normal: return AnyShapeStyle(.white.opacity(isHovered ? 0.14 : 0.1))
        case .accent: return AnyShapeStyle(.indigo)
        }
    }
}
