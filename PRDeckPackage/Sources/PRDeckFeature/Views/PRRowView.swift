import AppKit
import SwiftUI

struct PRRowView: View {
    @Environment(\.prdeckZoomScale) private var zoomScale
    let item: PRItem
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Column A: Fixed Avatar
            authorAvatar
                .frame(width: 40 * zoomScale, alignment: .leading)

            // Column B: Fluid Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13.5 * zoomScale, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(alignment: .center, spacing: 0) {
                    Text(item.repository.nameWithOwner)
                        .foregroundStyle(.white.opacity(0.65))
                    
                    Text(" • #\(item.number)")
                        .foregroundStyle(.white.opacity(0.5))
                        .monospacedDigit()
                    
                    Text(" • ")
                        .foregroundStyle(.white.opacity(0.3))
                    
                    Text(TimeAgo.string(from: item.updatedAt))
                        .foregroundStyle(.white.opacity(0.5))
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
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.visible)
        .listRowSeparatorTint(.white.opacity(0.08))
        .listRowBackground(rowBackground)
    }

    @ViewBuilder
    private var authorAvatar: some View {
        if let url = item.author?.avatarUrl {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Color.gray.opacity(0.2)
                }
            }
            .frame(width: 28 * zoomScale, height: 28 * zoomScale)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 1))
            .accessibilityLabel(Text(item.author?.login ?? "Author"))
        } else {
            Color.gray.opacity(0.2)
                .frame(width: 28 * zoomScale, height: 28 * zoomScale)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 1))
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var repoAvatar: some View {
        EmptyView()
    }

    private var statusLane: some View {
        HStack(spacing: 0) {
            // Slot 1: Conflict
            ZStack {
                if item.mergeConflict {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
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
                        .foregroundStyle(.red)
                        .font(.system(size: 12 * zoomScale))
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green.opacity(0.8))
                        .font(.system(size: 12 * zoomScale))
                case .running:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.mini)
                        .tint(.yellow)
                        .scaleEffect(0.7)
                case .none, .unknown:
                    EmptyView()
                }
            }
            .frame(width: 28 * zoomScale, height: 28 * zoomScale)
            .help(ciHelpText)
            .onTapGesture {
                openCiUrl()
            }

            // Slot 3: Review
            ZStack {
                if item.reviewDecision == .changesRequested {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                } else if item.isReviewRequestedToMe {
                    Image(systemName: "person.badge.exclamationmark")
                        .foregroundStyle(.blue)
                } else if item.reviewDecision == .approved {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.secondary.opacity(0.5))
                } else if item.reviewDecision == .reviewRequired {
                    Image(systemName: "circle.dashed")
                        .foregroundStyle(.yellow)
                }
            }
            .font(.system(size: 13 * zoomScale))
            .frame(width: 28 * zoomScale, height: 28 * zoomScale)
            .help(reviewHelpText)
        }
    }

    private func openCiUrl() {
        guard item.ciState == .failed || item.ciState == .running else { return }
        if let url = item.failingCheckURL {
            NSWorkspace.shared.open(url)
            return
        }
        if let checksURL = URL(string: item.url.absoluteString + "/checks") {
            NSWorkspace.shared.open(checksURL)
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
                Color.white.opacity(0.12)
            } else if isHovered {
                Color.white.opacity(0.06)
            } else {
                Color.clear
            }
        }
    }
}
