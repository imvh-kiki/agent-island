import SwiftUI

struct PermissionRequestView: View {
    let session: AgentSession
    let request: PermissionRequest
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                AgentIconView(agentType: session.agentType, size: 16)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Permission Required")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)

                    Text(session.agentType.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                // Pulsing alert indicator
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
                    .modifier(PulseModifier())
            }

            // Tool info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: toolIcon(for: request.toolName))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(toolLabel(for: request.toolName))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text(request.displayDescription)
                    .font(.system(size: 11, design: isCommandTool(request.toolName) ? .monospaced : .default))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(4)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }

            Spacer(minLength: 0)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onDeny) {
                    Text("Deny")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(IslandButtonStyle())

                Button(action: onApprove) {
                    Text("Allow")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.indigo, in: Capsule())
                }
                .buttonStyle(IslandPrimaryButtonStyle())
            }
        }
        .padding(18)
        .frame(
            width: IslandSize.permissionWidth,
            height: IslandSize.permissionHeight
        )
    }

    private func toolIcon(for name: String) -> String {
        switch name {
        case "Bash": return "terminal"
        case "Edit": return "pencil"
        case "Write": return "doc.badge.plus"
        case "Read": return "doc.text"
        default: return "wrench"
        }
    }

    private func toolLabel(for name: String) -> String {
        switch name {
        case "Bash": return "Run command"
        case "Edit": return "Edit file"
        case "Write": return "Create file"
        case "Read": return "Read file"
        default: return name
        }
    }

    private func isCommandTool(_ name: String) -> Bool {
        name == "Bash"
    }
}

/// Pulsing animation modifier
struct PulseModifier: ViewModifier {
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 1.4 : 0.95)
            .opacity(pulsing ? 0.5 : 1.0)
            .animation(
                .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}
