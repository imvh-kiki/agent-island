import SwiftUI

/// Expanded multi-session view: session cards list
struct SessionListView: View {
    let sessions: [AgentSession]
    let onSelectSession: (AgentSession) -> Void
    let onDismissSession: (AgentSession) -> Void
    let onCollapse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Divider()
                .background(.white.opacity(0.15))

            sessionList

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var header: some View {
        HStack {
            Text("\(sessions.count) Active Sessions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

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

    private var sessionList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(sessions) { session in
                    SessionCard(session: session, onDismiss: { onDismissSession(session) })
                        .onTapGesture {
                            onSelectSession(session)
                        }
                }
            }
        }
    }
}

/// Individual session card in the expanded multi-session list
private struct SessionCard: View {
    let session: AgentSession
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            AgentIconView(agentType: session.agentType, size: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    StatusBadge(status: session.status)

                    Text(session.status.displayText)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))

                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.2))

                    Text(session.elapsedText)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            Spacer(minLength: 4)

            if session.status.isActive {
                ProgressDots(color: .white.opacity(0.5))
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.25))
                    .frame(width: 20, height: 20)
                    .background(.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(IslandButtonStyle())

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func shortenCwd(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
