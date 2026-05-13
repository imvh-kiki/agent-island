import AppKit
import SwiftUI
import Combine

/// Manages the Island panel's position, size, and visibility.
final class IslandPanelController: ObservableObject {
    private(set) var panel: IslandPanel?
    private var cancellables = Set<AnyCancellable>()

    /// Distance from top of screen (below menu bar)
    private let topMargin: CGFloat = 8

    func setupPanel<Content: View>(with content: Content) {
        let initialRect = frameForState(.collapsed(dummySession))

        let panel = IslandPanel(contentRect: initialRect)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: initialRect.size)
        panel.contentView = hostingView

        self.panel = panel

        // Start hidden
        panel.orderOut(nil)

        // Track screen changes
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.repositionPanel() }
            .store(in: &cancellables)
    }

    func show() {
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func updateForState(_ state: IslandState) {
        guard let panel else { return }

        let targetFrame = frameForState(state)

        if state == .hidden {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                self?.panel?.orderOut(nil)
                self?.panel?.alphaValue = 1
            }
            return
        }

        if !panel.isVisible {
            panel.setFrame(targetFrame, display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
            return
        }

        // Animate frame change
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func repositionPanel() {
        // Re-center on current screen after display changes
        guard let panel, panel.isVisible else { return }
        // Keep current state size, just re-center
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let currentSize = panel.frame.size
        let x = (screen.frame.width - currentSize.width) / 2 + screen.frame.origin.x
        let y = screen.frame.maxY - currentSize.height - topMargin - (screen.frame.height - screen.visibleFrame.height - (screen.visibleFrame.origin.y - screen.frame.origin.y))
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func frameForState(_ state: IslandState) -> NSRect {
        let size = state.panelSize
        let screen = NSScreen.main ?? NSScreen.screens.first!

        // Menu bar height
        let menuBarHeight = screen.frame.height - screen.visibleFrame.height -
            (screen.visibleFrame.origin.y - screen.frame.origin.y)

        let x = (screen.frame.width - size.width) / 2 + screen.frame.origin.x
        let y = screen.frame.maxY - size.height - topMargin - menuBarHeight

        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// Dummy session for initial frame calculation
    private var dummySession: AgentSession {
        AgentSession(
            id: "init",
            agentType: .claudeCode,
            pid: 0,
            cwd: "",
            startedAt: Date()
        )
    }
}
