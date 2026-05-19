import SwiftUI

struct PlanReviewView: View {
    let session: AgentSession
    let plan: PlanReview
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 10) {
                AgentIconView(agentType: session.agentType, size: 16)

                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.indigo)

                    Text(session.agentType.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundStyle(.indigo.opacity(0.6))
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
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.1), in: Capsule())
                }
                .buttonStyle(IslandButtonStyle())

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
            height: IslandSize.planReviewHeight
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
