import SwiftUI

struct AskQuestionView: View {
    let session: AgentSession
    let question: UserQuestion
    let onAnswer: (String) -> Void
    let onCancel: () -> Void

    /// Current question index (for multi-question pagination)
    @State private var currentIndex = 0
    /// Collected answers for each question (keyed by sub-question index)
    @State private var answers: [Int: String] = [:]
    /// Whether the "Other" text field is active
    @State private var showOtherInput = false
    /// Text for the "Other" free-text input
    @State private var otherText = ""
    /// Text for pure free-text questions (no options)
    @State private var textInput = ""
    /// Hovered option ID for indigo border effect
    @State private var hoveredOptionId: String?
    /// Hovered cancel/back button
    @State private var cancelHovered = false

    private var totalQuestions: Int { question.questions.count }
    private var currentSubQuestion: SubQuestion? {
        guard currentIndex < question.questions.count else { return nil }
        return question.questions[currentIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            header

            // Question content
            if let sub = currentSubQuestion {
                questionContent(sub)
            }

            Spacer(minLength: 0)

            // Bottom: Dismiss
            Button(action: onCancel) {
                Text("Dismiss")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(
            width: IslandSize.questionWidth,
            height: IslandSize.questionHeight(for: question)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            // Contextual icon with tinted background
            Text("❓")
                .font(.system(size: 15))
                .frame(width: 30, height: 30)
                .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Question")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    if totalQuestions > 1 {
                        Text("\(currentIndex + 1)/\(totalQuestions)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.white.opacity(0.1), in: Capsule())
                    }
                }

                Text(session.agentType.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Circle()
                .fill(.indigo)
                .frame(width: 8, height: 8)
                .modifier(PulseModifier())
        }
    }

    // MARK: - Question Content

    @ViewBuilder
    private func questionContent(_ sub: SubQuestion) -> some View {
        // Question text (fixed, not scrollable — keeps it anchored)
        if let h = sub.header {
            Text(h)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)
        }

        Text(sub.question)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)

        if sub.options.isEmpty {
            freeTextInput
        } else if showOtherInput {
            otherTextInput
        } else {
            optionButtons(sub)
        }
    }

    // MARK: - Free text (no options)

    private var freeTextInput: some View {
        VStack(spacing: 8) {
            TextField("", text: $textInput, prompt: Text("Type your answer...").foregroundColor(.white.opacity(0.4)))
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .padding(8)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(cancelHovered ? .white.opacity(0.9) : .white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(cancelHovered ? .white.opacity(0.14) : .white.opacity(0.1), in: Capsule())
                        .animation(.easeOut(duration: 0.15), value: cancelHovered)
                }
                .buttonStyle(IslandButtonStyle())
                .onHover { cancelHovered = $0 }

                Button {
                    guard !textInput.isEmpty else { return }
                    selectAnswer(textInput)
                } label: {
                    Text("Send")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.indigo, in: Capsule())
                }
                .buttonStyle(IslandPrimaryButtonStyle())
            }
        }
    }

    // MARK: - "Other" text input mode

    private var otherTextInput: some View {
        VStack(spacing: 8) {
            TextField("Type your answer...", text: $otherText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .padding(8)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                Button {
                    showOtherInput = false
                    otherText = ""
                } label: {
                    Text("Back")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(cancelHovered ? .white.opacity(0.9) : .white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(cancelHovered ? .white.opacity(0.14) : .white.opacity(0.1), in: Capsule())
                        .animation(.easeOut(duration: 0.15), value: cancelHovered)
                }
                .buttonStyle(IslandButtonStyle())
                .onHover { cancelHovered = $0 }

                Button {
                    guard !otherText.isEmpty else { return }
                    selectAnswer(otherText)
                } label: {
                    Text("Send")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.indigo, in: Capsule())
                }
                .buttonStyle(IslandPrimaryButtonStyle())
            }
        }
    }

    // MARK: - Option buttons

    private func optionButtons(_ sub: SubQuestion) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(sub.options) { option in
                    let isHovered = hoveredOptionId == option.id
                    Button {
                        selectAnswer(option.label)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(isHovered ? .white : .white.opacity(0.9))

                                if let desc = option.description {
                                    Text(desc)
                                        .font(.system(size: 10))
                                        .foregroundStyle(isHovered ? .white.opacity(0.65) : .white.opacity(0.5))
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(isHovered ? .white.opacity(0.5) : .white.opacity(0.3))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            isHovered ? .white.opacity(0.12) : .white.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isHovered ? .white.opacity(0.2) : .clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(IslandButtonStyle())
                    .onHover { over in
                        withAnimation(.easeOut(duration: 0.15)) {
                            hoveredOptionId = over ? option.id : nil
                        }
                    }
                }

                // "Other" option — same style as regular options
                let otherHovered = hoveredOptionId == "__other__"
                Button {
                    showOtherInput = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Other...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(otherHovered ? .white : .white.opacity(0.9))
                            Text("Type a custom answer")
                                .font(.system(size: 10))
                                .foregroundStyle(otherHovered ? .white.opacity(0.65) : .white.opacity(0.5))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(otherHovered ? .white.opacity(0.5) : .white.opacity(0.3))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        otherHovered ? .white.opacity(0.12) : .white.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(otherHovered ? .white.opacity(0.2) : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(IslandButtonStyle())
                .onHover { over in
                    withAnimation(.easeOut(duration: 0.15)) {
                        hoveredOptionId = over ? "__other__" : nil
                    }
                }
            }
        }
    }

    // MARK: - Answer Logic

    private func selectAnswer(_ answer: String) {
        answers[currentIndex] = answer

        if currentIndex + 1 < totalQuestions {
            // Move to next question
            withAnimation(IslandSpring.micro) {
                currentIndex += 1
                showOtherInput = false
                otherText = ""
            }
        } else {
            // All questions answered — send combined answer
            submitAllAnswers()
        }
    }

    private func submitAllAnswers() {
        if totalQuestions == 1 {
            onAnswer(answers[0] ?? "")
        } else {
            // Format: "Q1: answer1, Q2: answer2, ..."
            let parts = (0..<totalQuestions).compactMap { i -> String? in
                guard let a = answers[i] else { return nil }
                let header = question.questions[i].header ?? "Q\(i + 1)"
                return "\(header): \(a)"
            }
            onAnswer(parts.joined(separator: "\n"))
        }
    }
}
