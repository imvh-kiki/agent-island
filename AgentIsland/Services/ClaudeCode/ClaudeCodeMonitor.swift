import Foundation
import AppKit
import Combine

/// Concrete AgentMonitor for Claude Code.
/// Combines session discovery, log watching, and hook server.
final class ClaudeCodeMonitor: AgentMonitor {
    let agentType: AgentType = .claudeCode

    private let sessionDiscovery = SessionDiscovery()
    private let logWatcher = LogWatcher()
    private let hookServer = HookServer()

    private let _sessions = CurrentValueSubject<[AgentSession], Never>([])
    private let _activities = PassthroughSubject<AgentActivity, Never>()
    private let _permissionRequests = PassthroughSubject<PermissionRequest, Never>()
    private let _questions = PassthroughSubject<UserQuestion, Never>()
    private let _planReviews = PassthroughSubject<PlanReview, Never>()

    private var cancellables = Set<AnyCancellable>()
    private var pollingTimer: Timer?
    private var watchedSessionIds = Set<String>()

    /// Called when a test endpoint is hit on the hook server
    var onTestAction: ((String) -> Void)?

    var sessionsPublisher: AnyPublisher<[AgentSession], Never> {
        _sessions.eraseToAnyPublisher()
    }

    var activitiesPublisher: AnyPublisher<AgentActivity, Never> {
        _activities.eraseToAnyPublisher()
    }

    var permissionRequestsPublisher: AnyPublisher<PermissionRequest, Never> {
        _permissionRequests.eraseToAnyPublisher()
    }

    var questionsPublisher: AnyPublisher<UserQuestion, Never> {
        _questions.eraseToAnyPublisher()
    }

    var planReviewsPublisher: AnyPublisher<PlanReview, Never> {
        _planReviews.eraseToAnyPublisher()
    }

    // MARK: - Lifecycle

    func startMonitoring() async throws {
        // 1. Start the hook server
        try hookServer.start()

        hookServer.onPermissionRequest = { [weak self] request in
            self?._permissionRequests.send(request)

            // Update session status
            var sessions = self?._sessions.value ?? []
            if let idx = sessions.firstIndex(where: { $0.id == request.sessionId }) {
                sessions[idx].status = .waitingForPermission
                self?._sessions.send(sessions)
            }
        }

        hookServer.onToolEvent = { [weak self] event in
            // Use tool events for faster UI updates
            if let toolName = event["tool_name"] as? String,
               let sessionId = event["session_id"] as? String {
                var sessions = self?._sessions.value ?? []
                if let idx = sessions.firstIndex(where: { $0.id == sessionId }) {
                    sessions[idx].status = .executingTool(toolName: toolName)
                    self?._sessions.send(sessions)
                }
            }
        }

        hookServer.onQuestion = { [weak self] question in
            self?._questions.send(question)
        }

        hookServer.onPlanReview = { [weak self] plan in
            self?._planReviews.send(plan)
        }

        hookServer.onTestAction = { [weak self] action in
            self?.onTestAction?(action)
        }

        // 2. Forward log watcher events (dispatch to main to avoid data race with refreshSessions)
        logWatcher.activities
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activity in
                self?._activities.send(activity)
            }
            .store(in: &cancellables)

        logWatcher.statusUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                var sessions = self?._sessions.value ?? []
                if let idx = sessions.firstIndex(where: { $0.id == update.sessionId }) {
                    sessions[idx].status = update.status
                    self?._sessions.send(sessions)
                }
            }
            .store(in: &cancellables)

        // 3. Configure hooks on first launch
        HookServer.configureHooks()

        // 4. Start polling for sessions
        refreshSessions()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshSessions()
        }
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        logWatcher.stopAll()
        hookServer.stop()
    }

    func approvePermission(_ request: PermissionRequest) async throws {
        hookServer.resolvePermission(toolUseId: request.id, decision: .allow)
        clearWaitingStatus(sessionId: request.sessionId, from: .waitingForPermission)
    }

    func denyPermission(_ request: PermissionRequest) async throws {
        hookServer.resolvePermission(toolUseId: request.id, decision: .deny)
        clearWaitingStatus(sessionId: request.sessionId, from: .waitingForPermission)
    }

    func answerQuestion(_ question: UserQuestion, answer: String) async throws {
        hookServer.resolveQuestion(questionId: question.id, answer: answer)
        clearWaitingStatus(sessionId: question.sessionId, from: .waitingForInput)
    }

    func resolvePreToolUseQuestion(requestId: String, answer: String?) async throws {
        hookServer.resolvePreToolUseQuestion(requestId: requestId, answer: answer)
    }

    func resolvePlan(_ plan: PlanReview, approved: Bool) async throws {
        hookServer.resolvePlanReview(planId: plan.id, approved: approved)
    }

    /// Clear stale waiting status from the internal sessions subject
    /// so that `refreshSessions()` doesn't re-propagate it.
    private func clearWaitingStatus(sessionId: String, from expected: SessionStatus) {
        var sessions = _sessions.value
        if let idx = sessions.firstIndex(where: { $0.id == sessionId }),
           sessions[idx].status == expected {
            sessions[idx].status = .idle
            _sessions.send(sessions)
        }
    }

    func jumpToTerminal(session: AgentSession) throws {
        // Try tmux first — it can jump to the exact pane
        TmuxJumper.jumpToPane(containingPID: session.pid)

        guard let terminal = ProcessUtils.findTerminalAncestor(of: session.pid) else {
            // Fallback: activate Terminal.app
            if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                NSWorkspace.shared.openApplication(at: terminalURL, configuration: .init())
            }
            return
        }

        // Activate the detected terminal app by its process ID
        if let app = NSRunningApplication(processIdentifier: pid_t(terminal.pid)) {
            app.unhide()
            app.activate(options: .activateIgnoringOtherApps)
        } else {
            // Fallback: activate by bundle URL
            let ws = NSWorkspace.shared
            for runningApp in ws.runningApplications where runningApp.localizedName?.localizedCaseInsensitiveContains(terminal.name.components(separatedBy: "/").last ?? "") == true {
                runningApp.activate(options: .activateIgnoringOtherApps)
                return
            }
        }
    }

    // MARK: - Private

    private func refreshSessions() {
        let discovered = sessionDiscovery.discoverSessions()
        let currentIds = Set(discovered.map(\.id))

        // Start watching new sessions
        for session in discovered where !watchedSessionIds.contains(session.id) {
            if let logPath = sessionDiscovery.logPath(for: session) {
                logWatcher.watchSession(id: session.id, logPath: logPath)
                watchedSessionIds.insert(session.id)
            }
        }

        // Stop watching ended sessions and clean up their resources
        for sessionId in watchedSessionIds where !currentIds.contains(sessionId) {
            logWatcher.unwatchSession(id: sessionId)
            UsageTracker.shared.resetSession(sessionId)
            watchedSessionIds.remove(sessionId)
        }

        // Merge with existing status info — only keep statuses that represent
        // a concrete, ongoing state (tool execution, waiting for user).
        // Transient states like .thinking fall back to discovery's .idle so
        // that auto-collapse can fire when the agent is truly idle.
        var updated = discovered
        let existing = _sessions.value
        for i in updated.indices {
            if let match = existing.first(where: { $0.id == updated[i].id }) {
                switch match.status {
                case .executingTool, .waitingForPermission, .waitingForInput:
                    updated[i].status = match.status
                default:
                    break // keep discovery's .idle
                }
                updated[i].currentTask = match.currentTask
            }
        }

        _sessions.send(updated)
    }
}
