import SwiftUI

private struct PRDeckToolTipFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct PRDeckToolTipModifier: ViewModifier {
    @Environment(\.prdeckTheme) private var theme
    @Environment(\.prdeckZoomScale) private var zoomScale

    let text: String
    let delay: Duration

    @State private var isHovered = false
    @State private var isVisible = false
    @State private var pendingTask: Task<Void, Never>?
    @State private var anchorFrame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: PRDeckToolTipFramePreferenceKey.self, value: proxy.frame(in: .global))
                }
            )
            .onPreferenceChange(PRDeckToolTipFramePreferenceKey.self) { anchorFrame = $0 }
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    scheduleShow()
                } else {
                    hide()
                }
            }
            .overlay(alignment: .topTrailing) {
                if isVisible, !text.isEmpty, !opensBelow {
                    tooltipView
                        .offset(x: -(6 * zoomScale), y: -(34 * zoomScale))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .allowsHitTesting(false)
                        .zIndex(999)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isVisible, !text.isEmpty, opensBelow {
                    tooltipView
                        .offset(x: -(6 * zoomScale), y: (10 * zoomScale))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .allowsHitTesting(false)
                        .zIndex(999)
                }
            }
            .onDisappear { hide() }
    }

    private var opensBelow: Bool {
        anchorFrame.minY < (90 * zoomScale)
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
            .multilineTextAlignment(.leading)
            .lineLimit(1)
            .foregroundStyle(theme.textPrimary)
            .fixedSize(horizontal: true, vertical: false)
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
