import SwiftUI

struct MidExpandedIslandView: View {
    let session: AgentSession
    let latestActivity: AgentActivity?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Status line
            HStack(spacing: 8) {
                StatusBadge(status: session.status)

                Text(session.status.displayText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)

                Spacer()

                Text(session.elapsedText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }

            // Current activity
            if let activity = latestActivity {
                HStack(spacing: 8) {
                    Image(systemName: activity.kind.iconSystemName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 14)

                    Text(activity.kind.displayText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            } else {
                Text("Starting...")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }

            // Indeterminate progress bar
            ShimmerProgressBar()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(
            width: IslandSize.midExpandedWidth,
            height: IslandSize.midExpandedHeight
        )
    }
}

/// Indeterminate shimmer progress bar
struct ShimmerProgressBar: View {
    @State private var offset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(.white.opacity(0.08))

                // Shimmer highlight
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.indigo.opacity(0.0), .indigo.opacity(0.6), .indigo.opacity(0.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width * 0.35)
                    .offset(x: offset * width)
            }
        }
        .frame(height: 4)
        .clipShape(Capsule())
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                offset = 1.0
            }
        }
    }
}
