import AppKit

/// Activates Terminal.app via AppleScript
enum TerminalAppJumper: TerminalJumperProtocol {
    static func activate() {
        let script = """
        tell application "Terminal"
            activate
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}
