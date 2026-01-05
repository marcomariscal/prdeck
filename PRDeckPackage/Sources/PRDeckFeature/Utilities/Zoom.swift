import SwiftUI

private struct PRDeckZoomScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var prdeckZoomScale: CGFloat {
        get { self[PRDeckZoomScaleKey.self] }
        set { self[PRDeckZoomScaleKey.self] = newValue }
    }
}

