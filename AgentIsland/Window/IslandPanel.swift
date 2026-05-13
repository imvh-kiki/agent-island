import AppKit
import SwiftUI

/// A floating NSPanel that acts as the Dynamic Island container.
/// Does not steal focus, stays above other windows, has no titlebar.
final class IslandPanel: NSPanel {

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

        // Transparent background — SwiftUI handles the pill shape
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Don't steal focus
        isMovableByWindowBackground = false
        hidesOnDeactivate = false

        // Smooth animations
        animationBehavior = .utilityWindow
    }

    // Allow clicking through when in collapsed (non-interactive) state
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
