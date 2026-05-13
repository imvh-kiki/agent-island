import SwiftUI

struct IslandBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        PillShape(cornerRadius: cornerRadius)
            .fill(.black.opacity(0.92))
            .overlay(
                PillShape(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.15),
                                .white.opacity(0.05),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 20, y: 5)
    }
}
