import SwiftUI

struct PermissionRequestView: View {
    let session: AgentSession
    let request: PermissionRequest
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                AgentIconView(agentType: session.agentType, size: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Permission Required")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)

                    Text(session.agentType.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
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
                    Image(systemName: "wrench")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(request.toolName)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text(request.displayDescription)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(3)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }

            Spacer(minLength: 0)

            // Action buttons
            HStack(spacing: 10) {
                Button(action: onDeny) {
                    Text("Deny")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onApprove) {
                    Text("Allow")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.green, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(
            width: IslandSize.permissionWidth,
            height: IslandSize.permissionHeight
        )
    }
}

/// Pulsing animation modifier
struct PulseModifier: ViewModifier {
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 1.3 : 1.0)
            .opacity(pulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}
