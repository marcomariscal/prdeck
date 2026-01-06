import SwiftUI

struct HeaderBarView<RepoFilterPopover: View>: View {
    let theme: PRDeckTheme
    let zoomScale: CGFloat

    @Binding var searchText: String
    let searchFocused: FocusState<Bool>.Binding

    @Binding var isRepoFilterPresented: Bool
    let isRepoFilterActive: Bool
    let repoFilterActiveCount: Int
    let repoFilterHelp: String
    @ViewBuilder let repoFilterPopover: () -> RepoFilterPopover

    struct FilterToken: Identifiable, Equatable {
        let id: String
        let label: String
        let onRemove: () -> Void

        static func == (lhs: FilterToken, rhs: FilterToken) -> Bool {
            lhs.id == rhs.id && lhs.label == rhs.label
        }
    }

    let filterTokens: [FilterToken]
    let isRefreshing: Bool

    @State private var isFilterHovered = false

    private var rowHeight: CGFloat { 52 * zoomScale }
    private var searchHeight: CGFloat { 36 * zoomScale }
    private var pillRadius: CGFloat { 11 * zoomScale }
    private var iconHitSize: CGFloat { 34 * zoomScale }

    // Keep header aligned with PRRowView layout constants.
    private var rowPaddingX: CGFloat { 12 * zoomScale }
    private var avatarColumnWidth: CGFloat { 40 * zoomScale }
    private var statusColumnWidth: CGFloat { 44 * zoomScale }

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * zoomScale) {
            topRow

            if !filterTokens.isEmpty {
                filterTokensRow
            }
        }
        .padding(.horizontal, rowPaddingX)
        .padding(.vertical, 10 * zoomScale)
        .background(theme.surface2)
    }

    private var topRow: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: avatarColumnWidth)

            search
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: searchHeight)
                .padding(.trailing, 10 * zoomScale)

            filterButton
                .frame(width: statusColumnWidth, height: rowHeight, alignment: .trailing)
        }
        .frame(height: rowHeight)
    }

    private var search: some View {
        HStack(spacing: 6 * zoomScale) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13 * zoomScale))
                .foregroundStyle(theme.textDisabled)

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

    private var filterTokensRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6 * zoomScale) {
                ForEach(filterTokens) { token in
                    filterTokenView(token)
                }
            }
        }
        .padding(.leading, avatarColumnWidth)
    }

    private func filterTokenView(_ token: FilterToken) -> some View {
        HStack(spacing: 4 * zoomScale) {
            Text(token.label)
                .font(.system(size: 11 * zoomScale, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Button(action: token.onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8 * zoomScale, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .prdeckInteractiveCursor()
        }
        .padding(.leading, 8 * zoomScale)
        .padding(.trailing, 6 * zoomScale)
        .frame(height: 22 * zoomScale)
        .background(
            Capsule(style: .continuous)
                .fill(theme.surface)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
        )
    }

    private var filterButton: some View {
        Button {
            isRepoFilterPresented = true
        } label: {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 16 * zoomScale))
                        .foregroundStyle(isRepoFilterActive ? theme.textPrimary : theme.textTertiary)
                        .opacity(isRepoFilterActive ? 1 : 0.8)

                    if isRefreshing {
                        PRDeckSpinner(color: theme.textSecondary, size: 16 * zoomScale, lineWidth: 2.4 * zoomScale)
                    }
                }

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
                    .offset(x: 5 * zoomScale, y: -5 * zoomScale)
                    .accessibilityHidden(true)
                }
            }
            .frame(width: iconHitSize, height: iconHitSize)
            .background(isFilterHovered ? theme.rowHover : .clear, in: Circle())
        }
        .buttonStyle(.plain)
        .prdeckInteractiveCursor()
        .onHover { isFilterHovered = $0 }
        .popover(isPresented: $isRepoFilterPresented, arrowEdge: .top) {
            repoFilterPopover()
        }
        .help(repoFilterHelp)
    }
}

