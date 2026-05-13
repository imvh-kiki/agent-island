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
                .transition(.opacity)

        case .expanded(let session):
            ExpandedIslandView(
                session: session,
                activities: viewModel.activities,
                onCollapse: { viewModel.collapse() },
                onJumpToTerminal: { viewModel.jumpToTerminal() }
            )
            .transition(.opacity)

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
            .transition(.opacity)

        case .multiSession:
            // Future: multi-session carousel
            EmptyView()
        }
    }

    private var currentAnimation: Animation {
        switch viewModel.state {
        case .permissionPrompt:
            return IslandSpring.alert
        default:
            return IslandSpring.expand
        }
    }
}
