import SwiftUI

enum PRDeckLayoutPreferenceKey {
    struct StatusIconCenterX: PreferenceKey {
        static var defaultValue: CGFloat? { nil }

        static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
            guard let next = nextValue() else { return }
            value = max(value ?? next, next)
        }
    }

    struct HeaderFilterIconCenterX: PreferenceKey {
        static var defaultValue: CGFloat? { nil }

        static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
            guard let next = nextValue() else { return }
            value = next
        }
    }
}
