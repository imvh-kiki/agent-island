import Foundation

struct UserQuestion: Identifiable, Equatable {
    let id: String               // unique question id
    let sessionId: String
    let questions: [SubQuestion]  // 1-4 questions from AskUserQuestion
    let timestamp: Date
    /// When set, this question was intercepted from PreToolUse.
    /// The answer is returned by denying the tool and passing the answer back via
    /// the hook's `permissionDecisionReason`, which Claude Code surfaces to the model.
    var preToolUseRequestId: String?

    /// Convenience: first question text (for display)
    var question: String {
        questions.first?.question ?? ""
    }

    /// Convenience: first question's options
    var options: [QuestionOption] {
        questions.first?.options ?? []
    }

    static func == (lhs: UserQuestion, rhs: UserQuestion) -> Bool {
        lhs.id == rhs.id
    }
}

/// A single sub-question within an AskUserQuestion call
struct SubQuestion: Identifiable, Equatable {
    let id: String
    let question: String
    let header: String?
    let options: [QuestionOption]
    let multiSelect: Bool
}

struct QuestionOption: Identifiable, Equatable {
    let id: String
    let label: String
    let description: String?
}
