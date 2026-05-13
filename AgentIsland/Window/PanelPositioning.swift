import AppKit

/// Utility for calculating panel positions across multiple displays
enum PanelPositioning {
    /// Get the top-center position for the island on the main screen
    static func topCenter(for size: CGSize, margin: CGFloat = 8) -> NSPoint {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        return topCenter(for: size, on: screen, margin: margin)
    }

    /// Get the top-center position on a specific screen
    static func topCenter(for size: CGSize, on screen: NSScreen, margin: CGFloat = 8) -> NSPoint {
        let menuBarHeight = screen.frame.height - screen.visibleFrame.height -
            (screen.visibleFrame.origin.y - screen.frame.origin.y)

        let x = screen.frame.origin.x + (screen.frame.width - size.width) / 2
        let y = screen.frame.maxY - size.height - margin - menuBarHeight

        return NSPoint(x: x, y: y)
    }

    /// Check if the current main screen has a notch (approximate heuristic)
    static var mainScreenHasNotch: Bool {
        guard let screen = NSScreen.main else { return false }
        // MacBook Pro with notch has a safe area inset at the top
        // The menu bar height is taller on notch displays (~38pt vs ~25pt)
        let menuBarHeight = screen.frame.height - screen.visibleFrame.height -
            (screen.visibleFrame.origin.y - screen.frame.origin.y)
        return menuBarHeight > 30
    }
}
