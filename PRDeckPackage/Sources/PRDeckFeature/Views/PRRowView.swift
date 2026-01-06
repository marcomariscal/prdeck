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
                .frame(width: 100 * zoomScale, alignment: .trailing)
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

    private var statusLane: some View {
        HStack(spacing: 0) {
            // Slot 1: Conflict
            ZStack {
                if item.mergeConflict {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.warning)
                        .font(.system(size: 12 * zoomScale))
                        .help("Merge conflict")
                }
            }
            .frame(width: 28 * zoomScale, height: 28 * zoomScale)

            // Slot 2: CI
            ZStack {
                switch item.ciState {
                case .failed:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.danger)
                        .font(.system(size: 12 * zoomScale))
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.success)
                        .font(.system(size: 12 * zoomScale))
                case .running:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .tint(theme.warning)
                        .scaleEffect(0.75 * zoomScale)
                case .none, .unknown:
                    EmptyView()
                }
            }
            .frame(width: 28 * zoomScale, height: 28 * zoomScale)
            .help(ciHelpText)

            // Slot 3: Review
            ZStack {
                if item.reviewDecision == .changesRequested {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(theme.danger)
                } else if item.isReviewRequestedToMe {
                    Image(systemName: "person.badge.exclamationmark")
                        .foregroundStyle(theme.info)
                } else if item.reviewDecision == .approved {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(theme.muted)
                } else if item.reviewDecision == .reviewRequired {
                    Image(systemName: "circle.dashed")
                        .foregroundStyle(theme.warning)
                }
            }
            .font(.system(size: 13 * zoomScale))
            .frame(width: 28 * zoomScale, height: 28 * zoomScale)
            .help(reviewHelpText)
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

    private var ciHelpText: String {
        switch item.ciState {
        case .failed: return "CI failed"
        case .running: return "CI running"
        case .success: return "CI passed"
        default: return ""
        }
    }

    private var reviewHelpText: String {
        if item.reviewDecision == .changesRequested { return "Changes requested" }
        if item.isReviewRequestedToMe { return "Review requested (to you)" }
        if item.reviewDecision == .approved { return "Approved" }
        if item.reviewDecision == .reviewRequired { return "Review required" }
        return ""
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
