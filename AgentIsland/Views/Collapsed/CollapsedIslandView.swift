import SwiftUI

struct CollapsedIslandView: View {
    let session: AgentSession

    var body: some View {
        HStack(spacing: 10) {
            // Agent 8-bit icon
            AgentIconView(agentType: session.agentType, size: 22)

            // Status indicator
            StatusBadge(status: session.status)

            // Status text
            statusText

            Spacer(minLength: 0)

            // Activity indicator when working
            if session.status.isActive {
                ProgressDots()
            }
        }
        .padding(.horizontal, 14)
        .frame(
            width: IslandSize.collapsedWidth,
            height: IslandSize.collapsedHeight
        )
    }

    @ViewBuilder
    private var statusText: some View {
        if let task = session.currentTask {
            Text(task)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
        } else {
            Text(session.status.displayText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
    }
}
