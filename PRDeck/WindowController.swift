import AppKit
import SwiftUI

final class WindowController: NSWindowController, NSWindowDelegate {
    private enum DefaultsKey {
        static let windowFrame = "windowFrame"
        static let pinnedCorner = "pinnedCorner"
    }

    private enum PinnedCorner: String {
        case topLeft
        case topRight
    }

    convenience init<Content: View>(rootView: Content) {
        let hostingView = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: .init(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.title = "PRDeck"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false

        self.init(window: window)

        window.delegate = self
        restoreFrameAndPin()
    }

    func windowDidMove(_ notification: Notification) {
        persistFrame()
    }

    func windowDidResize(_ notification: Notification) {
        persistFrame()
    }

    private func persistFrame() {
        guard let frame = window?.frame else { return }
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: DefaultsKey.windowFrame)
    }

    private func restoreFrameAndPin() {
        guard let window else { return }

        let pinnedCorner = PinnedCorner(
            rawValue: UserDefaults.standard.string(forKey: DefaultsKey.pinnedCorner) ?? ""
        ) ?? .topRight

        let savedFrame = UserDefaults.standard.string(forKey: DefaultsKey.windowFrame).map(NSRectFromString)
        let size = savedFrame?.size ?? .init(width: 420, height: 520)

        let screenFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .init(x: 0, y: 0, width: 1200, height: 800)
        let margin: CGFloat = 12

        let origin: CGPoint = {
            switch pinnedCorner {
            case .topLeft:
                return .init(
                    x: screenFrame.minX + margin,
                    y: screenFrame.maxY - margin - size.height
                )
            case .topRight:
                return .init(
                    x: screenFrame.maxX - margin - size.width,
                    y: screenFrame.maxY - margin - size.height
                )
            }
        }()

        window.setFrame(.init(origin: origin, size: size), display: true)
        persistFrame()
        UserDefaults.standard.set(pinnedCorner.rawValue, forKey: DefaultsKey.pinnedCorner)
    }
}

