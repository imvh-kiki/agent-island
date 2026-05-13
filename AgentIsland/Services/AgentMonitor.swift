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

    /// Start monitoring
    func startMonitoring() async throws

    /// Stop monitoring
    func stopMonitoring()

    /// Approve a permission request
    func approvePermission(_ request: PermissionRequest) async throws

    /// Deny a permission request
    func denyPermission(_ request: PermissionRequest) async throws

    /// Jump to the terminal running this session
    func jumpToTerminal(session: AgentSession) throws
}
