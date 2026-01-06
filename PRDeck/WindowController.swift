import AppKit
import SwiftUI

final class WindowController: NSWindowController, NSWindowDelegate {
    private enum DefaultsKey {
        static let windowFrame = "windowFrame"
        static let pinnedCorner = "pinnedCorner"
    }

    private enum WindowDefaults {
        static let defaultContentSize = CGSize(width: 420, height: 440)
        static let legacyDefaultContentSize = CGSize(width: 420, height: 520)
    }

    private enum PinnedCorner: String {
        case topLeft
        case topRight
    }

    convenience init<Content: View>(rootView: Content) {
        let hostingView = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: .init(origin: .zero, size: WindowDefaults.defaultContentSize),
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

        let defaultFrameSize = window.frameRect(
            forContentRect: .init(origin: .zero, size: WindowDefaults.defaultContentSize)
        ).size

        let migratedFrame = savedFrame.map { frame in
            let contentSize = window.contentRect(forFrameRect: frame).size
            let isLegacyDefault =
                abs(contentSize.width - WindowDefaults.legacyDefaultContentSize.width) < 0.5 &&
                abs(contentSize.height - WindowDefaults.legacyDefaultContentSize.height) < 0.5
            guard isLegacyDefault else { return frame }
            return .init(origin: frame.origin, size: defaultFrameSize)
        }

        let size = migratedFrame?.size ?? defaultFrameSize

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
