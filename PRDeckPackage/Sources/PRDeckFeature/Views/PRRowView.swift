import AppKit
import SwiftUI

struct PRRowView: View {
    @Environment(\.prdeckZoomScale) private var zoomScale
    @Environment(\.prdeckTheme) private var theme
    let item: PRItem
    let isSelected: Bool
    let onCopyPRURL: (URL) -> Void
    let onCopyCIURL: (URL) -> Void

    @State private var isHovered = false
    @State private var pendingCopyTask: Task<Void, Never>?
    @AppStorage(PRDeckDefaultsKey.showRepoAvatar) private var showRepoAvatar = true

    var body: some View {
        HStack(spacing: 0) {
            // Column A: Fixed Avatar
            authorAvatar
                .frame(width: 40 * zoomScale, alignment: .leading)

            // Column B: Fluid Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13.5 * zoomScale, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(alignment: .center, spacing: 0) {
                    Text(item.repository.nameWithOwner)
                        .foregroundStyle(theme.textSecondary)
                    
                    Text(" • #\(item.number)")
                        .foregroundStyle(theme.textTertiary)
                        .monospacedDigit()
                    
                    Text(" • ")
                        .foregroundStyle(theme.textDisabled)
                    
                    Text(TimeAgo.string(from: item.updatedAt))
                        .foregroundStyle(theme.textTertiary)
                }
                .font(.system(size: 11.5 * zoomScale, weight: .medium))
                .lineLimit(1)
            }
            
            Spacer(minLength: 16)

            // Column C: Fixed Status Lane
            statusLane
                .frame(width: 44 * zoomScale, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 52 * zoomScale)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .prdeckInteractiveCursor()
        .onTapGesture {
            scheduleCopyPRLink()
        }
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
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
        }
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.visible)
        .listRowSeparatorTint(theme.divider)
        .listRowBackground(rowBackground)
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
        let slotSize = 28 * zoomScale
        let iconSize = 14 * zoomScale

        let color: Color = {
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
        }()

        let helpText: String = {
            switch mergeGateVisual {
            case .clean:
                return "Mergeable"
            case .checksRunning:
                return "Checks running — click to open checks"
            case .failingChecks:
                return "Checks failing — click to open failing check"
            case .blocked:
                return "Blocked — click to open PR"
            case .behind:
                return "Behind base — click to open PR"
            case .dirty:
                return "Cannot merge cleanly — click to open PR"
            case .draft:
                return "Draft — click to open PR"
            case .hasHooks:
                return "Waiting on hooks — click to open PR"
            case .unknown:
                return "Merge status unknown — click to open PR"
            }
        }()

        return Button {
            switch mergeGateVisual {
            case .checksRunning:
                NSWorkspace.shared.open(checksURL)
            case .failingChecks:
                NSWorkspace.shared.open(item.failingCheckURL ?? checksURL)
            case .clean, .blocked, .behind, .dirty, .draft, .hasHooks, .unknown:
                NSWorkspace.shared.open(item.url)
            }
        } label: {
            Group {
                switch mergeGateVisual {
                case .checksRunning:
                    PRDeckSpinner(color: color, size: iconSize, lineWidth: 2.5 * zoomScale)
                case .clean:
                    Image(systemName: "checkmark.circle.fill")
                case .failingChecks:
                    Image(systemName: "xmark.circle.fill")
                case .blocked:
                    Image(systemName: "lock.circle.fill")
                case .behind:
                    Image(systemName: "arrow.triangle.2.circlepath")
                case .dirty:
                    Image(systemName: "exclamationmark.triangle.fill")
                case .draft:
                    Image(systemName: "pencil.circle.fill")
                case .hasHooks:
                    Image(systemName: "bolt.circle.fill")
                case .unknown:
                    Image(systemName: "ellipsis.circle.fill")
                }
            }
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .font(.system(size: iconSize))
            .frame(width: slotSize, height: slotSize)
        }
        .buttonStyle(.plain)
        .prdeckInteractiveCursor()
        .help(helpText)
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
        ZStack {
            if isSelected {
                theme.rowSelected
            } else if isHovered {
                theme.rowHover
            } else {
                Color.clear
            }
        }
    }
}
