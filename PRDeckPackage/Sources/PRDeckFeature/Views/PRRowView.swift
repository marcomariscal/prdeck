import AppKit
import SwiftUI

struct PRRowView: View {
    @Environment(\.prdeckZoomScale) private var zoomScale
    @Environment(\.prdeckTheme) private var theme
    @Environment(\.controlActiveState) private var controlActiveState
    let item: PRItem
    let isRefreshing: Bool
    let isSelected: Bool
    let onCopyPRURL: (URL) -> Void
    let onCopyCIURL: (URL) -> Void
    let onSelect: () -> Void

    @State private var isHovered = false
    @State private var pendingCopyTask: Task<Void, Never>?
    @State private var pendingMergeGateCopyTask: Task<Void, Never>?
    @AppStorage(PRDeckDefaultsKey.showRepoAvatar) private var showRepoAvatar = true

    var body: some View {
        HStack(spacing: 0) {
            // Column A: Fixed Avatar
            authorAvatar
                .frame(width: PRDeckLayout.statusColumnWidth * zoomScale, alignment: .leading)

            // Column B: Fluid Content
            VStack(alignment: .leading, spacing: 3 * zoomScale) {
                Text(item.title)
                    .font(.system(size: 13 * zoomScale, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(alignment: .center, spacing: 0) {
                    Text(item.repository.nameWithOwner)
                        .foregroundStyle(theme.textSecondary)

                    metaDot

                    Text("#\(item.number)")
                        .foregroundStyle(theme.textTertiary)
                        .monospacedDigit()

                    metaDot

                    Text(TimeAgo.string(from: item.updatedAt))
                        .foregroundStyle(theme.textTertiary)
                }
                .font(.system(size: 11 * zoomScale, weight: .medium))
                .lineLimit(1)
            }

            Spacer(minLength: 12 * zoomScale)

            // Column C: Fixed Status Lane
            statusLane
                .frame(width: PRDeckLayout.statusColumnWidth * zoomScale, alignment: .trailing)
        }
        .padding(.horizontal, PRDeckLayout.contentPadding * zoomScale)
        .padding(.vertical, PRDeckLayout.rowVerticalPadding * zoomScale)
        .frame(minHeight: PRDeckLayout.rowHeight * zoomScale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .prdeckInteractiveCursor()
        .onTapGesture {
            onSelect()
            scheduleCopyPRLink()
        }
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                onSelect()
                pendingCopyTask?.cancel()
                pendingCopyTask = nil
                NSWorkspace.shared.open(item.url)
            }
        )
        .contextMenu {
            Button("Copy PR link") { onCopyPRURL(item.url) }
            Button("Open PR") { NSWorkspace.shared.open(item.url) }

            if item.ciState != .none, item.ciState != .unknown {
                Button("Open checks") { NSWorkspace.shared.open(checksURL) }
            }

            if item.ciState == .failed {
                Button("Copy CI logs link") { onCopyCIURL(ciURLToCopy()) }
                Button("Open CI logs") { NSWorkspace.shared.open(ciURLToCopy()) }
            }
        }
        .onDisappear {
            pendingCopyTask?.cancel()
            pendingCopyTask = nil
            pendingMergeGateCopyTask?.cancel()
            pendingMergeGateCopyTask = nil
        }
        .animation(.easeInOut(duration: 0.14), value: isHovered)
        .animation(.easeInOut(duration: 0.14), value: isSelected)
        .animation(.easeInOut(duration: 0.14), value: controlActiveState)
    }

    private var metaDot: some View {
        Image(systemName: "circle.fill")
            .font(.system(size: 4 * zoomScale, weight: .semibold))
            .foregroundStyle(theme.textDisabled.opacity(0.7))
            .padding(.horizontal, 6 * zoomScale)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var authorAvatar: some View {
        ZStack(alignment: .bottomTrailing) {
            authorAvatarBase

            if showRepoAvatar {
                repoAvatar
                    .offset(x: 1.5 * zoomScale, y: 1.5 * zoomScale)
            }
        }
    }

    @ViewBuilder
    private var authorAvatarBase: some View {
        if let url = item.author?.avatarUrl {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    theme.muted.opacity(0.25)
                }
            }
            .frame(width: 28 * zoomScale, height: 28 * zoomScale)
            .clipShape(Circle())
            .overlay(Circle().stroke(theme.border, lineWidth: 1))
            .accessibilityLabel(Text(item.author?.login ?? "Author"))
        } else {
            theme.muted.opacity(0.25)
                .frame(width: 28 * zoomScale, height: 28 * zoomScale)
                .clipShape(Circle())
                .overlay(Circle().stroke(theme.border, lineWidth: 1))
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var repoAvatar: some View {
        if let url = item.repository.ownerAvatarUrl {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    theme.muted.opacity(0.25)
                }
            }
            .frame(width: 13 * zoomScale, height: 13 * zoomScale)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(theme.bg.opacity(0.9), lineWidth: 2 * zoomScale)
            )
            .overlay(Circle().stroke(theme.border, lineWidth: 1))
            .shadow(color: theme.shadow, radius: 2 * zoomScale, x: 0, y: 1 * zoomScale)
            .accessibilityLabel(Text(item.repository.ownerLogin ?? "Repository owner"))
        }
    }

    private enum MergeGateVisual {
        case clean
        case checksRunning
        case failingChecks
        case blocked
        case behind
        case dirty
        case draft
        case hasHooks
        case unknown
    }

    private var mergeGateVisual: MergeGateVisual {
        if item.ciState == .running { return .checksRunning }
        if item.ciState == .failed { return .failingChecks }
        if item.mergeConflict { return .dirty }

        switch item.mergeStateStatus {
        case .clean:
            return .clean
        case .unstable:
            return .failingChecks
        case .blocked:
            return .blocked
        case .behind:
            return .behind
        case .dirty:
            return .dirty
        case .draft:
            return .draft
        case .hasHooks:
            return .hasHooks
        case .unknown, .none:
            return .unknown
        }
    }

    private var statusLane: some View {
        let slotSize = 30 * zoomScale
        let iconSize = 18 * zoomScale

        let color = mergeGateColor

        let helpText: String = {
            switch mergeGateVisual {
            case .clean:
                return "Mergeable — Click: copy PR link • Double-click: open PR"
            case .checksRunning:
                return "Checks running — Click: copy checks link • Double-click: open checks"
            case .failingChecks:
                return "Checks failing — Click: copy link • Double-click: open link"
            case .blocked:
                return "Blocked — Click: copy PR link • Double-click: open PR"
            case .behind:
                return "Behind base — Click: copy PR link • Double-click: open PR"
            case .dirty:
                return "Cannot merge cleanly — Click: copy PR link • Double-click: open PR"
            case .draft:
                return "Draft — Click: copy PR link • Double-click: open PR"
            case .hasHooks:
                return "Waiting on hooks — Click: copy PR link • Double-click: open PR"
            case .unknown:
                return "Merge status unknown — Click: copy PR link • Double-click: open PR"
            }
        }()

        return mergeGateIcon(slotSize: slotSize, iconSize: iconSize, color: color, helpText: helpText)
    }

    private var mergeGateColor: Color {
        switch mergeGateVisual {
        case .clean:
            return theme.success
        case .checksRunning, .blocked, .behind, .hasHooks:
            return theme.warning
        case .failingChecks, .dirty:
            return theme.danger
        case .draft, .unknown:
            return theme.muted
        }
    }

    private func mergeGateIcon(slotSize: CGFloat, iconSize: CGFloat, color: Color, helpText: String) -> some View {
        let urlToCopy: URL = {
            switch mergeGateVisual {
            case .checksRunning:
                return checksURL
            case .failingChecks:
                return item.failingCheckURL ?? checksURL
            case .clean, .blocked, .behind, .dirty, .draft, .hasHooks, .unknown:
                return item.url
            }
        }()

        let urlToOpen = urlToCopy
        let refreshRingSize = max(0, slotSize - (4 * zoomScale))

        let label: some View = Group {
            switch mergeGateVisual {
            case .checksRunning:
                PRDeckSpinner(color: color, size: iconSize * 0.86, lineWidth: 2.6 * zoomScale)
            case .clean:
                mergeGateSymbol("checkmark.circle.fill", size: iconSize, color: color)
            case .failingChecks:
                mergeGateSymbol("xmark.circle.fill", size: iconSize, color: color)
            case .blocked:
                mergeGateSymbol("lock.circle.fill", size: iconSize, color: color)
            case .behind:
                mergeGateSymbol("arrow.triangle.2.circlepath", size: iconSize, color: color)
            case .dirty:
                mergeGateSymbol("exclamationmark.triangle.fill", size: iconSize, color: color)
            case .draft:
                mergeGateSymbol("pencil.circle.fill", size: iconSize, color: color)
            case .hasHooks:
                mergeGateSymbol("bolt.circle.fill", size: iconSize, color: color)
            case .unknown:
                mergeGateSymbol("ellipsis.circle.fill", size: iconSize, color: color)
            }
        }
        .frame(width: slotSize, height: slotSize)
        .overlay {
            if isRefreshing, mergeGateVisual != .checksRunning {
                PRDeckSpinner(color: color.opacity(0.75), size: refreshRingSize, lineWidth: 2.0 * zoomScale)
                    .allowsHitTesting(false)
            }
        }

        return label
            .contentShape(Rectangle())
            .prdeckInteractiveCursor()
            .prdeckToolTip(helpText)
            .accessibilityAddTraits(.isButton)
            .highPriorityGesture(
                TapGesture(count: 2)
                    .exclusively(before: TapGesture())
                    .onEnded { value in
                        switch value {
                        case .first:
                            onSelect()
                            pendingCopyTask?.cancel()
                            pendingCopyTask = nil

                            pendingMergeGateCopyTask?.cancel()
                            pendingMergeGateCopyTask = nil

                            NSWorkspace.shared.open(urlToOpen)
                        case .second:
                            onSelect()
                            scheduleCopyMergeGateLink(urlToCopy)
                        }
                    }
            )
    }

    private func mergeGateSymbol(_ name: String, size: CGFloat, color: Color) -> some View {
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .frame(width: size, height: size)
    }

    private func scheduleCopyMergeGateLink(_ url: URL) {
        pendingMergeGateCopyTask?.cancel()
        pendingMergeGateCopyTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            if url == item.url {
                onCopyPRURL(url)
            } else {
                onCopyCIURL(url)
            }
        }
    }

    private func ciURLToCopy() -> URL {
        if let url = item.failingCheckURL { return url }
        return URL(string: item.url.absoluteString + "/checks") ?? item.url
    }

    private var checksURL: URL {
        URL(string: item.url.absoluteString + "/checks") ?? item.url
    }

    private func scheduleCopyPRLink() {
        pendingCopyTask?.cancel()
        pendingCopyTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            onCopyPRURL(item.url)
        }
    }

    private var rowBackground: some View {
        let cornerRadius = 10 * zoomScale
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let stripeWidth = max(2, 2.5 * zoomScale)
        let stripeOpacity = isSelected ? 0.85 : (isHovered ? 0.7 : 0.55)
        let shadowOpacity = isSelected ? 0.3 : (isHovered ? 0.2 : 0.12)
        let isWindowActive = controlActiveState == .active

        return ZStack(alignment: .leading) {
            shape
                .fill(baseFill)

            if item.needsAttention {
                Rectangle()
                    .fill(mergeGateColor.opacity(stripeOpacity))
                    .frame(width: stripeWidth)
                    .padding(.vertical, PRDeckLayout.sectionPadding * zoomScale)
                    .accessibilityHidden(true)
            }

            shape
                .strokeBorder(baseStroke, lineWidth: 1)
        }
        .clipShape(shape)
        .shadow(color: theme.shadow.opacity(shadowOpacity), radius: 10, x: 0, y: 4)
        .shadow(color: theme.focusRing.opacity(isSelected && isWindowActive ? 0.22 : 0), radius: isSelected && isWindowActive ? 14 : 0, x: 0, y: 0)
    }

    private var baseFill: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        theme.focusRing.opacity(0.18),
                        theme.focusRing.opacity(0.08),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }

        if isHovered {
            return AnyShapeStyle(theme.rowHover.opacity(0.85))
        }

        return AnyShapeStyle(theme.surface2.opacity(0.75))
    }

    private var baseStroke: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(theme.focusRing.opacity(0.5))
        }

        if isHovered {
            return AnyShapeStyle(theme.border.opacity(0.5))
        }

        return AnyShapeStyle(theme.border.opacity(0.25))
    }
}
