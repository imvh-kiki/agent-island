import AppKit
import SwiftUI

/// A floating NSPanel that acts as the Dynamic Island container.
/// Does not steal focus, stays above other windows, has no titlebar.
/// Supports drag-to-reposition by the user.
final class IslandPanel: NSPanel {

    /// Whether the user has manually dragged the panel to a custom position
    var hasCustomPosition = false

    /// Track mouse-down for dragging
    private var dragOrigin: NSPoint = .zero

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Floating above all windows
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Fully transparent — SwiftUI handles the pill shape, no system shadow
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Enable dragging by background
        isMovableByWindowBackground = true
        hidesOnDeactivate = false

        // Smooth animations
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        dragOrigin = frame.origin
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        // If the panel moved, mark as custom position
        if frame.origin != dragOrigin {
            hasCustomPosition = true
        }
    }
}
