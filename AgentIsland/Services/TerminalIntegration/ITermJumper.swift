import AppKit

/// Activates iTerm2 via AppleScript
enum ITermJumper: TerminalJumperProtocol {
    static func activate() {
        let script = """
        tell application "iTerm2"
            activate
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}
