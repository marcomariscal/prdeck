import AppKit
import SwiftUI

// MARK: - Unified Layout System

/// Semantic spacing constants for consistent alignment across all views.
/// All values are base values that get multiplied by `zoomScale`.
public enum PRDeckLayout {
    // MARK: Horizontal Spacing

    /// Outer inset for the scrollable list wrapper (10pt base)
    public static let listInset: CGFloat = 10

    /// Internal horizontal padding within row content (20pt base)
    public static let contentPadding: CGFloat = 20

    /// Reserved space for scroll indicator appearance (6pt base)
    public static let scrollGutter: CGFloat = 6

    /// Fixed width for the status/action column on the right (40pt base)
    public static let statusColumnWidth: CGFloat = 40

    // MARK: Vertical Spacing

    /// Minimum row height (50pt base)
    public static let rowHeight: CGFloat = 50

    /// Vertical spacing between rows (6pt base)
    public static let rowSpacing: CGFloat = 6

    /// Vertical padding around sections/header (8pt base)
    public static let sectionPadding: CGFloat = 8

    /// Internal vertical padding within rows (10pt base)
    public static let rowVerticalPadding: CGFloat = 10

    // MARK: Computed Composites

    /// Total leading padding for content alignment: listInset + contentPadding
    public static let contentLeading: CGFloat = listInset + contentPadding

    /// Total trailing padding for content alignment: listInset + contentPadding + scrollGutter
    public static let contentTrailing: CGFloat = listInset + contentPadding + scrollGutter

    /// Returns the legacy scroller width if legacy style is active, otherwise 0
    @MainActor
    public static var scrollerWidth: CGFloat {
        guard NSScroller.preferredScrollerStyle == .legacy else { return 0 }
        return NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    }
}

public enum PRDeckPalette: String, CaseIterable, Identifiable, Sendable {
    // Terminal-inspired
    case monokai
    case dracula
    case solarizedDark
    case gruvboxDark
    case nord
    case oneDark
    case tokyoNight
    case catppuccinMocha

    // Built-in
    case graphiteIndigo
    case nearBlackCyan
    case slatePurple
    case appleBetter

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .monokai: "Monokai"
        case .dracula: "Dracula"
        case .solarizedDark: "Solarized (Dark)"
        case .gruvboxDark: "Gruvbox (Dark)"
        case .nord: "Nord"
        case .oneDark: "One Dark"
        case .tokyoNight: "Tokyo Night"
        case .catppuccinMocha: "Catppuccin (Mocha)"
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

    fileprivate init(palette: PRDeckPalette, colors: ThemeBuilder.Colors) {
        self.palette = palette
        bg = colors.bg
        surface = colors.surface
        surface2 = colors.surface2
        elevated = colors.elevated
        divider = colors.divider
        border = colors.border

        textPrimary = colors.textPrimary
        textSecondary = colors.textSecondary
        textTertiary = colors.textTertiary
        textDisabled = colors.textDisabled

        rowHover = colors.rowHover
        rowSelected = colors.rowSelected
        focusRing = colors.focusRing
        shadow = colors.shadow

        accent = colors.accent
        accentHover = colors.accentHover
        accentPressed = colors.accentPressed

        success = colors.success
        warning = colors.warning
        danger = colors.danger
        info = colors.info
        muted = colors.muted
    }

    public init(palette: PRDeckPalette) {
        switch palette {
        case .monokai:
            self = ThemeBuilder.terminalTheme(
                palette: palette,
                background: "#272822",
                foreground: "#F8F8F2",
                accent: "#66D9EF",
                success: "#A6E22E",
                warning: "#FD971F",
                danger: "#F92672",
                info: "#AE81FF",
                muted: "#75715E"
            )
            return

        case .dracula:
            self = ThemeBuilder.terminalTheme(
                palette: palette,
                background: "#282A36",
                foreground: "#F8F8F2",
                accent: "#FF79C6",
                success: "#50FA7B",
                warning: "#F1FA8C",
                danger: "#FF5555",
                info: "#8BE9FD",
                muted: "#6272A4"
            )
            return

        case .solarizedDark:
            self = ThemeBuilder.terminalTheme(
                palette: palette,
                background: "#002B36",
                foreground: "#EEE8D5",
                accent: "#268BD2",
                success: "#859900",
                warning: "#B58900",
                danger: "#DC322F",
                info: "#2AA198",
                muted: "#586E75"
            )
            return

        case .gruvboxDark:
            self = ThemeBuilder.terminalTheme(
                palette: palette,
                background: "#282828",
                foreground: "#EBDBB2",
                accent: "#83A598",
                success: "#B8BB26",
                warning: "#FABD2F",
                danger: "#FB4934",
                info: "#8EC07C",
                muted: "#7C6F64"
            )
            return

        case .nord:
            self = ThemeBuilder.terminalTheme(
                palette: palette,
                background: "#2E3440",
                foreground: "#ECEFF4",
                accent: "#88C0D0",
                success: "#A3BE8C",
                warning: "#EBCB8B",
                danger: "#BF616A",
                info: "#81A1C1",
                muted: "#4C566A"
            )
            return

        case .oneDark:
            self = ThemeBuilder.terminalTheme(
                palette: palette,
                background: "#282C34",
                foreground: "#DCDFE4",
                accent: "#61AFEF",
                success: "#98C379",
                warning: "#E5C07B",
                danger: "#E06C75",
                info: "#56B6C2",
                muted: "#5C6370"
            )
            return

        case .tokyoNight:
            self = ThemeBuilder.terminalTheme(
                palette: palette,
                background: "#1A1B26",
                foreground: "#C0CAF5",
                accent: "#7AA2F7",
                success: "#9ECE6A",
                warning: "#E0AF68",
                danger: "#F7768E",
                info: "#7DCFFF",
                muted: "#565F89"
            )
            return

        case .catppuccinMocha:
            self = ThemeBuilder.terminalTheme(
                palette: palette,
                background: "#1E1E2E",
                foreground: "#CDD6F4",
                accent: "#CBA6F7",
                success: "#A6E3A1",
                warning: "#F9E2AF",
                danger: "#F38BA8",
                info: "#89DCEB",
                muted: "#6C7086"
            )
            return

        case .graphiteIndigo:
            self.palette = palette
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
            self.palette = palette
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
            self.palette = palette
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
            self.palette = palette
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

private enum ThemeBuilder {
    struct Colors: Sendable {
        let bg: Color
        let surface: Color
        let surface2: Color
        let elevated: Color
        let divider: Color
        let border: Color

        let textPrimary: Color
        let textSecondary: Color
        let textTertiary: Color
        let textDisabled: Color

        let rowHover: Color
        let rowSelected: Color
        let focusRing: Color
        let shadow: Color

        let accent: Color
        let accentHover: Color
        let accentPressed: Color

        let success: Color
        let warning: Color
        let danger: Color
        let info: Color
        let muted: Color
    }

    static func terminal(
        background: String,
        foreground: String,
        accent: String,
        success: String,
        warning: String,
        danger: String,
        info: String,
        muted: String
    ) -> Colors {
        let bg = RGBA(hex: background)
        let fg = RGBA(hex: foreground)
        let accent = RGBA(hex: accent)
        let muted = RGBA(hex: muted)

        // High-contrast UI style: keep the terminal's vibe, but punch up separation + readability.
        let tintedBase = bg.mix(with: accent, t: 0.12)
        let surface = tintedBase.mix(with: .white, t: 0.05)
        let surface2 = tintedBase.mix(with: .white, t: 0.16)
        let elevated = tintedBase.mix(with: .white, t: 0.28)

        let divider = fg.withAlpha(0.18)
        let border = fg.withAlpha(0.28)

        let textPrimary = fg.mix(with: .white, t: 0.10)
        let textSecondary = fg.mix(with: bg, t: 0.08)
        let textTertiary = fg.mix(with: bg, t: 0.18)
        let textDisabled = fg.mix(with: bg, t: 0.40)

        let rowHover = accent.withAlpha(0.14)
        let rowSelected = accent.withAlpha(0.44)
        let focusRing = accent
        let shadow = RGBA.black.withAlpha(0.80)

        let accentHover = accent.mix(with: .white, t: 0.34)
        let accentPressed = accent.mix(with: bg, t: 0.18)

        return Colors(
            bg: bg.color,
            surface: surface.color,
            surface2: surface2.color,
            elevated: elevated.color,
            divider: divider.color,
            border: border.color,
            textPrimary: textPrimary.color,
            textSecondary: textSecondary.color,
            textTertiary: textTertiary.color,
            textDisabled: textDisabled.color,
            rowHover: rowHover.color,
            rowSelected: rowSelected.color,
            focusRing: focusRing.color,
            shadow: shadow.color,
            accent: accent.color,
            accentHover: accentHover.color,
            accentPressed: accentPressed.color,
            success: RGBA(hex: success).color,
            warning: RGBA(hex: warning).color,
            danger: RGBA(hex: danger).color,
            info: RGBA(hex: info).color,
            muted: muted.color
        )
    }

    static func terminalTheme(
        palette: PRDeckPalette,
        background: String,
        foreground: String,
        accent: String,
        success: String,
        warning: String,
        danger: String,
        info: String,
        muted: String
    ) -> PRDeckTheme {
        PRDeckTheme(
            palette: palette,
            colors: terminal(
                background: background,
                foreground: foreground,
                accent: accent,
                success: success,
                warning: warning,
                danger: danger,
                info: info,
                muted: muted
            )
        )
    }
}

private struct RGBA: Sendable {
    static let white = RGBA(r: 1, g: 1, b: 1, a: 1)
    static let black = RGBA(r: 0, g: 0, b: 0, a: 1)

    let r: Double
    let g: Double
    let b: Double
    let a: Double

    init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

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
                r: component(0),
                g: component(2),
                b: component(4),
                a: 1
            )
            return
        }

        if cleaned.count == 8 {
            self.init(
                r: component(0),
                g: component(2),
                b: component(4),
                a: component(6)
            )
            return
        }

        self.init(r: 0, g: 0, b: 0, a: 0)
    }

    func withAlpha(_ alpha: Double) -> RGBA {
        RGBA(r: r, g: g, b: b, a: alpha)
    }

    func mix(with other: RGBA, t: Double) -> RGBA {
        let clamped = max(0, min(1, t))
        return RGBA(
            r: r + (other.r - r) * clamped,
            g: g + (other.g - g) * clamped,
            b: b + (other.b - b) * clamped,
            a: a + (other.a - a) * clamped
        )
    }

    var color: Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
