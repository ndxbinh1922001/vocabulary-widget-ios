import Foundation

/// An sRGB color with 8-bit components. Free of UI frameworks so contrast can be tested on macOS.
public struct RGBColor: Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    /// Creates a color from `0xRRGGBB`.
    public init(hex: UInt32) {
        red = UInt8((hex >> 16) & 0xFF)
        green = UInt8((hex >> 8) & 0xFF)
        blue = UInt8(hex & 0xFF)
    }

    /// WCAG 2.x relative luminance in `0...1`.
    public var relativeLuminance: Double {
        0.2126 * Self.linearize(red) + 0.7152 * Self.linearize(green) + 0.0722 * Self.linearize(blue)
    }

    /// WCAG contrast ratio between two colors, in `1...21`.
    public static func contrastRatio(_ first: RGBColor, _ second: RGBColor) -> Double {
        let lighter = max(first.relativeLuminance, second.relativeLuminance)
        let darker = min(first.relativeLuminance, second.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func linearize(_ component: UInt8) -> Double {
        let value = Double(component) / 255
        return value <= 0.040_45 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
}

/// A color with separate light and dark appearance values.
public struct ThemeColor: Hashable, Sendable {
    public let light: RGBColor
    public let dark: RGBColor

    public init(light: UInt32, dark: UInt32) {
        self.light = RGBColor(hex: light)
        self.dark = RGBColor(hex: dark)
    }

    public init(_ both: UInt32) {
        self.init(light: both, dark: both)
    }
}

/// A text or icon color pair that must meet a WCAG contrast threshold in both appearances.
public struct ContrastRequirement: Sendable {
    public let name: String
    public let foreground: ThemeColor
    public let background: ThemeColor
    public let minimumRatio: Double
}

/// Color tokens taken from the Figma kit "Meditation app UI (Silent Moon)".
///
/// Light appearance follows the kit's Home/Meditate screens, dark appearance its Sleep screens.
/// Values marked *adjusted* deviate from the kit so text reaches WCAG AA (4.5:1) and icons 3:1.
public enum DesignTokens {
    // MARK: Brand

    /// Kit periwinkle `#8E97FD`. Decorative surfaces only: white text on it reaches just 2.6:1.
    public static let accent = ThemeColor(0x8E97FD)
    /// *Adjusted*: deeper periwinkle for filled cards, buttons, selected chips and the tab indicator.
    public static let accentStrong = ThemeColor(0x5F68D9)
    /// Text and icons on `accentStrong`, `darkCard` and chips.
    public static let onAccent = ThemeColor(0xFFFFFF)
    /// Accent-colored text: deeper periwinkle on white, kit periwinkle on navy.
    public static let accentText = ThemeColor(light: 0x5F68D9, dark: 0x8E97FD)

    // MARK: Surfaces

    /// Screen background: white (kit Home) / navy `#03174D` (kit Sleep).
    public static let background = ThemeColor(light: 0xFFFFFF, dark: 0x03174D)
    /// Tab bar background, same as the screen in the kit.
    public static let tabBar = ThemeColor(light: 0xFFFFFF, dark: 0x03174D)
    /// Input fields and the search bar (kit `#F2F3F7`; dark value chosen to keep the navy family).
    public static let field = ThemeColor(light: 0xF2F3F7, dark: 0x172B66)
    /// Secondary pill buttons (kit `#EBEAEC` / Sleep chip `#586894`).
    public static let pill = ThemeColor(light: 0xEBEAEC, dark: 0x586894)
    /// Dark feature card (kit "Daily Thought" `#333242`).
    public static let darkCard = ThemeColor(0x333242)
    /// Unselected filter chips. *Adjusted* light value (kit `#A0A3B1` gives white icons only 2.5:1).
    public static let chip = ThemeColor(light: 0x6B6E7C, dark: 0x586894)
    /// Soft decorative background blobs. Approximate values sampled from the kit's screenshots.
    public static let blob = ThemeColor(light: 0xFFF1E3, dark: 0x0E2A6E)

    // MARK: Text

    public static let textPrimary = ThemeColor(light: 0x3F414E, dark: 0xE6E7F2)
    /// *Adjusted* light value (kit `#A1A4B2` reaches only 2.5:1 on white).
    public static let textSecondary = ThemeColor(light: 0x6B6E7C, dark: 0x98A1BD)
    /// Text on `pill`.
    public static let pillText = ThemeColor(light: 0x3F414E, dark: 0xFFFFFF)
    /// Small uppercase captions on `darkCard` (kit `#EBEAEC`).
    public static let cardCaption = ThemeColor(0xEBEAEC)

    // MARK: Status (not in the kit)

    public static let error = ThemeColor(light: 0xC62828, dark: 0xFF8A80)
    public static let success = ThemeColor(light: 0x2E7D32, dark: 0x81C784)

    /// Every foreground/background pair the UI uses, with its minimum ratio
    /// (4.5 for text, 3.0 for icons and large text).
    public static let contrastRequirements: [ContrastRequirement] = [
        .init(name: "primary text on background", foreground: textPrimary, background: background, minimumRatio: 4.5),
        .init(
            name: "secondary text on background", foreground: textSecondary, background: background, minimumRatio: 4.5),
        .init(name: "primary text on field", foreground: textPrimary, background: field, minimumRatio: 4.5),
        .init(name: "placeholder text on field", foreground: textSecondary, background: field, minimumRatio: 4.5),
        .init(name: "text on accent card", foreground: onAccent, background: accentStrong, minimumRatio: 4.5),
        .init(name: "text on dark card", foreground: onAccent, background: darkCard, minimumRatio: 4.5),
        .init(name: "caption on dark card", foreground: cardCaption, background: darkCard, minimumRatio: 4.5),
        .init(name: "accent text on background", foreground: accentText, background: background, minimumRatio: 4.5),
        .init(name: "accent text on tab bar", foreground: accentText, background: tabBar, minimumRatio: 4.5),
        .init(name: "secondary text on tab bar", foreground: textSecondary, background: tabBar, minimumRatio: 4.5),
        .init(name: "pill text on pill", foreground: pillText, background: pill, minimumRatio: 4.5),
        .init(name: "icon on chip", foreground: onAccent, background: chip, minimumRatio: 3.0),
        .init(name: "icon on selected chip", foreground: onAccent, background: accentStrong, minimumRatio: 3.0),
        .init(name: "error text on background", foreground: error, background: background, minimumRatio: 4.5),
        .init(name: "error text on field", foreground: error, background: field, minimumRatio: 4.5),
        .init(name: "success icon on field", foreground: success, background: field, minimumRatio: 3.0),
    ]
}
