import SwiftUI

struct PRDeckSpinner: View {
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat

    @State private var isAnimating = false

    init(color: Color, size: CGFloat = 14, lineWidth: CGFloat = 2.5) {
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)

            Circle()
                .trim(from: 0.12, to: 0.96)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color.opacity(0.15), color]),
                        center: .center
                    ),
                    style: .init(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 0.75).repeatForever(autoreverses: false), value: isAnimating)
        }
        .frame(width: size, height: size)
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
    }
}

