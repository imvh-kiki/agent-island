import SwiftUI

struct IslandContainerView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        ZStack {
            // Background pill
            IslandBackground(cornerRadius: viewModel.state.cornerRadius)

            // Content based on state
            content
        }
        .frame(
            width: viewModel.state.panelSize.width,
            height: viewModel.state.panelSize.height
        )
        .clipShape(RoundedRectangle(cornerRadius: viewModel.state.cornerRadius, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(currentAnimation, value: viewModel.state)
        .onTapGesture {
            viewModel.toggleExpanded()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .hidden:
            EmptyView()

        case .collapsed(let session):
            CollapsedIslandView(session: session)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))

        case .expanded(let session):
            ExpandedIslandView(
                session: session,
                activities: viewModel.activitiesForCurrentSession,
                onCollapse: { viewModel.collapse() },
                onJumpToTerminal: { viewModel.jumpToTerminal() },
                onDismiss: { viewModel.dismissSession(session) },
                showBackButton: viewModel.cameFromMultiSession
            )
            .transition(.opacity.combined(with: .scale(scale: 0.97)))

        case .permissionPrompt(let session, let request):
            PermissionRequestView(
                session: session,
                request: request,
                onApprove: {
                    Task { await viewModel.approvePermission(request) }
                },
                onDeny: {
                    Task { await viewModel.denyPermission(request) }
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))

        case .askQuestion(let session, let question):
            AskQuestionView(
                session: session,
                question: question,
                onAnswer: { answer in
                    Task { await viewModel.answerQuestion(question, answer: answer) }
                },
                onCancel: {
                    Task { await viewModel.cancelQuestion(question) }
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))

        case .planReview(let session, let plan):
            PlanReviewView(
                session: session,
                plan: plan,
                onApprove: {
                    Task { await viewModel.approvePlan(plan) }
                },
                onReject: {
                    Task { await viewModel.rejectPlan(plan) }
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))

        case .multiSession(let sessions):
            CollapsedMultiView(sessions: sessions)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))

        case .expandedMulti(let sessions):
            SessionListView(
                sessions: sessions,
                onSelectSession: { session in
                    viewModel.selectSession(session)
                },
                onDismissSession: { session in
                    viewModel.dismissSession(session)
                },
                onCollapse: { viewModel.collapse() }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }

    private var currentAnimation: Animation {
        switch viewModel.state {
        case .permissionPrompt, .askQuestion, .planReview:
            return IslandSpring.alert
        default:
            return IslandSpring.expand
        }
    }
}
