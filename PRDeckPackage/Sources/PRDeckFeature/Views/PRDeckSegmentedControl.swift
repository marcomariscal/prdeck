import SwiftUI

struct PRDeckSegmentedControl<Selection: Hashable>: View {
    struct Segment: Identifiable {
        let id: Selection
        let title: String

        init(_ value: Selection, title: String) {
            id = value
            self.title = title
        }
    }

    let theme: PRDeckTheme
    let zoomScale: CGFloat
    let segments: [Segment]
    @Binding var selection: Selection

    @State private var hoveredId: Selection?

    private var segmentHeight: CGFloat { 32 * zoomScale }
    private var segmentRadius: CGFloat { 10 * zoomScale }
    private var containerPadding: CGFloat { 2 * zoomScale }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments) { segment in
                let isSelected = selection == segment.id
                let isHovered = hoveredId == segment.id

                Button {
                    selection = segment.id
                } label: {
                    Text(segment.title)
                        .font(.system(size: 12.5 * zoomScale, weight: .semibold))
                        .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: segmentHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: segmentRadius, style: .continuous)
                        .fill(isSelected ? theme.elevated : (isHovered ? theme.rowHover : .clear))
                )
                .prdeckInteractiveCursor()
                .onHover { hoveredId = $0 ? segment.id : (hoveredId == segment.id ? nil : hoveredId) }

                if segment.id != segments.last?.id {
                    Rectangle()
                        .fill(theme.divider)
                        .frame(width: 1)
                        .padding(.vertical, 7 * zoomScale)
                }
            }
        }
        .padding(containerPadding)
        .background(
            RoundedRectangle(cornerRadius: segmentRadius + containerPadding, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: segmentRadius + containerPadding, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
        )
        .frame(height: segmentHeight + (containerPadding * 2))
        .animation(.easeInOut(duration: 0.16), value: selection)
    }
}

