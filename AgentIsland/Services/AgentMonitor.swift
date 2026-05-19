import Foundation
import Combine

/// Protocol for monitoring any AI coding agent.
/// Implement this for each agent type (Claude Code, Cursor, etc.)
protocol AgentMonitor: AnyObject {
    var agentType: AgentType { get }

    /// Publisher for active sessions
    var sessionsPublisher: AnyPublisher<[AgentSession], Never> { get }

    /// Publisher for individual activity events
    var activitiesPublisher: AnyPublisher<AgentActivity, Never> { get }

    /// Publisher for permission requests
    var permissionRequestsPublisher: AnyPublisher<PermissionRequest, Never> { get }

    /// Publisher for user questions
    var questionsPublisher: AnyPublisher<UserQuestion, Never> { get }

    /// Publisher for plan reviews
    var planReviewsPublisher: AnyPublisher<PlanReview, Never> { get }

    /// Start monitoring
    func startMonitoring() async throws

    /// Stop monitoring
    func stopMonitoring()

    /// Approve a permission request
    func approvePermission(_ request: PermissionRequest) async throws

    /// Deny a permission request
    func denyPermission(_ request: PermissionRequest) async throws

    /// Answer a user question
    func answerQuestion(_ question: UserQuestion, answer: String) async throws

    /// Answer an AskUserQuestion intercepted from PreToolUse
    func resolvePreToolUseQuestion(requestId: String, answer: String?) async throws

    /// Approve or reject a plan
    func resolvePlan(_ plan: PlanReview, approved: Bool) async throws

    /// Jump to the terminal running this session
    func jumpToTerminal(session: AgentSession) throws
}
