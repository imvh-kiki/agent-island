import SwiftUI

/// Collapsed multi-session view: vertically stacked session rows
struct CollapsedMultiView: View {
    let sessions: [AgentSession]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                sessionRow(session)
                if index < sessions.count - 1 {
                    Divider()
                        .background(.white.opacity(0.08))
                        .padding(.horizontal, 14)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func sessionRow(_ session: AgentSession) -> some View {
        HStack(spacing: 8) {
            AgentIconView(agentType: session.agentType, size: 12)

            HStack(spacing: 6) {
                StatusBadge(status: session.status)

                Text(sessionLabel(session))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 4)

            if session.status.isActive {
                ProgressDots(color: .white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: IslandSize.multiSessionRowHeight)
    }

    private func sessionLabel(_ session: AgentSession) -> String {
        if let task = session.currentTask {
            return task
        }
        let cwd = session.cwd.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        let lastComponent = (cwd as NSString).lastPathComponent
        return "\(session.status.displayText) · \(lastComponent)"
    }
}
