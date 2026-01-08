import SwiftUI

struct FiltersHeaderBarView: View {
    let theme: PRDeckTheme
    let zoomScale: CGFloat
    let onBack: () -> Void

    @State private var isBackHovered = false

    // Scaled layout values - match row structure exactly
    private var contentPadding: CGFloat { PRDeckLayout.contentPadding * zoomScale }
    private var statusColumnWidth: CGFloat { PRDeckLayout.statusColumnWidth * zoomScale }
    private var rowHeight: CGFloat { PRDeckLayout.rowHeight * zoomScale }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 6 * zoomScale) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11 * zoomScale, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)

                    Text("Back")
                        .font(.system(size: 12.5 * zoomScale, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                }
                .padding(.horizontal, 12 * zoomScale)
                .frame(height: 30 * zoomScale)
                .background(
                    RoundedRectangle(cornerRadius: 8 * zoomScale, style: .continuous)
                        .fill(isBackHovered ? theme.rowHover : theme.surface2.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8 * zoomScale, style: .continuous)
                        .stroke(theme.border.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .prdeckInteractiveCursor()
            .onHover { isBackHovered = $0 }

            Spacer()

            Text("Filters")
                .font(.system(size: 12 * zoomScale, weight: .medium))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PRDeckLayout.listInset + PRDeckLayout.scrollGutter)
        .padding(.vertical, PRDeckLayout.sectionPadding * zoomScale)
        .background(theme.surface)
    }
}
