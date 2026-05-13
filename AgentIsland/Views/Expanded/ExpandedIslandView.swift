import SwiftUI

struct ExpandedIslandView: View {
    let session: AgentSession
    let activities: [AgentActivity]
    let onCollapse: () -> Void
    let onJumpToTerminal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            header

            Divider()
                .background(.white.opacity(0.15))

            // Activity feed
            activityFeed

            Spacer(minLength: 0)

            // Action bar
            actionBar
        }
        .padding(16)
        .frame(
            width: IslandSize.expandedWidth,
            height: IslandSize.expandedHeight
        )
    }

    private var header: some View {
        HStack {
            AgentIconView(agentType: session.agentType, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.agentType.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    StatusBadge(status: session.status)
                    Text(session.status.displayText)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()

            // Collapse button
            Button(action: onCollapse) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var activityFeed: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                if activities.isEmpty {
                    Text("Waiting for activity...")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    ForEach(activities.suffix(8)) { activity in
                        ActivityRow(activity: activity)
                    }
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            // Jump to terminal
            Button(action: onJumpToTerminal) {
                Label("Terminal", systemImage: "terminal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            // Working directory
            Text(shortenCwd(session.cwd))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
        }
    }

    private func shortenCwd(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

struct ActivityRow: View {
    let activity: AgentActivity

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: activity.kind.iconSystemName)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 14)

            Text(activity.kind.displayText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(timeAgo(activity.timestamp))
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 5 { return "now" }
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        return "\(minutes)m"
    }
}
