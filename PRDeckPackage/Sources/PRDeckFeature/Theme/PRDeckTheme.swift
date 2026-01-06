import SwiftUI

public enum PRDeckPalette: String, CaseIterable, Identifiable, Sendable {
    case graphiteIndigo
    case nearBlackCyan
    case slatePurple
    case appleBetter

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .graphiteIndigo: "Graphite + Indigo"
        case .nearBlackCyan: "Near-black + Cyan"
        case .slatePurple: "Slate + Purple"
        case .appleBetter: "Apple (sharper)"
        }
    }
}

public struct PRDeckTheme: Sendable {
    public let palette: PRDeckPalette

    // Neutrals
    public let bg: Color
    public let surface: Color
    public let surface2: Color
    public let elevated: Color
    public let divider: Color
    public let border: Color

    // Text
    public let textPrimary: Color
    public let textSecondary: Color
    public let textTertiary: Color
    public let textDisabled: Color

    // Interactive
    public let rowHover: Color
    public let rowSelected: Color
    public let focusRing: Color
    public let shadow: Color

    // Accent
    public let accent: Color
    public let accentHover: Color
    public let accentPressed: Color

    // Semantic
    public let success: Color
    public let warning: Color
    public let danger: Color
    public let info: Color
    public let muted: Color

    public init(palette: PRDeckPalette) {
        self.palette = palette

        switch palette {
        case .graphiteIndigo:
            bg = Color(hex: "#0B0D10")
            surface = Color(hex: "#10141A")
            surface2 = Color(hex: "#141A22")
            elevated = Color(hex: "#1A2230")
            divider = Color(hex: "#FFFFFF14")
            border = Color(hex: "#FFFFFF1F")

            textPrimary = Color(hex: "#F4F7FF")
            textSecondary = Color(hex: "#B9C0CC")
            textTertiary = Color(hex: "#8B94A6")
            textDisabled = Color(hex: "#6A7282")

            rowHover = Color(hex: "#FFFFFF0F")
            rowSelected = Color(hex: "#6D7CFF22")
            focusRing = Color(hex: "#6D7CFF")
            shadow = Color(hex: "#00000066")

            accent = Color(hex: "#6D7CFF")
            accentHover = Color(hex: "#8290FF")
            accentPressed = Color(hex: "#5667FF")

            success = Color(hex: "#2EE59D")
            warning = Color(hex: "#F5C451")
            danger = Color(hex: "#FF5C7A")
            info = Color(hex: "#53A6FF")
            muted = Color(hex: "#667085")

        case .nearBlackCyan:
            bg = Color(hex: "#06080B")
            surface = Color(hex: "#0C1117")
            surface2 = Color(hex: "#0F1620")
            elevated = Color(hex: "#121C29")
            divider = Color(hex: "#FFFFFF12")
            border = Color(hex: "#FFFFFF1C")

            textPrimary = Color(hex: "#F2F8FF")
            textSecondary = Color(hex: "#A9B4C4")
            textTertiary = Color(hex: "#7E8CA3")
            textDisabled = Color(hex: "#5F6C83")

            rowHover = Color(hex: "#FFFFFF10")
            rowSelected = Color(hex: "#22D3EE1F")
            focusRing = Color(hex: "#22D3EE")
            shadow = Color(hex: "#00000080")

            accent = Color(hex: "#22D3EE")
            accentHover = Color(hex: "#5EE9FF")
            accentPressed = Color(hex: "#0FBFD9")

            success = Color(hex: "#34D399")
            warning = Color(hex: "#FBBF24")
            danger = Color(hex: "#FB7185")
            info = Color(hex: "#60A5FA")
            muted = Color(hex: "#64748B")

        case .slatePurple:
            bg = Color(hex: "#0A0C12")
            surface = Color(hex: "#0F1420")
            surface2 = Color(hex: "#131B2B")
            elevated = Color(hex: "#18223A")
            divider = Color(hex: "#FFFFFF12")
            border = Color(hex: "#FFFFFF1A")

            textPrimary = Color(hex: "#F5F3FF")
            textSecondary = Color(hex: "#C7C9D3")
            textTertiary = Color(hex: "#9AA1B2")
            textDisabled = Color(hex: "#737C90")

            rowHover = Color(hex: "#FFFFFF10")
            rowSelected = Color(hex: "#A78BFA22")
            focusRing = Color(hex: "#A78BFA")
            shadow = Color(hex: "#00000070")

            accent = Color(hex: "#A78BFA")
            accentHover = Color(hex: "#C4B5FD")
            accentPressed = Color(hex: "#8B5CF6")

            success = Color(hex: "#22C55E")
            warning = Color(hex: "#F59E0B")
            danger = Color(hex: "#F43F5E")
            info = Color(hex: "#38BDF8")
            muted = Color(hex: "#6B7280")

        case .appleBetter:
            bg = Color(hex: "#0F1115")
            surface = Color(hex: "#151922")
            surface2 = Color(hex: "#1A2030")
            elevated = Color(hex: "#1F2840")
            divider = Color(hex: "#FFFFFF10")
            border = Color(hex: "#FFFFFF18")

            textPrimary = Color(hex: "#F5F5F7")
            textSecondary = Color(hex: "#C6C7D0")
            textTertiary = Color(hex: "#9A9EAB")
            textDisabled = Color(hex: "#6E7380")

            rowHover = Color(hex: "#FFFFFF0D")
            rowSelected = Color(hex: "#0A84FF24")
            focusRing = Color(hex: "#0A84FF")
            shadow = Color(hex: "#00000066")

            accent = Color(hex: "#0A84FF")
            accentHover = Color(hex: "#409CFF")
            accentPressed = Color(hex: "#0071E3")

            success = Color(hex: "#30D158")
            warning = Color(hex: "#FFD60A")
            danger = Color(hex: "#FF453A")
            info = Color(hex: "#64D2FF")
            muted = Color(hex: "#7D8596")
        }
    }
}

@preconcurrency
private struct PRDeckThemeKey: EnvironmentKey {
    static let defaultValue = PRDeckTheme(palette: .appleBetter)
}

extension EnvironmentValues {
    var prdeckTheme: PRDeckTheme {
        get { self[PRDeckThemeKey.self] }
        set { self[PRDeckThemeKey.self] = newValue }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        func component(_ start: Int) -> Double {
            let s = cleaned.index(cleaned.startIndex, offsetBy: start)
            let e = cleaned.index(s, offsetBy: 2)
            let part = String(cleaned[s..<e])
            return Double(Int(part, radix: 16) ?? 0) / 255.0
        }

        if cleaned.count == 6 {
            self.init(
                red: component(0),
                green: component(2),
                blue: component(4),
                opacity: 1
            )
            return
        }

        if cleaned.count == 8 {
            self.init(
                red: component(0),
                green: component(2),
                blue: component(4),
                opacity: component(6)
            )
            return
        }

        self = .clear
    }
}
