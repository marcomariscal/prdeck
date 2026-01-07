import AppKit
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

    private var rowHeight: CGFloat { 52 * zoomScale }
    private var searchHeight: CGFloat { 36 * zoomScale }
    private var pillRadius: CGFloat { 11 * zoomScale }
    private var iconHitSize: CGFloat { 30 * zoomScale }
    private var statusIconSize: CGFloat { 18 * zoomScale }

    private var toolbarPaddingLeading: CGFloat { 20 * zoomScale }
    private var toolbarPaddingTrailing: CGFloat { (20 * zoomScale) + scrollerGutterWidth }
    private var statusColumnWidth: CGFloat { 44 * zoomScale }

    private var scrollerGutterWidth: CGFloat {
        guard NSScroller.preferredScrollerStyle == .legacy else { return 0 }
        return NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    }

    var body: some View {
        topRow
        .padding(.leading, toolbarPaddingLeading)
        .padding(.trailing, toolbarPaddingTrailing)
        .padding(.vertical, 10 * zoomScale)
        .background(theme.surface)
    }

    private var topRow: some View {
        HStack(spacing: 0) {
            search
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: searchHeight)

            Spacer(minLength: 16 * zoomScale)

            filterButton
        }
        .frame(height: rowHeight)
    }

    private var search: some View {
        HStack(spacing: 6 * zoomScale) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13 * zoomScale))
                .foregroundStyle(theme.textDisabled)
                .frame(width: 14 * zoomScale, height: 14 * zoomScale)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .focused(searchFocused)
                .font(.system(size: 13 * zoomScale))
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 10 * zoomScale)
        .frame(height: searchHeight)
        .background(
            RoundedRectangle(cornerRadius: pillRadius, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: pillRadius, style: .continuous)
                        .stroke(searchFocused.wrappedValue ? theme.focusRing : theme.border, lineWidth: searchFocused.wrappedValue ? 1.5 : 1)
                )
        )
    }

    private var filterButton: some View {
        Button {
            isRepoFilterPresented.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: statusIconSize))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isRepoFilterActive ? theme.textPrimary : theme.textTertiary)
                    .opacity(isRepoFilterActive ? 1 : 0.8)

                if isRepoFilterActive {
                    Group {
                        if repoFilterActiveCount <= 9 {
                            Text("\(repoFilterActiveCount)")
                                .font(.system(size: 9 * zoomScale, weight: .bold))
                                .foregroundStyle(theme.bg)
                                .frame(width: 12 * zoomScale, height: 12 * zoomScale)
                                .background(theme.accent, in: Circle())
                        } else {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 6 * zoomScale, height: 6 * zoomScale)
                        }
                    }
                    .offset(x: 4 * zoomScale, y: -4 * zoomScale)
                    .accessibilityHidden(true)
                }
            }
            .frame(width: iconHitSize, height: iconHitSize)
            .background(isFilterHovered ? theme.rowHover : .clear, in: Circle())
        }
        .buttonStyle(.plain)
        .frame(width: statusColumnWidth, height: rowHeight, alignment: .trailing)
        .contentShape(Rectangle())
        .prdeckInteractiveCursor()
        .onHover { isFilterHovered = $0 }
    }
}
