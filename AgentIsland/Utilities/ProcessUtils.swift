import Foundation

enum ProcessUtils {
    /// Check if a process with the given PID is running
    static func isProcessRunning(pid: Int) -> Bool {
        kill(Int32(pid), 0) == 0
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
        let terminalNames = ["Terminal", "iTerm2", "Ghostty", "Alacritty", "kitty", "WezTerm", "Warp"]
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
}
