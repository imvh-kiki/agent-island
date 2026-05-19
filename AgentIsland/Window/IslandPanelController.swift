import AppKit
import SwiftUI
import Combine

/// Manages the Island panel's position, size, and visibility.
/// Uses a fixed-size transparent panel — SwiftUI handles all visual sizing/animation.
/// Clicks on transparent areas pass through automatically (isOpaque = false).
final class IslandPanelController: ObservableObject {
    private(set) var panel: IslandPanel?
    private var cancellables = Set<AnyCancellable>()
    /// Tracks the current hide animation — used to cancel stale completions
    private var hideAnimationId: UUID?

    /// Distance from top of screen (below menu bar)
    private let topMargin: CGFloat = 8

    /// Fixed panel size — large enough for all states. SwiftUI handles the pill.
    private let panelWidth: CGFloat = 400
    private let panelHeight: CGFloat = 400

    func setupPanel<Content: View>(with content: Content) {
        let initialRect = fixedFrame()

        let panel = IslandPanel(contentRect: initialRect)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: initialRect.size)

        // Fully transparent layer — clipping handled in SwiftUI
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        hostingView.layer?.isOpaque = false

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
        guard let panel else { return }
        hideAnimationId = nil          // Cancel any pending hide completion
        panel.alphaValue = 1           // In case called mid-hide-animation
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// Reset to default top-center position
    func resetPosition() {
        panel?.hasCustomPosition = false
        if let panel, panel.isVisible {
            panel.setFrame(fixedFrame(), display: true)
        }
    }

    func updateForState(_ state: IslandState) {
        guard let panel else { return }

        if state == .hidden {
            let animId = UUID()
            hideAnimationId = animId
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                // Only act if this animation hasn't been superseded by show()
                guard let self, self.hideAnimationId == animId else { return }
                self.hideAnimationId = nil
                self.panel?.orderOut(nil)
                self.panel?.alphaValue = 1
            }
            return
        }

        if !panel.isVisible {
            // Position the fixed-size panel, then fade in
            if !panel.hasCustomPosition {
                panel.setFrame(fixedFrame(), display: true)
            }
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
            return
        }

        // Panel frame never changes during state transitions —
        // SwiftUI handles all sizing and animation within the fixed panel.
    }

    private func repositionPanel() {
        guard let panel, panel.isVisible, !panel.hasCustomPosition else { return }
        panel.setFrame(fixedFrame(), display: true)
    }

    /// Fixed frame: centered horizontally, top-aligned below menu bar
    private func fixedFrame() -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let menuBarHeight = screen.frame.height - screen.visibleFrame.height -
            (screen.visibleFrame.origin.y - screen.frame.origin.y)
        let x = (screen.frame.width - panelWidth) / 2 + screen.frame.origin.x
        let y = screen.frame.maxY - panelHeight - topMargin - menuBarHeight
        return NSRect(x: x, y: y, width: panelWidth, height: panelHeight)
    }

    private var dummySession: AgentSession {
        AgentSession(id: "init", agentType: .claudeCode, pid: 0, cwd: "", startedAt: Date())
    }
}
