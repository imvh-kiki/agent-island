import SwiftUI

struct FileActivityView: View {
    let activities: [AgentActivity]

    private var fileActivities: [AgentActivity] {
        activities.filter { activity in
            switch activity.kind {
            case .fileRead, .fileWrite: return true
            default: return false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Files")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)

            if fileActivities.isEmpty {
                Text("No file activity")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            } else {
                ForEach(fileActivities.suffix(5)) { activity in
                    HStack(spacing: 4) {
                        Image(systemName: activity.kind.iconSystemName)
                            .font(.system(size: 9))
                            .foregroundStyle(fileColor(activity.kind))
                            .frame(width: 12)

                        Text(activity.kind.displayText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func fileColor(_ kind: ActivityKind) -> Color {
        switch kind {
        case .fileRead: return .blue.opacity(0.7)
        case .fileWrite: return .green.opacity(0.7)
        default: return .white.opacity(0.5)
        }
    }
}
