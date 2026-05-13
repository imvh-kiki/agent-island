import Foundation
import Network

/// Lightweight HTTP server for Claude Code hooks.
/// Receives PermissionRequest and PreToolUse/PostToolUse events.
final class HookServer {
    let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "hook-server")

    /// Pending permission requests waiting for user decision.
    /// Key: tool_use_id, Value: continuation to resume with the decision
    private var pendingDecisions: [String: CheckedContinuation<PermissionDecision, Never>] = [:]
    private let lock = NSLock()

    /// Called when a new permission request arrives
    var onPermissionRequest: ((PermissionRequest) -> Void)?

    /// Called on tool use events (for real-time UI updates)
    var onToolEvent: (([String: Any]) -> Void)?

    init(port: UInt16 = 31415) {
        self.port = port
    }

    // MARK: - Lifecycle

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[HookServer] Listening on port \(self.port)")
            case .failed(let error):
                print("[HookServer] Failed: \(error)")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil

        // Cancel all pending decisions
        lock.lock()
        for (_, continuation) in pendingDecisions {
            continuation.resume(returning: .deny)
        }
        pendingDecisions.removeAll()
        lock.unlock()
    }

    /// Called by the UI when user approves/denies a permission
    func resolvePermission(toolUseId: String, decision: PermissionDecision) {
        lock.lock()
        let continuation = pendingDecisions.removeValue(forKey: toolUseId)
        lock.unlock()

        continuation?.resume(returning: decision)
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else {
                connection.cancel()
                return
            }

            self.handleHTTPRequest(data: data, connection: connection)
        }
    }

    private func handleHTTPRequest(data: Data, connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad request")
            return
        }

        // Parse HTTP request — extract path and body
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad request")
            return
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad request")
            return
        }

        let method = String(parts[0])
        let path = String(parts[1])

        // Extract body (after empty line)
        var body: [String: Any]?
        if let emptyLineIndex = lines.firstIndex(of: "") {
            let bodyString = lines[(emptyLineIndex + 1)...].joined(separator: "\r\n")
            if let bodyData = bodyString.data(using: .utf8) {
                body = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            }
        }

        // Route
        guard method == "POST" else {
            sendResponse(connection: connection, statusCode: 405, body: "Method not allowed")
            return
        }

        switch path {
        case "/hooks/permission":
            handlePermissionHook(body: body, connection: connection)

        case "/hooks/pre-tool-use":
            onToolEvent?(body ?? [:])
            sendResponse(connection: connection, statusCode: 200, body: "{}")

        case "/hooks/post-tool-use":
            onToolEvent?(body ?? [:])
            sendResponse(connection: connection, statusCode: 200, body: "{}")

        case "/hooks/stop":
            onToolEvent?(body ?? [:])
            sendResponse(connection: connection, statusCode: 200, body: "{}")

        default:
            sendResponse(connection: connection, statusCode: 404, body: "Not found")
        }
    }

    private func handlePermissionHook(body: [String: Any]?, connection: NWConnection) {
        guard let body,
              let toolName = body["tool_name"] as? String,
              let toolUseId = body["tool_use_id"] as? String else {
            sendResponse(connection: connection, statusCode: 200, body: "{}")
            return
        }

        let sessionId = body["session_id"] as? String ?? "unknown"

        // Parse tool input
        var toolInput: [String: String] = [:]
        if let input = body["tool_input"] as? [String: Any] {
            for (key, value) in input {
                toolInput[key] = "\(value)"
            }
        }

        let request = PermissionRequest(
            id: toolUseId,
            sessionId: sessionId,
            toolName: toolName,
            toolInput: toolInput,
            timestamp: Date()
        )

        // Notify UI
        DispatchQueue.main.async { [weak self] in
            self?.onPermissionRequest?(request)
        }

        // Block this connection until user decides
        Task {
            let decision = await withCheckedContinuation { (continuation: CheckedContinuation<PermissionDecision, Never>) in
                self.lock.lock()
                self.pendingDecisions[toolUseId] = continuation
                self.lock.unlock()
            }

            // Build response
            let responseBody: [String: Any] = [
                "hookSpecificOutput": [
                    "hookEventName": "PermissionRequest",
                    "decision": ["behavior": decision == .allow ? "allow" : "deny"]
                ]
            ]

            if let jsonData = try? JSONSerialization.data(withJSONObject: responseBody),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                self.sendResponse(connection: connection, statusCode: 200, body: jsonString)
            } else {
                self.sendResponse(connection: connection, statusCode: 200, body: "{}")
            }
        }
    }

    private func sendResponse(connection: NWConnection, statusCode: Int, body: String) {
        let statusText: String
        switch statusCode {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 405: statusText = "Method Not Allowed"
        default: statusText = "Unknown"
        }

        let response = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Hook Configuration

    /// Write hook configuration to Claude Code settings
    static func configureHooks() {
        let settingsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.local.json")

        var settings: [String: Any] = [:]

        // Read existing settings if they exist
        if let data = try? Data(contentsOf: settingsPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = existing
        }

        let hookConfig: [String: Any] = [
            "type": "http",
            "url": "http://127.0.0.1:31415/hooks/permission",
            "timeout": 120
        ]

        let preToolHook: [String: Any] = [
            "type": "http",
            "url": "http://127.0.0.1:31415/hooks/pre-tool-use",
            "timeout": 5
        ]

        let postToolHook: [String: Any] = [
            "type": "http",
            "url": "http://127.0.0.1:31415/hooks/post-tool-use",
            "timeout": 5
        ]

        let stopHook: [String: Any] = [
            "type": "http",
            "url": "http://127.0.0.1:31415/hooks/stop",
            "timeout": 5
        ]

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        hooks["PermissionRequest"] = [
            ["matcher": ".*", "hooks": [hookConfig]]
        ]
        hooks["PreToolUse"] = [
            ["matcher": ".*", "hooks": [preToolHook]]
        ]
        hooks["PostToolUse"] = [
            ["matcher": ".*", "hooks": [postToolHook]]
        ]
        hooks["Stop"] = [
            ["matcher": ".*", "hooks": [stopHook]]
        ]

        settings["hooks"] = hooks

        if let data = try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted) {
            try? data.write(to: settingsPath)
            print("[HookServer] Hooks configured at \(settingsPath.path)")
        }
    }
}
