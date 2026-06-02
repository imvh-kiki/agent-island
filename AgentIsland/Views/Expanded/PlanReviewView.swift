import SwiftUI

struct PlanReviewView: View {
    let session: AgentSession
    let plan: PlanReview
    let onApprove: () -> Void
    let onReject: () -> Void
    @State private var rejectHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 10) {
                // Contextual icon with tinted background
                Text("📄")
                    .font(.system(size: 15))
                    .frame(width: 30, height: 30)
                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(session.agentType.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()
            }

            // Markdown content
            ScrollView(.vertical, showsIndicators: true) {
                markdownContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            // Action buttons
            HStack(spacing: 10) {
                Button(action: onReject) {
                    Text("Reject")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(rejectHovered ? .white.opacity(0.9) : .white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(rejectHovered ? .white.opacity(0.14) : .white.opacity(0.1), in: Capsule())
                        .animation(.easeOut(duration: 0.15), value: rejectHovered)
                }
                .buttonStyle(IslandButtonStyle())
                .onHover { rejectHovered = $0 }

                Button(action: onApprove) {
                    Text("Approve")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.indigo, in: Capsule())
                }
                .buttonStyle(IslandPrimaryButtonStyle())
            }
        }
        .padding(18)
        .frame(
            width: IslandSize.planReviewWidth,
            height: IslandSize.planReviewHeight(for: plan)
        )
    }

    @ViewBuilder
    private var markdownContent: some View {
        if let attributed = try? AttributedString(markdown: plan.content,
                                                   options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.85))
                .textSelection(.enabled)
        } else {
            Text(plan.content)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.85))
                .textSelection(.enabled)
        }
    }
}
