import AppKit
import SwiftUI

private struct PRDeckInteractiveCursorModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    let cursor: NSCursor
    let disabledCursor: NSCursor

    func body(content: Content) -> some View {
        content.prdeckHoverCursor(isEnabled ? cursor : disabledCursor)
    }
}

extension View {
    func prdeckInteractiveCursor(
        _ cursor: NSCursor = .pointingHand,
        disabled disabledCursor: NSCursor = .operationNotAllowed
    ) -> some View {
        modifier(PRDeckInteractiveCursorModifier(cursor: cursor, disabledCursor: disabledCursor))
    }
}

