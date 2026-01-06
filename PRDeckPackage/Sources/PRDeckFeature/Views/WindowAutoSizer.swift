import AppKit
import SwiftUI

struct PRDeckViewHeightPreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func prdeckMeasureHeight(_ id: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: PRDeckViewHeightPreferenceKey.self, value: [id: proxy.size.height])
            }
        )
    }
}

struct WindowAutoSizer: NSViewRepresentable {
    var desiredContentHeight: CGFloat?

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let desiredContentHeight else { return }

        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if window.inLiveResize { return }

            let currentFrame = window.frame
            let currentContentRect = window.contentRect(forFrameRect: currentFrame)

            let titlebarHeight = currentFrame.height - currentContentRect.height
            let maxContentHeight = max(0, (window.screen?.visibleFrame.height ?? 800) - titlebarHeight - 24)
            let clampedDesiredHeight = max(0, min(desiredContentHeight, maxContentHeight))

            // Only shrink to remove empty space; don't grow automatically.
            if clampedDesiredHeight >= currentContentRect.height - 2 { return }

            let desiredContentRect = NSRect(origin: .zero, size: .init(width: currentContentRect.width, height: clampedDesiredHeight))
            let desiredFrameRect = window.frameRect(forContentRect: desiredContentRect)

            var newFrame = currentFrame
            newFrame.origin.y += currentFrame.height - desiredFrameRect.height // keep top edge pinned
            newFrame.size.height = desiredFrameRect.height

            if abs(newFrame.height - currentFrame.height) < 1 { return }
            window.setFrame(newFrame, display: true, animate: true)
        }
    }
}
