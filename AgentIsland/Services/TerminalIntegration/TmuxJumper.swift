import Foundation

/// Jump to a specific tmux pane by finding which pane owns a process
enum TmuxJumper {
    /// Try to jump to the tmux pane running a given PID
    static func jumpToPane(containingPID pid: Int) -> Bool {
        // Check if tmux is available
        guard isTmuxRunning() else { return false }

        // Find which tmux pane owns this PID
        guard let paneId = findPaneForPID(pid) else { return false }

        // Select the pane
        return selectPane(paneId)
    }

    private static func isTmuxRunning() -> Bool {
        let result = shell("which", "tmux")
        return !result.isEmpty
    }

    private static func findPaneForPID(_ pid: Int) -> String? {
        // List all panes with their PIDs
        let output = shell("tmux", "list-panes", "-a", "-F", "#{pane_id}:#{pane_pid}")
        guard !output.isEmpty else { return nil }

        // Walk up process tree to find a tmux pane
        var currentPID = pid
        for _ in 0..<10 {
            for line in output.components(separatedBy: "\n") {
                let parts = line.split(separator: ":")
                guard parts.count == 2,
                      let panePID = Int(parts[1]) else { continue }

                if panePID == currentPID {
                    return String(parts[0])
                }
            }

            guard let ppid = ProcessUtils.parentPID(of: currentPID), ppid > 1 else { break }
            currentPID = ppid
        }

        return nil
    }

    private static func selectPane(_ paneId: String) -> Bool {
        // Extract session and window from pane, then select
        let _ = shell("tmux", "select-pane", "-t", paneId)
        // Also select the window containing this pane
        let windowInfo = shell("tmux", "display-message", "-t", paneId, "-p", "#{window_id}")
        if !windowInfo.isEmpty {
            let _ = shell("tmux", "select-window", "-t", windowInfo.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return true
    }

    private static func shell(_ args: String...) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }
}
