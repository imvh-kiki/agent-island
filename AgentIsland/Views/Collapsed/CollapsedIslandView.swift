import SwiftUI

struct CollapsedIslandView: View {
    let session: AgentSession

    var body: some View {
        HStack(spacing: 10) {
            // Agent icon
            AgentIconView(agentType: session.agentType, size: 14)

            // Two-line info
            VStack(alignment: .leading, spacing: 3) {
                Text(session.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    StatusBadge(status: session.status)

                    Text(session.status.displayText)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 4)

            // Right side: progress dots + elapsed time
            VStack(alignment: .trailing, spacing: 4) {
                if session.status.isActive {
                    ProgressDots(color: .white.opacity(0.6))
                }

                Text(session.elapsedText)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .frame(
            width: IslandSize.collapsedWidth,
            height: IslandSize.collapsedHeight
        )
    }
}
