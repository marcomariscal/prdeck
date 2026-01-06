import AppKit
import SwiftUI

private final class CursorTrackingView: NSView {
    var cursor: NSCursor = .arrow
    private var trackingAreaRef: NSTrackingArea?
    private var didPush = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeInKeyWindow,
            .inVisibleRect,
        ]
        let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard !didPush else { return }
        cursor.push()
        didPush = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard didPush else { return }
        NSCursor.pop()
        didPush = false
    }

    deinit {
        if didPush {
            NSCursor.pop()
        }
    }
}

private struct HoverCursor: NSViewRepresentable {
    let cursor: NSCursor

    func makeNSView(context: Context) -> CursorTrackingView {
        let view = CursorTrackingView()
        view.cursor = cursor
        return view
    }

    func updateNSView(_ nsView: CursorTrackingView, context: Context) {
        nsView.cursor = cursor
    }
}

extension View {
    func prdeckHoverCursor(_ cursor: NSCursor) -> some View {
        background(HoverCursor(cursor: cursor))
    }
}
