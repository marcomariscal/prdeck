import PRDeckFeature
import SwiftUI

struct TitlebarTitleView: View {
    @AppStorage(PRDeckDefaultsKey.themePalette) private var themePaletteRaw = PRDeckPalette.appleBetter.rawValue

    private var theme: PRDeckTheme {
        PRDeckTheme(palette: PRDeckPalette(rawValue: themePaletteRaw) ?? .appleBetter)
    }

    var body: some View {
        Text("PRDeck")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(theme.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}
