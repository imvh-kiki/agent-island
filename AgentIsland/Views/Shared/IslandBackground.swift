import SwiftUI

struct IslandBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        PillShape(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .overlay(
                PillShape(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.35))
            )
            .overlay(
                PillShape(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
    }
}
