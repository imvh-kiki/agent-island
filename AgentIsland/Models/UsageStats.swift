import Foundation

struct UsageStats: Equatable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var totalCost: Double = 0.0        // estimated USD
    var requestCount: Int = 0
    var sessionId: String = ""

    var totalTokens: Int { inputTokens + outputTokens }

    var formattedTokens: String {
        if totalTokens >= 1_000_000 {
            return String(format: "%.1fM", Double(totalTokens) / 1_000_000)
        } else if totalTokens >= 1_000 {
            return String(format: "%.1fK", Double(totalTokens) / 1_000)
        }
        return "\(totalTokens)"
    }

    var formattedCost: String {
        String(format: "$%.2f", totalCost)
    }
}
