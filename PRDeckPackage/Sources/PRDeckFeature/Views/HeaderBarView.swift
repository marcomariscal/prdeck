import SwiftUI

struct HeaderBarView: View {
    let theme: PRDeckTheme
    let zoomScale: CGFloat

    @Binding var searchText: String
    let searchFocused: FocusState<Bool>.Binding

    @Binding var isRepoFilterPresented: Bool
    let isRepoFilterActive: Bool
    let repoFilterActiveCount: Int
    let repoFilterHelp: String

    @State private var isFilterHovered = false

    // Scaled layout values - match row structure exactly
    private var contentPadding: CGFloat { PRDeckLayout.contentPadding * zoomScale }
    private var statusColumnWidth: CGFloat { PRDeckLayout.statusColumnWidth * zoomScale }
    private var rowHeight: CGFloat { PRDeckLayout.rowHeight * zoomScale }

    // Local constants
    private var searchHeight: CGFloat { 34 * zoomScale }
    private var pillRadius: CGFloat { 10 * zoomScale }
    private var iconHitSize: CGFloat { 30 * zoomScale }

    var body: some View {
        HStack(spacing: 12 * zoomScale) {
            search

            filterButton
        }
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PRDeckLayout.listInset + PRDeckLayout.scrollGutter)
        .padding(.vertical, PRDeckLayout.sectionPadding * zoomScale)
        .background(theme.surface)
    }

    private var search: some View {
        HStack(spacing: 8 * zoomScale) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12 * zoomScale, weight: .medium))
                .foregroundStyle(theme.textTertiary)

            TextField("Search PRs...", text: $searchText)
                .textFieldStyle(.plain)
                .focused(searchFocused)
                .font(.system(size: 12.5 * zoomScale, weight: .medium))
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 12 * zoomScale)
        .frame(height: searchHeight)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: pillRadius, style: .continuous)
                .fill(theme.surface2.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: pillRadius, style: .continuous)
                .stroke(searchFocused.wrappedValue ? theme.focusRing.opacity(0.8) : theme.border.opacity(0.5), lineWidth: 1)
        )
    }

    private var filterButton: some View {
        Button {
            isRepoFilterPresented.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15 * zoomScale, weight: .medium))
                    .foregroundStyle(isRepoFilterActive ? theme.accent : theme.textSecondary)

                if isRepoFilterActive {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 6 * zoomScale, height: 6 * zoomScale)
                        .offset(x: 2 * zoomScale, y: -2 * zoomScale)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: iconHitSize, height: iconHitSize)
            .background(
                RoundedRectangle(cornerRadius: 8 * zoomScale, style: .continuous)
                    .fill(isFilterHovered ? theme.rowHover : .clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .prdeckInteractiveCursor()
        .prdeckToolTip(repoFilterHelp)
        .onHover { isFilterHovered = $0 }
    }
}
