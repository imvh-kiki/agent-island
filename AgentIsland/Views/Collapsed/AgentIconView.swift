import SwiftUI

/// 8-bit pixel art style agent icon
struct AgentIconView: View {
    let agentType: AgentType
    let size: CGFloat

    init(agentType: AgentType, size: CGFloat = 22) {
        self.agentType = agentType
        self.size = size
    }

    var body: some View {
        // Procedural 8-bit style Claude icon
        // Uses a pixel grid to create a retro-styled agent face
        switch agentType {
        case .claudeCode:
            claudePixelIcon
        }
    }

    /// Procedural 8-bit Claude icon — orange/coral tones
    private var claudePixelIcon: some View {
        let pixelSize = size / 8.0
        let pixels: [[Color?]] = [
            [nil,     nil,     .claude, .claude, .claude, .claude, nil,     nil    ],
            [nil,     .claude, .claude, .claude, .claude, .claude, .claude, nil    ],
            [.claude, .claude, .white,  .claude, .claude, .white,  .claude, .claude],
            [.claude, .claude, .claude, .claude, .claude, .claude, .claude, .claude],
            [.claude, .claude, .claude, .claude, .claude, .claude, .claude, .claude],
            [.claude, .claude, .mouth,  .mouth,  .mouth,  .mouth,  .claude, .claude],
            [nil,     .claude, .claude, .claude, .claude, .claude, .claude, nil    ],
            [nil,     nil,     .claude, .claude, .claude, .claude, nil,     nil    ],
        ]

        return Canvas { context, canvasSize in
            for (row, cols) in pixels.enumerated() {
                for (col, color) in cols.enumerated() {
                    guard let color else { continue }
                    let rect = CGRect(
                        x: CGFloat(col) * pixelSize,
                        y: CGFloat(row) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// Custom colors for the pixel art
private extension Color {
    static let claude = Color(red: 0.85, green: 0.45, blue: 0.25)  // Claude orange
    static let mouth = Color(red: 0.7, green: 0.3, blue: 0.2)      // Darker for mouth
}
