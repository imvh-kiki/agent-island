import Foundation
import Network

/// Lightweight HTTP server for Claude Code hooks.
/// Receives PermissionRequest and PreToolUse/PostToolUse events.
final class HookServer {
    let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "hook-server")

    /// Pending permission requests waiting for user decision.
    /// Key: tool_use_id, Value: (continuation, createdAt)
    private var pendingDecisions: [String: (CheckedContinuation<PermissionDecision, Never>, Date)] = [:]
    /// Pending question answers from /hooks/ask-question. Key: question_id
    private var pendingAnswers: [String: (CheckedContinuation<String, Never>, Date)] = [:]
    /// Pending plan review decisions. Key: plan_id
    private var pendingPlanDecisions: [String: (CheckedContinuation<Bool, Never>, Date)] = [:]
    /// Pending AskUserQuestion answers from PreToolUse interception. Key: tool_use_id
    /// Value is the user's answer string (nil = dismissed/cancelled)
    private var pendingPreToolUseAnswers: [String: (CheckedContinuation<String?, Never>, Date)] = [:]
    /// Tool-use IDs already approved via PreToolUse — auto-approve subsequent PermissionRequest
    private var preToolApprovedIds: [String: Date] = [:]
    private let lock = NSLock()

    /// Max age for pending continuations before auto-cleanup (5 minutes)
    private let continuationTimeout: TimeInterval = 300
    private var cleanupTimer: Timer?

    /// Max debug log file size (512 KB)
    private let maxLogSize: UInt64 = 512 * 1024
    /// Max request body size (1 MB) — prevents memory exhaustion
    private let maxRequestSize = 1_048_576

    /// Shared secret for request authentication
    private var authToken: String?
    /// Path to the token file (readable only by current user)
    private let tokenFilePath: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/agent-island-token")

    /// Called when a new permission request arrives
    var onPermissionRequest: ((PermissionRequest) -> Void)?

    /// Called when a question needs user input
    var onQuestion: ((UserQuestion) -> Void)?

    /// Called when a plan needs review
    var onPlanReview: ((PlanReview) -> Void)?

    /// Called on tool use events (for real-time UI updates)
    var onToolEvent: (([String: Any]) -> Void)?

    /// Called when a session's turn ends (Stop hook). Carries the session id so
    /// the monitor can reset status to idle — otherwise the Island stays stuck on
    /// the last tool (e.g. "running Read") after the agent has finished.
    var onStop: ((String) -> Void)?

    /// Called on test endpoint hits — lets AppDelegate show mock UI states
    var onTestAction: ((String) -> Void)?

    init(port: UInt16 = 31415) {
        self.port = port
    }

    // MARK: - Auth Token

    /// Generate a random token, write it to a file with 0600 permissions.
    /// The token is included in hook URLs so only requests from our configured hooks pass validation.
    private func generateToken() -> String {
        let token = UUID().uuidString
        let data = Data(token.utf8)
        FileManager.default.createFile(atPath: tokenFilePath.path, contents: data, attributes: [
            .posixPermissions: 0o600
        ])
        authToken = token
        return token
    }

    /// Validate that the request contains the correct auth token (via query param ?token=...)
    private func validateToken(path: String) -> Bool {
        guard let token = authToken else { return false }  // No token = reject (fail-closed)
        // Extract token from URL query: /hooks/pre-tool-use?token=xxx
        guard let queryStart = path.firstIndex(of: "?") else { return false }
        let query = String(path[path.index(after: queryStart)...])
        let params = query.components(separatedBy: "&")
        for param in params {
            let kv = param.components(separatedBy: "=")
            if kv.count == 2, kv[0] == "token", kv[1] == token {
                return true
            }
        }
        return false
    }

    /// Remove the token file on shutdown
    private func removeTokenFile() {
        try? FileManager.default.removeItem(at: tokenFilePath)
    }

    // MARK: - Lifecycle

    func start() throws {
        // Generate auth token before starting
        _ = generateToken()

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        // Bind to localhost only — never expose to the local network
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: 0)

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            print("[HookServer] Invalid port: \(port)")
            return
        }
        listener = try NWListener(using: params, on: nwPort)

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

        // Periodically clean up orphaned continuations
        DispatchQueue.main.async { [weak self] in
            self?.cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.cleanupOrphanedContinuations()
            }
        }
    }

    func stop() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        removeTokenFile()
        listener?.cancel()
        listener = nil

        // Cancel all pending decisions
        lock.lock()
        for (_, (continuation, _)) in pendingDecisions {
            continuation.resume(returning: .deny)
        }
        pendingDecisions.removeAll()
        for (_, (continuation, _)) in pendingAnswers {
            continuation.resume(returning: "")
        }
        pendingAnswers.removeAll()
        for (_, (continuation, _)) in pendingPlanDecisions {
            continuation.resume(returning: false)
        }
        pendingPlanDecisions.removeAll()
        for (_, (continuation, _)) in pendingPreToolUseAnswers {
            continuation.resume(returning: nil)
        }
        pendingPreToolUseAnswers.removeAll()
        preToolApprovedIds.removeAll()
        lock.unlock()
    }

    /// Called by the UI when user approves/denies a permission
    func resolvePermission(toolUseId: String, decision: PermissionDecision) {
        lock.lock()
        let entry = pendingDecisions.removeValue(forKey: toolUseId)
        lock.unlock()

        entry?.0.resume(returning: decision)
    }

    /// Called by the UI when user answers a question
    func resolveQuestion(questionId: String, answer: String) {
        lock.lock()
        let entry = pendingAnswers.removeValue(forKey: questionId)
        lock.unlock()

        entry?.0.resume(returning: answer)
    }

    /// Called by the UI when user approves/rejects a plan
    func resolvePlanReview(planId: String, approved: Bool) {
        lock.lock()
        let entry = pendingPlanDecisions.removeValue(forKey: planId)
        lock.unlock()

        entry?.0.resume(returning: approved)
    }

    /// Called by the UI when user answers an AskUserQuestion intercepted from PreToolUse.
    /// answer: the user's selection, or nil if dismissed.
    func resolvePreToolUseQuestion(requestId: String, answer: String?) {
        lock.lock()
        let entry = pendingPreToolUseAnswers.removeValue(forKey: requestId)
        lock.unlock()

        entry?.0.resume(returning: answer)
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveFullRequest(connection: connection, accumulated: Data())
    }

    /// Accumulate TCP data until we have a complete HTTP request (headers + body).
    private func receiveFullRequest(connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { connection.cancel(); return }

            var buffer = accumulated
            if let data { buffer.append(data) }

            if error != nil {
                connection.cancel()
                return
            }

            // M2: Reject oversized requests
            if buffer.count > self.maxRequestSize {
                self.sendResponse(connection: connection, statusCode: 413, body: #"{"error":"request too large"}"#)
                return
            }

            // Check if we have the full HTTP request
            if let fullString = String(data: buffer, encoding: .utf8),
               let headerEndRange = fullString.range(of: "\r\n\r\n") {

                // Parse Content-Length to know if we have the full body
                let headerPart = String(fullString[..<headerEndRange.lowerBound])
                let bodyStart = fullString[headerEndRange.upperBound...]
                let receivedBodyLength = bodyStart.utf8.count

                // Find Content-Length header
                var expectedLength = 0
                for line in headerPart.components(separatedBy: "\r\n") {
                    if line.lowercased().hasPrefix("content-length:") {
                        let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                        expectedLength = Int(value) ?? 0
                        break
                    }
                }

                if receivedBodyLength >= expectedLength || isComplete {
                    // We have the full request — process it
                    self.handleHTTPRequest(data: buffer, connection: connection)
                    return
                }
            }

            if isComplete {
                // Connection closed — process what we have
                if !buffer.isEmpty {
                    self.handleHTTPRequest(data: buffer, connection: connection)
                } else {
                    connection.cancel()
                }
                return
            }

            // Need more data — keep reading
            self.receiveFullRequest(connection: connection, accumulated: buffer)
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

        // Strip query params from path for routing (token is in query)
        let routePath = path.components(separatedBy: "?").first ?? path

        // Log to file for debugging (compact format)
        logToFile("[HookServer] \(method) \(routePath)")

        // H1: Validate auth token on hook endpoints
        if routePath.hasPrefix("/hooks/") && !validateToken(path: path) {
            sendResponse(connection: connection, statusCode: 403, body: #"{"error":"unauthorized"}"#)
            return
        }

        // Route — POST for hooks
        switch (method, routePath) {
        case ("POST", "/hooks/permission"):
            handlePermissionHook(body: body, connection: connection)

        case ("POST", "/hooks/ask-question"):
            handleQuestionHook(body: body, connection: connection)

        case ("POST", "/hooks/plan-review"):
            handlePlanReviewHook(body: body, connection: connection)

        case ("POST", "/hooks/pre-tool-use"):
            handlePreToolUse(body: body, connection: connection)

        case ("POST", "/hooks/post-tool-use"):
            onToolEvent?(body ?? [:])
            sendResponse(connection: connection, statusCode: 200, body: "{}")

        case ("POST", "/hooks/stop"):
            if let sessionId = body?["session_id"] as? String {
                DispatchQueue.main.async { [weak self] in self?.onStop?(sessionId) }
            }
            onToolEvent?(body ?? [:])
            sendResponse(connection: connection, statusCode: 200, body: "{}")

        #if DEBUG
        // Test endpoints — only in debug builds
        case (_, "/test/collapsed"):
            DispatchQueue.main.async { self.onTestAction?("collapsed") }
            sendResponse(connection: connection, statusCode: 200, body: #"{"status":"ok","action":"collapsed"}"#)

        case (_, "/test/expanded"):
            DispatchQueue.main.async { self.onTestAction?("expanded") }
            sendResponse(connection: connection, statusCode: 200, body: #"{"status":"ok","action":"expanded"}"#)

        case (_, "/test/permission"):
            DispatchQueue.main.async { self.onTestAction?("permission") }
            sendResponse(connection: connection, statusCode: 200, body: #"{"status":"ok","action":"permission"}"#)

        case (_, "/test/hide"):
            DispatchQueue.main.async { self.onTestAction?("hide") }
            sendResponse(connection: connection, statusCode: 200, body: #"{"status":"ok","action":"hide"}"#)

        case (_, "/test/multi"):
            DispatchQueue.main.async { self.onTestAction?("multi") }
            sendResponse(connection: connection, statusCode: 200, body: #"{"status":"ok","action":"multi"}"#)

        case (_, "/test/question"):
            DispatchQueue.main.async { self.onTestAction?("question") }
            sendResponse(connection: connection, statusCode: 200, body: #"{"status":"ok","action":"question"}"#)

        case (_, "/test/planreview"):
            DispatchQueue.main.async { self.onTestAction?("planreview") }
            sendResponse(connection: connection, statusCode: 200, body: #"{"status":"ok","action":"planreview"}"#)

        case (_, "/test/planreviewlong"):
            DispatchQueue.main.async { self.onTestAction?("planreviewlong") }
            sendResponse(connection: connection, statusCode: 200, body: #"{"status":"ok","action":"planreviewlong"}"#)

        case (_, "/test/midexpanded"):
            DispatchQueue.main.async { self.onTestAction?("midexpanded") }
            sendResponse(connection: connection, statusCode: 200, body: #"{"status":"ok","action":"midexpanded"}"#)
        #endif

        default:
            sendResponse(connection: connection, statusCode: 404, body: #"{"error":"not found"}"#)
        }
    }

    private func handlePreToolUse(body: [String: Any]?, connection: NWConnection) {
        guard let body else {
            sendResponse(connection: connection, statusCode: 200, body: "{}")
            return
        }

        let toolName = body["tool_name"] as? String ?? ""
        let sessionId = body["session_id"] as? String ?? "unknown"
        let requestId = body["tool_use_id"] as? String ?? UUID().uuidString

        // Fire event for UI updates
        onToolEvent?(body)

        // AskUserQuestion: show question on Dynamic Island, block until user answers
        if toolName == "AskUserQuestion",
           let input = body["tool_input"] as? [String: Any],
           var question = parseQuestionFromToolInput(input, sessionId: sessionId) {

            question.preToolUseRequestId = requestId
            logToFile("[PreToolUse] question intercepted: \(requestId)")

            DispatchQueue.main.async { [weak self] in
                self?.onQuestion?(question)
            }

            // Block until user answers on Dynamic Island
            Task {
                let answer = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
                    self.lock.lock()
                    // M5: Resume old continuation if requestId collides
                    if let old = self.pendingPreToolUseAnswers.removeValue(forKey: requestId) {
                        old.0.resume(returning: nil)
                    }
                    self.pendingPreToolUseAnswers[requestId] = (continuation, Date())
                    self.lock.unlock()
                }

                if let answer {
                    // User answered on the Island. PreToolUse hooks cannot inject a
                    // tool_result, so we deny the tool (to suppress the terminal UI) and
                    // pass the answer back via `permissionDecisionReason` — the field
                    // Claude Code surfaces to the model. (Older builds used `reason`,
                    // which newer Claude Code silently ignores, dropping the answer.)
                    self.logToFile("[PreToolUse] question answered via Dynamic Island: \(answer)")
                    let response: [String: Any] = [
                        "hookSpecificOutput": [
                            "hookEventName": "PreToolUse",
                            "permissionDecision": "deny",
                            "permissionDecisionReason": "The user already answered this AskUserQuestion via the Agent Island UI. Their answer: \"\(answer)\". Treat this as the user's response and continue — do not call AskUserQuestion again."
                        ]
                    ]
                    let body = self.jsonString(response) ?? "{}"
                    self.sendResponse(connection: connection, statusCode: 200, body: body)
                } else {
                    // Dismissed — allow the tool so it shows in terminal
                    let response: [String: Any] = [
                        "hookSpecificOutput": [
                            "hookEventName": "PreToolUse",
                            "permissionDecision": "allow"
                        ]
                    ]
                    let body = self.jsonString(response) ?? "{}"
                    self.sendResponse(connection: connection, statusCode: 200, body: body)
                }
            }
            return
        }

        // All other PreToolUse events require permission — show on Dynamic Island

        logToFile("[PreToolUse] permission prompt for \(toolName) id=\(requestId)")

        // Parse tool input
        var toolInput: [String: String] = [:]
        if let input = body["tool_input"] as? [String: Any] {
            for (key, value) in input {
                toolInput[key] = "\(value)"
            }
        }

        let request = PermissionRequest(
            id: requestId,
            sessionId: sessionId,
            toolName: toolName,
            toolInput: toolInput,
            timestamp: Date()
        )

        // Show permission UI
        DispatchQueue.main.async { [weak self] in
            self?.onPermissionRequest?(request)
        }

        // Block until user decides
        Task {
            let decision = await withCheckedContinuation { (continuation: CheckedContinuation<PermissionDecision, Never>) in
                self.lock.lock()
                // M5: Resume old continuation if requestId collides
                if let old = self.pendingDecisions.removeValue(forKey: requestId) {
                    old.0.resume(returning: .deny)
                }
                self.pendingDecisions[requestId] = (continuation, Date())
                self.lock.unlock()
            }

            let behavior = decision == .allow ? "allow" : "deny"
            self.logToFile("[PreToolUse] decision: \(behavior)")

            if decision == .allow {
                self.lock.lock()
                self.preToolApprovedIds[requestId] = Date()
                self.lock.unlock()
            }

            let response: [String: Any] = [
                "hookSpecificOutput": [
                    "hookEventName": "PreToolUse",
                    "permissionDecision": behavior
                ]
            ]
            let body = self.jsonString(response) ?? "{}"
            self.sendResponse(connection: connection, statusCode: 200, body: body)
        }
    }

    private func handlePermissionHook(body: [String: Any]?, connection: NWConnection) {
        let toolUseId = body?["tool_use_id"] as? String
        let toolName = body?["tool_name"] as? String ?? "unknown"
        let sessionId = body?["session_id"] as? String ?? "unknown"

        // If this tool was already approved via PreToolUse, auto-approve
        if let id = toolUseId {
            lock.lock()
            let wasApproved = preToolApprovedIds.removeValue(forKey: id) != nil
            lock.unlock()

            if wasApproved {
                logToFile("[PermissionRequest] auto-approved (already approved via PreToolUse) id=\(id)")
                let response = PermissionDecision.allow.hookResponse
                let body = jsonString(response) ?? "{}"
                sendResponse(connection: connection, statusCode: 200, body: body)
                return
            }
        }

        // Not previously approved — show Dynamic Island UI and block
        let requestId = toolUseId ?? UUID().uuidString

        logToFile("[PermissionRequest] permission prompt for \(toolName) id=\(requestId)")

        var toolInput: [String: String] = [:]
        if let input = body?["tool_input"] as? [String: Any] {
            for (key, value) in input {
                toolInput[key] = "\(value)"
            }
        }

        let request = PermissionRequest(
            id: requestId,
            sessionId: sessionId,
            toolName: toolName,
            toolInput: toolInput,
            timestamp: Date()
        )

        DispatchQueue.main.async { [weak self] in
            self?.onPermissionRequest?(request)
        }

        Task {
            let decision = await withCheckedContinuation { (continuation: CheckedContinuation<PermissionDecision, Never>) in
                self.lock.lock()
                if let old = self.pendingDecisions.removeValue(forKey: requestId) {
                    old.0.resume(returning: .deny)
                }
                self.pendingDecisions[requestId] = (continuation, Date())
                self.lock.unlock()
            }

            let behavior = decision == .allow ? "allow" : "deny"
            self.logToFile("[PermissionRequest] decision: \(behavior)")

            let response = (decision == .allow ? PermissionDecision.allow : PermissionDecision.deny).hookResponse
            let body = self.jsonString(response) ?? "{}"
            self.sendResponse(connection: connection, statusCode: 200, body: body)
        }
    }

    /// Extract question data from AskUserQuestion tool_input (supports 1-4 questions)
    private func parseQuestionFromToolInput(_ input: [String: Any], sessionId: String) -> UserQuestion? {
        guard let rawQuestions = input["questions"] as? [[String: Any]],
              !rawQuestions.isEmpty else {
            return nil
        }

        let questionId = UUID().uuidString
        var subQuestions: [SubQuestion] = []

        for (qi, raw) in rawQuestions.enumerated() {
            guard let questionText = raw["question"] as? String else { continue }

            let header = raw["header"] as? String
            let multiSelect = raw["multiSelect"] as? Bool ?? false

            var options: [QuestionOption] = []
            if let rawOptions = raw["options"] as? [[String: Any]] {
                for (oi, opt) in rawOptions.enumerated() {
                    let label = opt["label"] as? String ?? "Option \(oi + 1)"
                    let desc = opt["description"] as? String
                    options.append(QuestionOption(id: "\(questionId)-\(qi)-\(oi)", label: label, description: desc))
                }
            }

            subQuestions.append(SubQuestion(
                id: "\(questionId)-q\(qi)",
                question: questionText,
                header: header,
                options: options,
                multiSelect: multiSelect
            ))
        }

        guard !subQuestions.isEmpty else { return nil }

        return UserQuestion(
            id: questionId,
            sessionId: sessionId,
            questions: subQuestions,
            timestamp: Date()
        )
    }

    private lazy var logFilePath: String = {
        let logDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/AgentIsland")
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: [
            .posixPermissions: 0o700
        ])
        return logDir.appendingPathComponent("hooks.log").path
    }()

    private func logToFile(_ message: String) {
        let line = "\(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        // Truncate if too large
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logFilePath),
           let size = attrs[.size] as? UInt64, size > maxLogSize {
            try? FileManager.default.removeItem(atPath: logFilePath)
        }

        if FileManager.default.fileExists(atPath: logFilePath) {
            if let handle = FileHandle(forWritingAtPath: logFilePath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: logFilePath, contents: data, attributes: [
                .posixPermissions: 0o600
            ])
        }
    }

    /// Remove continuations that have been waiting too long (session likely died)
    private func cleanupOrphanedContinuations() {
        let now = Date()
        lock.lock()

        for (id, (continuation, created)) in pendingDecisions where now.timeIntervalSince(created) > continuationTimeout {
            continuation.resume(returning: .deny)
            pendingDecisions.removeValue(forKey: id)
        }
        for (id, (continuation, created)) in pendingAnswers where now.timeIntervalSince(created) > continuationTimeout {
            continuation.resume(returning: "")
            pendingAnswers.removeValue(forKey: id)
        }
        for (id, (continuation, created)) in pendingPlanDecisions where now.timeIntervalSince(created) > continuationTimeout {
            continuation.resume(returning: false)
            pendingPlanDecisions.removeValue(forKey: id)
        }
        for (id, (continuation, created)) in pendingPreToolUseAnswers where now.timeIntervalSince(created) > continuationTimeout {
            continuation.resume(returning: nil)
            pendingPreToolUseAnswers.removeValue(forKey: id)
        }
        preToolApprovedIds = preToolApprovedIds.filter { now.timeIntervalSince($0.value) <= continuationTimeout }

        lock.unlock()
    }

    private func handleQuestionHook(body: [String: Any]?, connection: NWConnection) {
        guard let body,
              let questionText = body["question"] as? String else {
            sendResponse(connection: connection, statusCode: 200, body: "{}")
            return
        }

        let questionId = body["question_id"] as? String ?? UUID().uuidString
        let sessionId = body["session_id"] as? String ?? "unknown"

        // Parse options
        var options: [QuestionOption] = []
        if let rawOptions = body["options"] as? [[String: Any]] {
            for (i, opt) in rawOptions.enumerated() {
                let label = opt["label"] as? String ?? "Option \(i + 1)"
                let desc = opt["description"] as? String
                options.append(QuestionOption(id: "\(questionId)-\(i)", label: label, description: desc))
            }
        }

        let subQuestion = SubQuestion(
            id: "\(questionId)-q0",
            question: questionText,
            header: nil,
            options: options,
            multiSelect: false
        )

        let question = UserQuestion(
            id: questionId,
            sessionId: sessionId,
            questions: [subQuestion],
            timestamp: Date()
        )

        DispatchQueue.main.async { [weak self] in
            self?.onQuestion?(question)
        }

        Task {
            let answer = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
                self.lock.lock()
                self.pendingAnswers[questionId] = (continuation, Date())
                self.lock.unlock()
            }

            let responseBody: [String: Any] = ["answer": answer]
            if let jsonData = try? JSONSerialization.data(withJSONObject: responseBody),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                self.sendResponse(connection: connection, statusCode: 200, body: jsonString)
            } else {
                self.sendResponse(connection: connection, statusCode: 200, body: "{}")
            }
        }
    }

    private func handlePlanReviewHook(body: [String: Any]?, connection: NWConnection) {
        guard let body,
              let planContent = body["plan_content"] as? String else {
            sendResponse(connection: connection, statusCode: 200, body: "{}")
            return
        }

        let planId = body["plan_id"] as? String ?? UUID().uuidString
        let sessionId = body["session_id"] as? String ?? "unknown"
        let title = body["title"] as? String ?? "Plan Review"

        let plan = PlanReview(
            id: planId,
            sessionId: sessionId,
            title: title,
            content: planContent,
            timestamp: Date()
        )

        DispatchQueue.main.async { [weak self] in
            self?.onPlanReview?(plan)
        }

        Task {
            let approved = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                self.lock.lock()
                self.pendingPlanDecisions[planId] = (continuation, Date())
                self.lock.unlock()
            }

            let responseBody: [String: Any] = ["approved": approved]
            if let jsonData = try? JSONSerialization.data(withJSONObject: responseBody),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                self.sendResponse(connection: connection, statusCode: 200, body: jsonString)
            } else {
                self.sendResponse(connection: connection, statusCode: 200, body: "{}")
            }
        }
    }

    /// Safely serialize a dictionary to a JSON string
    private func jsonString(_ dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
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

    /// Unique marker to identify Agent Island hooks (for safe add/remove)
    private static let hookMarker = "agent-island"

    /// Write hook configuration to Claude Code settings.
    /// Appends to existing hooks instead of overwriting them.
    /// Token is embedded in URLs for authentication.
    static func configureHooks() {
        let settingsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
        let tokenPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/agent-island-token")

        // Read token
        let token = (try? String(contentsOf: tokenPath, encoding: .utf8)) ?? ""
        let tokenQuery = token.isEmpty ? "" : "?token=\(token)"

        var settings: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = existing
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        // matcher per event — PreToolUse only intercepts AskUserQuestion so other
        // tools (incl. read-only ones) don't round-trip through the Island.
        let hookDefs: [(String, String, String, Int)] = [
            ("PermissionRequest", ".*", "http://127.0.0.1:31415/hooks/permission\(tokenQuery)", 120),
            ("PreToolUse", "AskUserQuestion", "http://127.0.0.1:31415/hooks/pre-tool-use\(tokenQuery)", 120),
            ("PostToolUse", ".*", "http://127.0.0.1:31415/hooks/post-tool-use\(tokenQuery)", 5),
            ("Stop", ".*", "http://127.0.0.1:31415/hooks/stop\(tokenQuery)", 5),
        ]

        for (eventName, matcher, url, timeout) in hookDefs {
            let newHook: [String: Any] = [
                "type": "http",
                "url": url,
                "timeout": timeout
            ]
            let newEntry: [String: Any] = [
                "matcher": matcher,
                "hooks": [newHook]
            ]

            var entries = hooks[eventName] as? [[String: Any]] ?? []
            // Remove any existing Agent Island hooks (by URL prefix) before adding
            entries.removeAll { entry in
                guard let entryHooks = entry["hooks"] as? [[String: Any]] else { return false }
                return entryHooks.contains { hook in
                    let hookUrl = hook["url"] as? String ?? ""
                    return hookUrl.contains("127.0.0.1:31415")
                }
            }
            entries.append(newEntry)
            hooks[eventName] = entries
        }

        settings["hooks"] = hooks

        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: settingsPath)
            // Restrict permissions — file contains auth token in hook URLs
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: settingsPath.path)
            print("[HookServer] Hooks configured at \(settingsPath.path)")
        }
    }

    /// Remove Agent Island hooks from Claude Code settings
    static func removeHooks() {
        let settingsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")

        guard let data = try? Data(contentsOf: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = settings["hooks"] as? [String: Any] else { return }

        for eventName in ["PermissionRequest", "PreToolUse", "PostToolUse", "Stop"] {
            guard var entries = hooks[eventName] as? [[String: Any]] else { continue }
            entries.removeAll { entry in
                guard let entryHooks = entry["hooks"] as? [[String: Any]] else { return false }
                return entryHooks.contains { ($0["url"] as? String ?? "").contains("127.0.0.1:31415") }
            }
            hooks[eventName] = entries.isEmpty ? nil : entries
        }

        settings["hooks"] = hooks
        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: settingsPath)
            print("[HookServer] Hooks removed from \(settingsPath.path)")
        }
    }
}
