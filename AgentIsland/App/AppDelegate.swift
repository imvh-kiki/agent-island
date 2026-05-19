import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let panelController = IslandPanelController()
    private let viewModel = IslandViewModel()
    private var statusObservation: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance guard: if another AgentIsland is already running, quit
        let myPID = ProcessInfo.processInfo.processIdentifier
        let others = NSWorkspace.shared.runningApplications.filter {
            $0.localizedName == "AgentIsland" && $0.processIdentifier != myPID
        }
        if !others.isEmpty {
            NSApp.terminate(nil)
            return
        }

        // Auto-enable Launch at Login on first run
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            try? SMAppService.mainApp.register()
        }

        setupMenuBar()
        setupPanel()

        let monitor = ClaudeCodeMonitor()
        #if DEBUG
        monitor.onTestAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case "collapsed":  self.testCollapsed()
            case "expanded":   self.testExpanded()
            case "permission": self.testPermission()
            case "multi":      self.testMultiSession()
            case "hide":       self.hideIsland()
            default: break
            }
        }
        #endif
        viewModel.addMonitor(monitor)
        viewModel.panelController = panelController

        // Update menu bar icon when sessions change
        statusObservation = viewModel.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.updateMenuBarIcon(sessions: sessions)
            }

        Task {
            await viewModel.startMonitoring()
        }
    }

    private func updateMenuBarIcon(sessions: [AgentSession]) {
        guard let button = statusItem?.button else { return }
        let hasActive = sessions.contains { $0.status.isActive }

        // Swap icon to indicate activity — no text badge
        let iconName = hasActive ? "sparkles" : "sparkle"
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Agent Island")
        button.image?.size = NSSize(width: 16, height: 16)
        button.title = ""
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopMonitoring()
    }

    // MARK: - Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Agent Island")
            button.image?.size = NSSize(width: 16, height: 16)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Island", action: #selector(showIsland), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Hide Island", action: #selector(hideIsland), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Reset Position", action: #selector(resetPosition), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())

        #if DEBUG
        // Debug / Test submenu
        let testMenu = NSMenu()
        testMenu.addItem(NSMenuItem(title: "Show Collapsed (Mock)", action: #selector(testCollapsed), keyEquivalent: ""))
        testMenu.addItem(NSMenuItem(title: "Show Expanded (Mock)", action: #selector(testExpanded), keyEquivalent: ""))
        testMenu.addItem(NSMenuItem(title: "Show Permission Prompt (Mock)", action: #selector(testPermission), keyEquivalent: ""))
        testMenu.addItem(NSMenuItem(title: "Show Multi-Session (Mock)", action: #selector(testMultiSession), keyEquivalent: ""))
        testMenu.addItem(NSMenuItem.separator())
        testMenu.addItem(NSMenuItem(title: "Send curl Permission Test", action: #selector(testPermissionCurl), keyEquivalent: ""))

        let testItem = NSMenuItem(title: "Test", action: nil, keyEquivalent: "")
        testItem.submenu = testMenu
        menu.addItem(testItem)

        menu.addItem(NSMenuItem.separator())
        #endif
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Agent Island", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupPanel() {
        let containerView = IslandContainerView(viewModel: viewModel)
        panelController.setupPanel(with: containerView)
    }

    // MARK: - Actions

    @objc private func showIsland() {
        viewModel.forceShow()
    }

    @objc private func hideIsland() {
        panelController.hide()
    }

    @objc private func resetPosition() {
        panelController.resetPosition()
    }

    @objc private func openSettings() {
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "Agent Island Settings"
        settingsWindow.contentView = NSHostingView(rootView: SettingsView())
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Test / Debug Actions

    #if DEBUG
    private var mockSession: AgentSession {
        AgentSession(
            id: "test-session-001",
            agentType: .claudeCode,
            pid: Int(ProcessInfo.processInfo.processIdentifier),
            cwd: NSHomeDirectory(),
            startedAt: Date(),
            status: .executingTool(toolName: "Bash"),
            currentTask: "Building Agent Island..."
        )
    }

    @objc private func testCollapsed() {
        panelController.show()
        viewModel.transitionTo(.collapsed(mockSession))
    }

    @objc private func testExpanded() {
        panelController.show()

        // Add some mock activities
        let mockActivities: [AgentActivity] = [
            AgentActivity(id: UUID(), timestamp: Date().addingTimeInterval(-30), sessionId: "test-session-001",
                          kind: .fileRead(path: NSHomeDirectory() + "/project/Package.swift")),
            AgentActivity(id: UUID(), timestamp: Date().addingTimeInterval(-20), sessionId: "test-session-001",
                          kind: .bashCommand(command: "swift build", description: "Build the project")),
            AgentActivity(id: UUID(), timestamp: Date().addingTimeInterval(-10), sessionId: "test-session-001",
                          kind: .fileWrite(path: NSHomeDirectory() + "/project/AppDelegate.swift")),
            AgentActivity(id: UUID(), timestamp: Date().addingTimeInterval(-5), sessionId: "test-session-001",
                          kind: .thinking),
            AgentActivity(id: UUID(), timestamp: Date(), sessionId: "test-session-001",
                          kind: .toolUse(name: "Edit", description: "Updating IslandPanel.swift")),
        ]
        viewModel.activities = mockActivities
        viewModel.transitionTo(.expanded(mockSession))
    }

    @objc private func testMultiSession() {
        panelController.show()

        let sessions = [
            AgentSession(
                id: "session-001",
                agentType: .claudeCode,
                pid: Int(ProcessInfo.processInfo.processIdentifier),
                cwd: NSHomeDirectory() + "/myProject/agent-island",
                startedAt: Date().addingTimeInterval(-120),
                status: .executingTool(toolName: "Bash"),
                currentTask: "Building Agent Island..."
            ),
            AgentSession(
                id: "session-002",
                agentType: .claudeCode,
                pid: Int(ProcessInfo.processInfo.processIdentifier),
                cwd: NSHomeDirectory() + "/myProject/web-app",
                startedAt: Date().addingTimeInterval(-60),
                status: .thinking,
                currentTask: "Refactoring auth module"
            ),
            AgentSession(
                id: "session-003",
                agentType: .claudeCode,
                pid: Int(ProcessInfo.processInfo.processIdentifier),
                cwd: NSHomeDirectory() + "/myProject/api-server",
                startedAt: Date().addingTimeInterval(-30),
                status: .executingTool(toolName: "Edit"),
                currentTask: "Updating API endpoints"
            ),
        ]
        viewModel.transitionTo(.multiSession(sessions))
    }

    @objc private func testPermission() {
        panelController.show()

        let mockRequest = PermissionRequest(
            id: "test-perm-\(UUID().uuidString.prefix(8))",
            sessionId: "test-session-001",
            toolName: "Bash",
            toolInput: [
                "command": "rm -rf node_modules && npm install",
                "description": "Clean install dependencies"
            ],
            timestamp: Date()
        )

        viewModel.transitionTo(.permissionPrompt(mockSession, mockRequest))
    }

    /// Send a real HTTP request to the hook server to test the full flow
    @objc private func testPermissionCurl() {
        panelController.show()

        // First show collapsed state so the island is visible
        viewModel.transitionTo(.collapsed(mockSession))

        // Then send a real HTTP request to the hook server after a short delay
        Task {
            try? await Task.sleep(for: .seconds(1))

            let url = URL(string: "http://127.0.0.1:31415/hooks/permission")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "session_id": "test-session-001",
                "hook_event_name": "PermissionRequest",
                "tool_name": "Bash",
                "tool_input": [
                    "command": "rm -rf node_modules && npm install",
                    "description": "Clean install dependencies"
                ],
                "tool_use_id": "toolu_test_\(UUID().uuidString.prefix(8))"
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            // Fire and don't wait — the hook server will hold the connection
            // until user taps Allow/Deny in the island UI
            Task.detached {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    let bodyStr = String(data: data, encoding: .utf8) ?? ""
                    print("[Test] Hook server responded: \(httpResponse.statusCode) — \(bodyStr)")
                }
            }
        }
    }
    #endif
}
