import SwiftUI
import Combine

@MainActor
final class IslandViewModel: ObservableObject {
    @Published var state: IslandState = .hidden
    @Published var activities: [AgentActivity] = []
    @Published var sessions: [AgentSession] = []
    @Published var pendingPermissions: [PermissionRequest] = []
    var pendingQuestions: [UserQuestion] = []
    var pendingPlans: [PlanReview] = []

    /// Activities grouped by session
    private var activitiesBySession: [String: [AgentActivity]] = [:]

    /// Activities for the currently viewed session
    var activitiesForCurrentSession: [AgentActivity] {
        guard let session = currentSession else { return activities }
        return activitiesBySession[session.id] ?? []
    }

    private var monitors: [any AgentMonitor] = []
    private var cancellables = Set<AnyCancellable>()
    private var autoCollapseTask: Task<Void, Never>?
    /// Track if we drilled in from multi-session view
    private(set) var cameFromMultiSession = false
    /// Sessions manually dismissed by the user (hidden until process actually ends)
    private var dismissedSessionIds = Set<String>()

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

        monitor.questionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] question in
                self?.handleQuestion(question)
            }
            .store(in: &cancellables)

        monitor.planReviewsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] plan in
                self?.handlePlanReview(plan)
            }
            .store(in: &cancellables)
    }

    func startMonitoring() async {
        for monitor in monitors {
            do {
                try await monitor.startMonitoring()
            } catch {
                print("[IslandViewModel] Failed to start \(monitor.agentType.displayName) monitor: \(error)")
            }
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

        // Play sound effects on key transitions
        playSoundForTransition(from: oldState, to: newState)

        withAnimation(animation) {
            state = newState
        }

        panelController?.updateForState(newState)
    }

    private func playSoundForTransition(from oldState: IslandState, to newState: IslandState) {
        switch newState {
        case .permissionPrompt:
            SoundManager.shared.playPermission()
        case .askQuestion:
            SoundManager.shared.playQuestion()
        default:
            break
        }

        // Session appeared
        if case .hidden = oldState {
            switch newState {
            case .collapsed, .multiSession:
                SoundManager.shared.playSessionStart()
            default:
                break
            }
        }
    }

    /// Called from menu bar "Show Island" — force-show with current sessions
    func forceShow() {
        cancelAutoCollapse()

        if state != .hidden {
            // Already visible — just ensure panel is in front
            panelController?.show()
            return
        }

        if sessions.count >= 2 {
            transitionTo(.multiSession(sessions))
        } else if let session = sessions.first {
            transitionTo(.collapsed(session))
        } else {
            // No sessions — show panel briefly so user knows app is alive
            panelController?.show()
            // Auto-hide after 3 seconds since there's nothing to show
            autoCollapseTask = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                panelController?.hide()
            }
            return
        }

        // Keep visible for 10 seconds before auto-collapse (if all idle)
        scheduleAutoCollapse(delay: 10)
    }

    func toggleExpanded() {
        switch state {
        case .collapsed(let session):
            cameFromMultiSession = false
            transitionTo(.expanded(session))
            cancelAutoCollapse()
        case .expanded:
            collapse()
            return
        case .multiSession(let sessions):
            transitionTo(.expandedMulti(sessions))
            cancelAutoCollapse()
        case .expandedMulti(let sessions):
            transitionTo(.multiSession(sessions))
            scheduleAutoCollapse()
        default:
            break
        }
    }

    func collapse() {
        switch state {
        case .expanded:
            if cameFromMultiSession && sessions.count >= 2 {
                // Go back to session list instead of collapsing
                cameFromMultiSession = false
                transitionTo(.expandedMulti(sessions))
            } else {
                cameFromMultiSession = false
                collapseToAppropriateState()
            }
        case .permissionPrompt, .askQuestion, .planReview:
            collapseToAppropriateState()
        case .expandedMulti(let sessions):
            transitionTo(.multiSession(sessions))
            scheduleAutoCollapse()
        default:
            break
        }
    }

    /// Dismiss a session from the island (hides it, doesn't kill the process)
    func dismissSession(_ session: AgentSession) {
        dismissedSessionIds.insert(session.id)
        let remaining = sessions.filter { !dismissedSessionIds.contains($0.id) }
        sessions = remaining

        if remaining.isEmpty {
            transitionTo(.hidden)
        } else if remaining.count == 1 {
            transitionTo(.collapsed(remaining[0]))
        } else {
            switch state {
            case .expandedMulti:
                transitionTo(.expandedMulti(remaining))
            default:
                transitionTo(.multiSession(remaining))
            }
        }
    }

    /// Select a single session from multi-session list to view details
    func selectSession(_ session: AgentSession) {
        cameFromMultiSession = true
        transitionTo(.expanded(session))
    }

    /// Collapse back to the right state based on current session count
    private func collapseToAppropriateState() {
        if sessions.count >= 2 {
            transitionTo(.multiSession(sessions))
        } else if let session = sessions.first {
            transitionTo(.collapsed(session))
        } else {
            transitionTo(.hidden)
        }
        scheduleAutoCollapse()
    }

    // MARK: - Permission Handling

    func approvePermission(_ request: PermissionRequest) async {
        guard let monitor = monitors.first(where: { $0.agentType == .claudeCode }) else { return }
        do {
            try await monitor.approvePermission(request)
            SoundManager.shared.playSuccess()
        } catch {
            print("[IslandViewModel] approvePermission failed: \(error)")
            SoundManager.shared.playError()
        }

        pendingPermissions.removeAll { $0.id == request.id }
        clearSessionWaitingStatus(sessionId: request.sessionId)
        showNextPendingOrCollapse()
    }

    func denyPermission(_ request: PermissionRequest) async {
        guard let monitor = monitors.first(where: { $0.agentType == .claudeCode }) else { return }
        do {
            try await monitor.denyPermission(request)
        } catch {
            print("[IslandViewModel] denyPermission failed: \(error)")
            SoundManager.shared.playError()
        }

        pendingPermissions.removeAll { $0.id == request.id }
        clearSessionWaitingStatus(sessionId: request.sessionId)
        showNextPendingOrCollapse()
    }

    /// After resolving any interactive prompt, show the next pending one or collapse.
    /// Priority: permissions > questions > plans
    private func showNextPendingOrCollapse() {
        if let next = pendingPermissions.first {
            let session = sessionForId(next.sessionId, fallbackStatus: .waitingForPermission)
            transitionTo(.permissionPrompt(session, next))
        } else if let next = pendingQuestions.first {
            pendingQuestions.removeFirst()
            let session = sessionForId(next.sessionId, fallbackStatus: .waitingForInput)
            transitionTo(.askQuestion(session, next))
        } else if let next = pendingPlans.first {
            pendingPlans.removeFirst()
            if let session = currentSession ?? sessions.first {
                transitionTo(.planReview(session, next))
            }
        } else if let session = currentSession {
            transitionTo(.collapsed(session))
            scheduleAutoCollapse()
        }
    }

    // MARK: - Terminal

    func jumpToTerminal() {
        guard let session = currentSession,
              let monitor = monitors.first(where: { $0.agentType == session.agentType }) else { return }
        try? monitor.jumpToTerminal(session: session)
    }

    // MARK: - Private

    /// Reset a session's status after resolving an interactive prompt.
    /// Without this, `refreshSessions()` keeps copying the stale waiting status.
    private func clearSessionWaitingStatus(sessionId: String) {
        if let idx = sessions.firstIndex(where: { $0.id == sessionId }),
           sessions[idx].status == .waitingForPermission || sessions[idx].status == .waitingForInput {
            sessions[idx].status = .idle
        }
    }

    func answerQuestion(_ question: UserQuestion, answer: String) async {
        guard let monitor = monitors.first(where: { $0.agentType == .claudeCode }) else { return }

        do {
            if let requestId = question.preToolUseRequestId {
                try await monitor.resolvePreToolUseQuestion(requestId: requestId, answer: answer)
            } else {
                try await monitor.answerQuestion(question, answer: answer)
            }
            SoundManager.shared.playSuccess()
        } catch {
            print("[IslandViewModel] answerQuestion failed: \(error)")
            SoundManager.shared.playError()
        }

        pendingQuestions.removeAll { $0.id == question.id }
        clearSessionWaitingStatus(sessionId: question.sessionId)
        showNextPendingOrCollapse()
    }

    func cancelQuestion(_ question: UserQuestion) async {
        guard let monitor = monitors.first(where: { $0.agentType == .claudeCode }) else { return }

        do {
            if let requestId = question.preToolUseRequestId {
                try await monitor.resolvePreToolUseQuestion(requestId: requestId, answer: nil)
            } else {
                try await monitor.answerQuestion(question, answer: "")
            }
        } catch {
            print("[IslandViewModel] cancelQuestion failed: \(error)")
        }

        pendingQuestions.removeAll { $0.id == question.id }
        clearSessionWaitingStatus(sessionId: question.sessionId)
        showNextPendingOrCollapse()
    }

    func approvePlan(_ plan: PlanReview) async {
        guard let monitor = monitors.first(where: { $0.agentType == .claudeCode }) else { return }
        do {
            try await monitor.resolvePlan(plan, approved: true)
            SoundManager.shared.playSuccess()
        } catch {
            print("[IslandViewModel] approvePlan failed: \(error)")
            SoundManager.shared.playError()
        }

        pendingPlans.removeAll { $0.id == plan.id }
        showNextPendingOrCollapse()
    }

    func rejectPlan(_ plan: PlanReview) async {
        guard let monitor = monitors.first(where: { $0.agentType == .claudeCode }) else { return }
        do {
            try await monitor.resolvePlan(plan, approved: false)
        } catch {
            print("[IslandViewModel] rejectPlan failed: \(error)")
            SoundManager.shared.playError()
        }

        pendingPlans.removeAll { $0.id == plan.id }
        showNextPendingOrCollapse()
    }

    private var currentSession: AgentSession? {
        switch state {
        case .collapsed(let s), .expanded(let s), .permissionPrompt(let s, _),
             .askQuestion(let s, _), .planReview(let s, _):
            return s
        case .multiSession(let ss), .expandedMulti(let ss):
            return ss.first
        case .hidden:
            return sessions.first
        }
    }

    private func handleSessionsUpdate(_ newSessions: [AgentSession]) {
        // Remove dismissed sessions that are no longer discovered (process ended) — allow re-show
        let currentIds = Set(newSessions.map(\.id))
        dismissedSessionIds = dismissedSessionIds.filter { currentIds.contains($0) }

        let filtered = newSessions.filter { !dismissedSessionIds.contains($0.id) }
        sessions = filtered
        let newSessions = filtered
        let hasActive = newSessions.contains { $0.status.isActive }

        switch state {
        case .hidden:
            if hasActive {
                cancelAutoCollapse()
                if newSessions.count >= 2 {
                    transitionTo(.multiSession(newSessions))
                } else if let session = newSessions.first {
                    transitionTo(.collapsed(session))
                }
            }

        case .collapsed, .expanded:
            if newSessions.isEmpty {
                transitionTo(.hidden)
            } else if newSessions.count >= 2 {
                transitionTo(.multiSession(newSessions))
                if !hasActive { scheduleAutoCollapse() }
            } else if let session = newSessions.first {
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
                if hasActive {
                    cancelAutoCollapse()
                } else {
                    scheduleAutoCollapse()
                }
            }

        case .multiSession, .expandedMulti:
            if newSessions.isEmpty {
                transitionTo(.hidden)
            } else if newSessions.count == 1 {
                transitionTo(.collapsed(newSessions[0]))
                if !hasActive { scheduleAutoCollapse() }
            } else {
                switch state {
                case .multiSession:
                    withAnimation(IslandSpring.micro) {
                        state = .multiSession(newSessions)
                    }
                    panelController?.updateForState(.multiSession(newSessions))
                case .expandedMulti:
                    withAnimation(IslandSpring.micro) {
                        state = .expandedMulti(newSessions)
                    }
                    panelController?.updateForState(.expandedMulti(newSessions))
                default:
                    break
                }
                if hasActive {
                    cancelAutoCollapse()
                } else {
                    scheduleAutoCollapse()
                }
            }

        case .permissionPrompt(let s, _), .askQuestion(let s, _), .planReview(let s, _):
            // Clean pending queues of dead sessions
            let activeIds = Set(newSessions.map(\.id))
            pendingPermissions.removeAll { !activeIds.contains($0.sessionId) }
            pendingQuestions.removeAll { !activeIds.contains($0.sessionId) }
            pendingPlans.removeAll { !activeIds.contains($0.sessionId) }

            // If the session for the current prompt is gone, expire it
            if !activeIds.contains(s.id) {
                showNextPendingOrCollapse()
            }
        }
    }

    private func handleActivity(_ activity: AgentActivity) {
        // Store in global list
        activities.append(activity)
        if activities.count > 50 {
            activities.removeFirst(activities.count - 50)
        }

        // Store per-session
        var sessionActivities = activitiesBySession[activity.sessionId] ?? []
        sessionActivities.append(activity)
        if sessionActivities.count > 50 {
            sessionActivities.removeFirst(sessionActivities.count - 50)
        }
        activitiesBySession[activity.sessionId] = sessionActivities

        // Auto-show island when activity arrives while hidden
        if case .hidden = state {
            if sessions.count >= 2 {
                transitionTo(.multiSession(sessions))
            } else if let session = sessions.first {
                transitionTo(.collapsed(session))
            }
        }
    }

    private func handlePermissionRequest(_ request: PermissionRequest) {
        pendingPermissions.append(request)
        cancelAutoCollapse()

        // Save current interactive state back to its queue before switching
        saveCurrentInteractiveState()

        let session = sessionForId(request.sessionId, fallbackStatus: .waitingForPermission)
        transitionTo(.permissionPrompt(session, request))
    }

    private func handleQuestion(_ question: UserQuestion) {
        cancelAutoCollapse()
        saveCurrentInteractiveState()

        let session = sessionForId(question.sessionId, fallbackStatus: .waitingForInput)
        transitionTo(.askQuestion(session, question))
    }

    private func handlePlanReview(_ plan: PlanReview) {
        cancelAutoCollapse()
        saveCurrentInteractiveState()

        if let session = currentSession ?? sessions.first {
            transitionTo(.planReview(session, plan))
        }
    }

    /// If the island is currently showing an interactive prompt, save it back
    /// to its pending queue so it isn't lost when a new prompt takes over.
    private func saveCurrentInteractiveState() {
        switch state {
        case .askQuestion(_, let question):
            if !pendingQuestions.contains(where: { $0.id == question.id }) {
                pendingQuestions.append(question)
            }
        case .planReview(_, let plan):
            if !pendingPlans.contains(where: { $0.id == plan.id }) {
                pendingPlans.append(plan)
            }
        case .permissionPrompt(_, let request):
            // Already in pendingPermissions (added on arrival)
            if !pendingPermissions.contains(where: { $0.id == request.id }) {
                pendingPermissions.append(request)
            }
        default:
            break
        }
    }

    /// Find the session for a given ID, or create a fallback
    private func sessionForId(_ sessionId: String, fallbackStatus: SessionStatus) -> AgentSession {
        sessions.first(where: { $0.id == sessionId })
            ?? currentSession
            ?? AgentSession(
                id: sessionId,
                agentType: .claudeCode,
                pid: 0,
                cwd: NSHomeDirectory(),
                startedAt: Date(),
                status: fallbackStatus
            )
    }

    private var allSessionsIdle: Bool {
        sessions.allSatisfy { !$0.status.isActive }
    }

    private func scheduleAutoCollapse(delay: Int = 3) {
        guard allSessionsIdle else {
            cancelAutoCollapse()
            return
        }
        // Don't restart if already pending — prevents polling from resetting the timer
        guard autoCollapseTask == nil else { return }

        autoCollapseTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, allSessionsIdle else { return }
            transitionTo(.hidden)
        }
    }

    private func cancelAutoCollapse() {
        autoCollapseTask?.cancel()
        autoCollapseTask = nil
    }
}
