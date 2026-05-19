import SwiftUI

/// Agent icon — emoji for Claude Code, SF Symbols for others
struct AgentIconView: View {
    let agentType: AgentType
    let size: CGFloat

    init(agentType: AgentType, size: CGFloat = 14) {
        self.agentType = agentType
        self.size = size
    }

    var body: some View {
        if let emoji = agentType.emojiIcon {
            Text(emoji)
                .font(.system(size: size))
                .frame(width: size * 1.4, height: size * 1.4)
        } else {
            Image(systemName: agentType.sfSymbolName)
                .font(.system(size: size * 0.7, weight: .medium))
                .foregroundStyle(agentType.accentColor)
                .frame(width: size, height: size)
        }
    }
}
