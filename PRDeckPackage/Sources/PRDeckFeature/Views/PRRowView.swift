import SwiftUI

struct PRRowView: View {
    @Environment(\.prdeckZoomScale) private var zoomScale
    let item: PRItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(item.repository.nameWithOwner) #\(item.number)")
                    .font(.system(size: 12 * zoomScale))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(TimeAgo.string(from: item.updatedAt))
                    .font(.system(size: 11 * zoomScale))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                authorAvatar
                Text(item.title)
                    .font(.system(size: 13 * zoomScale))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                if item.isDraft {
                    pill("Draft", color: .gray)
                }

                if item.mergeConflict {
                    pill("Conflict", color: .red)
                }

                switch item.ciState {
                case .failed:
                    pill("CI Failed", color: .red)
                case .running:
                    spinnerPill("CI", color: .orange)
                case .success:
                    pill("CI OK", color: .green)
                case .none, .unknown:
                    EmptyView()
                }

                if item.isReviewRequestedToMe {
                    pill("Review requested", color: .blue)
                }

                if item.reviewDecision == .changesRequested {
                    pill("Changes requested", color: .red)
                } else if item.reviewDecision == .reviewRequired {
                    pill("Review required", color: .yellow)
                } else if item.reviewDecision == .approved {
                    pill("Approved", color: .green)
                }
            }
        }
        .padding(.vertical, 6)
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
                    Color.gray.opacity(0.25)
                }
            }
            .frame(width: 22 * zoomScale, height: 22 * zoomScale)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
            .accessibilityLabel(Text(item.author?.login ?? "Author"))
        } else {
            Color.gray.opacity(0.25)
                .frame(width: 22 * zoomScale, height: 22 * zoomScale)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
                .accessibilityHidden(true)
        }
    }

    private func pill(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10 * zoomScale))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func spinnerPill(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.mini)
                .tint(color)
            Text(title)
        }
        .font(.system(size: 10 * zoomScale))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}
