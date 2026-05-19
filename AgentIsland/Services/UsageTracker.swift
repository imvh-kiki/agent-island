import Foundation
import Combine

/// Tracks token usage from JSONL log entries.
/// Thread-safe: sessionStats protected by lock, @Published updated on main.
final class UsageTracker: ObservableObject {
    static let shared = UsageTracker()

    @Published var stats = UsageStats()
    private var sessionStats: [String: UsageStats] = [:]
    private let lock = NSLock()

    private init() {}

    /// Process a log line and extract usage data
    func processLogLine(_ json: [String: Any], sessionId: String) {
        let usage: [String: Any]?
        if let msg = json["message"] as? [String: Any],
           let u = msg["usage"] as? [String: Any] {
            usage = u
        } else if let u = json["usage"] as? [String: Any] {
            usage = u
        } else {
            return
        }
        guard let usage else { return }

        let input = usage["input_tokens"] as? Int ?? 0
        let output = usage["output_tokens"] as? Int ?? 0

        lock.lock()
        var current = sessionStats[sessionId] ?? UsageStats(sessionId: sessionId)
        current.inputTokens += input
        current.outputTokens += output
        current.requestCount += 1

        let inputCost = Double(input) * 3.0 / 1_000_000
        let outputCost = Double(output) * 15.0 / 1_000_000
        current.totalCost += inputCost + outputCost

        sessionStats[sessionId] = current

        var total = UsageStats()
        for (_, s) in sessionStats {
            total.inputTokens += s.inputTokens
            total.outputTokens += s.outputTokens
            total.totalCost += s.totalCost
            total.requestCount += s.requestCount
        }
        lock.unlock()

        DispatchQueue.main.async {
            self.stats = total
        }
    }

    func resetSession(_ sessionId: String) {
        lock.lock()
        sessionStats.removeValue(forKey: sessionId)
        lock.unlock()
    }
}
