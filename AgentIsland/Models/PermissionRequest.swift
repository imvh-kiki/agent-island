import Foundation

struct PermissionRequest: Identifiable, Equatable {
    let id: String               // tool_use_id
    let sessionId: String
    let toolName: String
    let toolInput: [String: String]
    let timestamp: Date
    var status: PermissionStatus = .pending

    static func == (lhs: PermissionRequest, rhs: PermissionRequest) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status
    }

    var displayDescription: String {
        switch toolName {
        case "Bash":
            return toolInput["command"] ?? toolInput["description"] ?? "Run command"
        case "Edit":
            return "Edit \(shortenPath(toolInput["file_path"] ?? "file"))"
        case "Write":
            return "Write \(shortenPath(toolInput["file_path"] ?? "file"))"
        case "Read":
            return "Read \(shortenPath(toolInput["file_path"] ?? "file"))"
        default:
            return toolInput["description"] ?? "Use \(toolName)"
        }
    }

    private func shortenPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count <= 2 { return path }
        return "../\(components.suffix(2).joined(separator: "/"))"
    }
}

enum PermissionStatus: Equatable {
    case pending
    case approved
    case denied
    case expired
}

enum PermissionDecision {
    case allow
    case deny

    var hookResponse: [String: Any] {
        [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": ["behavior": self == .allow ? "allow" : "deny"]
            ]
        ]
    }
}
