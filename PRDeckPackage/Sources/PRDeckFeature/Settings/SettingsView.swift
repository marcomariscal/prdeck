import SwiftUI

public struct SettingsView: View {
    @AppStorage(PRDeckDefaultsKey.themePalette) private var themePaletteRaw = PRDeckPalette.appleBetter.rawValue

    public init() {}

    public var body: some View {
        Form {
            Picker("Theme", selection: $themePaletteRaw) {
                ForEach(PRDeckPalette.allCases) { palette in
                    Text(palette.displayName)
                        .tag(palette.rawValue)
                }
            }
            .prdeckInteractiveCursor()
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 360)
    }
}
