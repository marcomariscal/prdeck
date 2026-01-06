import SwiftUI

private struct PRDeckToolTipModifier: ViewModifier {
    @Environment(\.prdeckTheme) private var theme
    @Environment(\.prdeckZoomScale) private var zoomScale

    let text: String
    let delay: Duration

    @State private var isHovered = false
    @State private var isVisible = false
    @State private var pendingTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    scheduleShow()
                } else {
                    hide()
                }
            }
            .overlay(alignment: .top) {
                if isVisible, !text.isEmpty {
                    tooltipView
                        .offset(y: -(34 * zoomScale))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .allowsHitTesting(false)
                        .zIndex(999)
                }
            }
            .onDisappear { hide() }
    }

    private func scheduleShow() {
        guard !text.isEmpty else { return }

        pendingTask?.cancel()
        pendingTask = Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard isHovered else { return }
            withAnimation(.easeInOut(duration: 0.14)) {
                isVisible = true
            }
        }
    }

    private func hide() {
        pendingTask?.cancel()
        pendingTask = nil
        withAnimation(.easeInOut(duration: 0.12)) {
            isVisible = false
        }
    }

    private var tooltipView: some View {
        Text(text)
            .font(.system(size: 12.5 * zoomScale, weight: .medium))
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 10 * zoomScale)
            .padding(.vertical, 7 * zoomScale)
            .background(
                RoundedRectangle(cornerRadius: 10 * zoomScale, style: .continuous)
                    .fill(theme.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10 * zoomScale, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
            )
            .shadow(color: theme.shadow, radius: 8 * zoomScale, x: 0, y: 4 * zoomScale)
    }
}

extension View {
    func prdeckToolTip(_ text: String, delay: Duration = .seconds(1)) -> some View {
        modifier(PRDeckToolTipModifier(text: text, delay: delay))
    }
}
