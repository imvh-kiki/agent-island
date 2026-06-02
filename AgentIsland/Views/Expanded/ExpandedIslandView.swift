import SwiftUI

struct ExpandedIslandView: View {
    let session: AgentSession
    let activities: [AgentActivity]
    let onCollapse: () -> Void
    let onJumpToTerminal: () -> Void
    let onDismiss: () -> Void
    var showBackButton: Bool = false
    @ObservedObject private var usageTracker = UsageTracker.shared

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
        .padding(18)
        .frame(
            width: IslandSize.expandedWidth,
            height: IslandSize.expandedHeight
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            AgentIconView(agentType: session.agentType, size: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    StatusBadge(status: session.status)
                    Text(session.status.displayText)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))

                    Text("·")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.25))

                    Text(session.elapsedText)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            // Dismiss session button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(IslandButtonStyle())
            .help("Dismiss session")

            // Back / Collapse button
            Button(action: onCollapse) {
                Image(systemName: showBackButton ? "chevron.left" : "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(IslandButtonStyle())
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
                    let items = Array(activities.suffix(8))
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, activity in
                        ActivityRow(activity: activity)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: activities.count)
        }
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            // Usage stats
            usageBar

            HStack(spacing: 10) {
                // Jump to terminal
                Button(action: onJumpToTerminal) {
                    Label("Terminal", systemImage: "terminal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(IslandButtonStyle())

                Spacer()

                // Working directory
                Text(shortenCwd(session.cwd))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }
        }
    }

    private var usageBar: some View {
        HStack(spacing: 12) {
            let stats = usageTracker.stats
            Label(stats.formattedTokens + " tokens", systemImage: "square.stack.3d.up")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))

            Label(stats.formattedCost, systemImage: "dollarsign.circle")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))

            Spacer()

            Label("\(stats.requestCount) reqs", systemImage: "arrow.up.arrow.down")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
    }

    private func shortenCwd(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

struct ActivityRow: View {
    let activity: AgentActivity
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: activity.kind.iconSystemName)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(isHovered ? 0.55 : 0.4))
                .frame(width: 14)

            Text(activity.kind.displayText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(isHovered ? 0.8 : 0.65))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(timeAgo(activity.timestamp))
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            isHovered ? Color.white.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .onHover { over in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = over }
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
