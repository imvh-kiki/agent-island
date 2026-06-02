import Foundation
import AppKit

enum ProcessUtils {
    /// Known terminal emulators, matched against process `comm` and app names.
    /// Shared by both the parent-process walk and the running-app fallback.
    static let terminalNames = [
        "Terminal", "iTerm2", "iTerm", "Ghostty", "Alacritty", "kitty", "WezTerm", "Warp",
        "Hyper", "Tabby", "Rio", "Prompt", "Wave", "Contour", "foot",
        "Terminus", "cool-retro-term", "Zed", "WindTerm", "MobaXterm"
    ]

    /// Check if a process with the given PID is running and attached to a terminal
    static func isProcessRunning(pid: Int) -> Bool {
        guard kill(Int32(pid), 0) == 0 else { return false }

        // Check if the process still has a TTY (terminal)
        // If the terminal tab was closed, TTY shows as "??" — treat as dead
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", "\(pid)", "-o", "tty="]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let tty = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // "??" or empty means no terminal attached
            return !tty.isEmpty && tty != "??"
        } catch {
            return true // If check fails, assume still running
        }
    }

    /// Get the parent PID of a process
    static func parentPID(of pid: Int) -> Int? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", "\(pid)", "-o", "ppid="]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let ppid = Int(output) {
                return ppid
            }
        } catch {
            return nil
        }
        return nil
    }

    /// Get the process name for a PID
    static func processName(for pid: Int) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", "\(pid)", "-o", "comm="]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Walk up the process tree to find a terminal emulator
    static func findTerminalAncestor(of pid: Int) -> (pid: Int, name: String)? {
        var currentPID = pid

        for _ in 0..<10 { // Max 10 levels up
            guard let ppid = parentPID(of: currentPID) else { break }
            if ppid <= 1 { break }

            if let name = processName(for: ppid),
               terminalNames.contains(where: { name.localizedCaseInsensitiveContains($0) }) {
                return (ppid, name)
            }
            currentPID = ppid
        }
        return nil
    }

    /// Fallback when the parent-process walk fails (dead pid, re-parented child,
    /// tmux/login intermediaries): find a terminal emulator that is actually
    /// running, preferring the one the user is currently focused on.
    /// Never assumes Apple Terminal — returns whatever real terminal is in use.
    static func runningTerminalApp() -> NSRunningApplication? {
        let candidates = NSWorkspace.shared.runningApplications.filter { app in
            guard app.activationPolicy == .regular, let name = app.localizedName else { return false }
            return terminalNames.contains { name.localizedCaseInsensitiveContains($0) }
        }
        // Prefer the frontmost terminal; otherwise any running one.
        return candidates.first(where: { $0.isActive }) ?? candidates.first
    }
}
