import Foundation

struct PlanReview: Identifiable, Equatable {
    let id: String
    let sessionId: String
    let title: String
    let content: String          // Markdown content
    let timestamp: Date

    static func == (lhs: PlanReview, rhs: PlanReview) -> Bool {
        lhs.id == rhs.id
    }
}
