import SwiftUI

struct HeaderBarView<RepoFilterPopover: View>: View {
    let theme: PRDeckTheme
    let zoomScale: CGFloat

    @Binding var searchText: String
    let searchFocused: FocusState<Bool>.Binding

    let needsAttentionCount: Int
    let allCount: Int
    @Binding var showAll: Bool

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
    let lastSuccessfulRefreshAt: Date?
    let onRefresh: () -> Void

    @State private var hoveredAttentionSegment: AttentionSegment?
    @State private var isFilterHovered = false
    @State private var isUpdatedHovered = false

    private enum AttentionSegment: Hashable {
        case attention
        case all
    }

    private var controlHeight: CGFloat { 34 * zoomScale }
    private var pillRadius: CGFloat { 11 * zoomScale }
    private var iconHitSize: CGFloat { 34 * zoomScale }

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * zoomScale) {
            topRow

            if !filterTokens.isEmpty {
                filterTokensRow
            }
        }
        .padding(.horizontal, 14 * zoomScale)
        .padding(.vertical, 10 * zoomScale)
        .background(theme.surface2)
    }

    private var topRow: some View {
        HStack(spacing: 12 * zoomScale) {
            search
                .frame(minWidth: 140 * zoomScale)
                .layoutPriority(2)

            Spacer(minLength: 0)

            attentionToggle
                .layoutPriority(1)

            Spacer(minLength: 0)

            rightControls
                .layoutPriority(0)
        }
        .frame(height: controlHeight)
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
        .frame(height: controlHeight)
        .background(
            RoundedRectangle(cornerRadius: pillRadius, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: pillRadius, style: .continuous)
                        .stroke(searchFocused.wrappedValue ? theme.focusRing : theme.border, lineWidth: searchFocused.wrappedValue ? 1.5 : 1)
                )
        )
    }

    private var attentionToggle: some View {
        HStack(spacing: 0) {
            attentionToggleButton(
                segment: .attention,
                title: "Needs attention",
                count: needsAttentionCount,
                isOn: !showAll,
                action: { showAll = false }
            )

            attentionToggleButton(
                segment: .all,
                title: "All",
                count: allCount,
                isOn: showAll,
                action: { showAll = true }
            )
        }
        .padding(2 * zoomScale)
        .frame(minWidth: 220 * zoomScale, idealWidth: 280 * zoomScale)
        .frame(height: controlHeight)
        .background(
            RoundedRectangle(cornerRadius: pillRadius, style: .continuous)
                .fill(theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: pillRadius, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.14), value: showAll)
        .animation(.easeInOut(duration: 0.10), value: hoveredAttentionSegment)
    }

    private var filterTokensRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6 * zoomScale) {
                ForEach(filterTokens) { token in
                    filterTokenView(token)
                }
            }
        }
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

    private func attentionToggleButton(
        segment: AttentionSegment,
        title: String,
        count: Int,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredAttentionSegment == segment

        return Button(action: action) {
            (
                Text(title)
                    .foregroundStyle(isOn ? theme.textPrimary : theme.textSecondary)
                +
                Text(" (\(count))")
                    .monospacedDigit()
                    .foregroundStyle(isOn ? theme.textSecondary : theme.textTertiary)
            )
            .font(.system(size: 11.25 * zoomScale, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .allowsTightening(true)
            .frame(maxWidth: .infinity)
            .frame(height: controlHeight - (4 * zoomScale))
            .background(
                RoundedRectangle(cornerRadius: (pillRadius - (3 * zoomScale)), style: .continuous)
                    .fill(isOn ? theme.rowSelected : (isHovered ? theme.rowHover : .clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: (pillRadius - (3 * zoomScale)), style: .continuous)
                            .stroke(isOn ? theme.focusRing.opacity(0.8) : .clear, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .prdeckInteractiveCursor()
        .onHover { isHovering in
            if isHovering {
                hoveredAttentionSegment = segment
            } else if hoveredAttentionSegment == segment {
                hoveredAttentionSegment = nil
            }
        }
        .accessibilityLabel(Text("\(title), \(count)"))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var rightControls: some View {
        HStack(spacing: 6 * zoomScale) {
            repoFilterButton
            updatedStatusButton
        }
    }

    private var repoFilterButton: some View {
        Button {
            isRepoFilterPresented = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 15 * zoomScale))
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

    private var updatedStatusButton: some View {
        TimelineView(.periodic(from: .now, by: 20)) { context in
            Button(action: onRefresh) {
                HStack(spacing: 6 * zoomScale) {
                    if isRefreshing {
                        PRDeckSpinner(color: theme.textSecondary, size: 12 * zoomScale, lineWidth: 2 * zoomScale)
                    }

                    Text(updatedText(now: context.date))
                        .monospacedDigit()
                        .font(.system(size: 11 * zoomScale, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                        .foregroundStyle(isUpdatedHovered ? theme.textSecondary : theme.textTertiary)
                }
                .padding(.horizontal, 8 * zoomScale)
                .frame(height: iconHitSize)
                .background(isUpdatedHovered ? theme.rowHover : .clear, in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .prdeckInteractiveCursor()
            .disabled(isRefreshing)
            .onHover { isUpdatedHovered = $0 }
            .help(isRefreshing ? "Refreshing…" : "Refresh")
        }
    }

    private func updatedText(now: Date) -> String {
        if isRefreshing { return "Updating…" }
        guard let lastSuccessfulRefreshAt else { return "Refresh" }
        return "Updated \(TimeAgo.string(from: lastSuccessfulRefreshAt, relativeTo: now))"
    }
}
