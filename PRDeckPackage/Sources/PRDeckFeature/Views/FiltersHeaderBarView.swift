import AppKit
import SwiftUI

struct FiltersHeaderBarView: View {
    let theme: PRDeckTheme
    let zoomScale: CGFloat
    let onBack: () -> Void

    @State private var isBackHovered = false

    private var rowHeight: CGFloat { 52 * zoomScale }
    private var toolbarPaddingLeading: CGFloat { 20 * zoomScale }
    private var toolbarPaddingTrailing: CGFloat { (20 * zoomScale) + scrollerGutterWidth }
    private var statusIconSize: CGFloat { 18 * zoomScale }
    private var statusColumnWidth: CGFloat { 44 * zoomScale }

    private var scrollerGutterWidth: CGFloat {
        guard NSScroller.preferredScrollerStyle == .legacy else { return 0 }
        return NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    }

    var body: some View {
        HStack(spacing: 10 * zoomScale) {
            Button(action: onBack) {
                HStack(spacing: 6 * zoomScale) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12.5 * zoomScale, weight: .bold))
                        .foregroundStyle(theme.textPrimary)

                    Text("Back")
                        .font(.system(size: 12.5 * zoomScale, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                }
                .padding(.horizontal, 10 * zoomScale)
                .frame(height: 30 * zoomScale)
                .background(
                    Capsule(style: .continuous)
                        .fill(isBackHovered ? theme.rowHover : theme.surface)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(theme.border, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .prdeckInteractiveCursor()
            .onHover { isBackHovered = $0 }

            Spacer()

            Group {
                Color.clear
                    .frame(width: statusIconSize, height: statusIconSize)
                    .accessibilityHidden(true)
            }
            .frame(width: statusColumnWidth, height: rowHeight, alignment: .trailing)
        }
        .frame(height: rowHeight)
        .padding(.leading, toolbarPaddingLeading)
        .padding(.trailing, toolbarPaddingTrailing)
        .padding(.vertical, 10 * zoomScale)
        .background(theme.surface)
    }
}
