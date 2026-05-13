import SwiftUI
import Combine

@MainActor
final class IslandViewModel: ObservableObject {
    @Published var state: IslandState = .hidden
    @Published var activities: [AgentActivity] = []
    @Published var sessions: [AgentSession] = []
    @Published var pendingPermissions: [PermissionRequest] = []

    private var monitors: [any AgentMonitor] = []
    private var cancellables = Set<AnyCancellable>()
    private var autoCollapseTask: Task<Void, Never>?

    weak var panelController: IslandPanelController?

    // MARK: - Monitor Management

    func addMonitor(_ monitor: any AgentMonitor) {
        monitors.append(monitor)

        monitor.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.handleSessionsUpdate(sessions)
            }
            .store(in: &cancellables)

        monitor.activitiesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activity in
                self?.handleActivity(activity)
            }
            .store(in: &cancellables)

        monitor.permissionRequestsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] request in
                self?.handlePermissionRequest(request)
            }
            .store(in: &cancellables)
    }

    func startMonitoring() async {
        for monitor in monitors {
            try? await monitor.startMonitoring()
        }
    }

    func stopMonitoring() {
        for monitor in monitors {
            monitor.stopMonitoring()
        }
    }

    // MARK: - State Transitions

    func transitionTo(_ newState: IslandState) {
        let oldState = state
        let animation = IslandTransition.transition(from: oldState, to: newState)

        withAnimation(animation) {
            state = newState
        }

        panelController?.updateForState(newState)
    }

    func toggleExpanded() {
        switch state {
        case .collapsed(let session):
            transitionTo(.expanded(session))
            cancelAutoCollapse()
        case .expanded(let session):
            transitionTo(.collapsed(session))
            scheduleAutoCollapse()
        default:
            break
        }
    }

    func collapse() {
        switch state {
        case .expanded(let session), .permissionPrompt(let session, _):
            transitionTo(.collapsed(session))
            scheduleAutoCollapse()
        default:
            break
        }
    }

    // MARK: - Permission Handling

    func approvePermission(_ request: PermissionRequest) async {
        guard let monitor = monitors.first(where: { $0.agentType == .claudeCode }) else { return }
        try? await monitor.approvePermission(request)

        pendingPermissions.removeAll { $0.id == request.id }

        if let session = currentSession {
            transitionTo(.collapsed(session))
        }
    }

    func denyPermission(_ request: PermissionRequest) async {
        guard let monitor = monitors.first(where: { $0.agentType == .claudeCode }) else { return }
        try? await monitor.denyPermission(request)

        pendingPermissions.removeAll { $0.id == request.id }

        if let session = currentSession {
            transitionTo(.collapsed(session))
        }
    }

    // MARK: - Terminal

    func jumpToTerminal() {
        guard let session = currentSession,
              let monitor = monitors.first(where: { $0.agentType == session.agentType }) else { return }
        try? monitor.jumpToTerminal(session: session)
    }

    // MARK: - Private

    private var currentSession: AgentSession? {
        switch state {
        case .collapsed(let s), .expanded(let s), .permissionPrompt(let s, _):
            return s
        default:
            return sessions.first
        }
    }

    private func handleSessionsUpdate(_ newSessions: [AgentSession]) {
        sessions = newSessions

        switch state {
        case .hidden:
            if let session = newSessions.first {
                transitionTo(.collapsed(session))
                scheduleAutoCollapse()
            }
        case .collapsed, .expanded:
            if newSessions.isEmpty {
                transitionTo(.hidden)
            } else if let session = newSessions.first {
                // Update session data in current state
                switch state {
                case .collapsed:
                    withAnimation(IslandSpring.micro) {
                        state = .collapsed(session)
                    }
                case .expanded:
                    withAnimation(IslandSpring.micro) {
                        state = .expanded(session)
                    }
                default:
                    break
                }
            }
        default:
            break
        }
    }

    private func handleActivity(_ activity: AgentActivity) {
        activities.append(activity)
        // Keep last 50 activities
        if activities.count > 50 {
            activities.removeFirst(activities.count - 50)
        }
    }

    private func handlePermissionRequest(_ request: PermissionRequest) {
        pendingPermissions.append(request)

        if let session = currentSession {
            transitionTo(.permissionPrompt(session, request))
        }
    }

    private func scheduleAutoCollapse() {
        cancelAutoCollapse()
        // No auto-collapse for now — user controls collapse via click
    }

    private func cancelAutoCollapse() {
        autoCollapseTask?.cancel()
        autoCollapseTask = nil
    }
}
