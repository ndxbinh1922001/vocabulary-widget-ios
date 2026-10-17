import SwiftUI
import UIKit
import VocabularyKit

/// Visual language of the app and widgets, adapted from the Figma kit "Meditation app UI (Silent Moon)".
/// Colors come from `DesignTokens` so their contrast is unit-tested in VocabularyKit.
enum Theme {
    // MARK: Colors

    static let accent = Color(token: DesignTokens.accent)
    static let accentStrong = Color(token: DesignTokens.accentStrong)
    static let onAccent = Color(token: DesignTokens.onAccent)
    static let accentText = Color(token: DesignTokens.accentText)
    static let background = Color(token: DesignTokens.background)
    static let tabBar = Color(token: DesignTokens.tabBar)
    static let field = Color(token: DesignTokens.field)
    static let pill = Color(token: DesignTokens.pill)
    static let pillText = Color(token: DesignTokens.pillText)
    static let darkCard = Color(token: DesignTokens.darkCard)
    static let chip = Color(token: DesignTokens.chip)
    static let blob = Color(token: DesignTokens.blob)
    static let textPrimary = Color(token: DesignTokens.textPrimary)
    static let textSecondary = Color(token: DesignTokens.textSecondary)
    static let cardCaption = Color(token: DesignTokens.cardCaption)
    static let error = Color(token: DesignTokens.error)
    static let success = Color(token: DesignTokens.success)

    /// Widget background on the Home Screen: periwinkle by day, navy (kit "Sleep") by night.
    static let widgetBackground = Color(
        token: ThemeColor(light: 0x5F68D9, dark: 0x03174D)
    )

    /// Tab bar shadow: barely visible on white, the kit's deep navy glow in dark mode.
    static let tabBarShadow = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 3 / 255, green: 19 / 255, blue: 64 / 255, alpha: 0.95)
                : UIColor(white: 0, alpha: 0.06)
        }
    )

    // MARK: Typography (Helvetica Neue, scaled with Dynamic Type)

    enum Typography {
        static let screenTitle = font("HelveticaNeue-Bold", 28, .title)
        static let settingsTitle = font("HelveticaNeue-Bold", 24, .title2)
        static let wordHero = font("HelveticaNeue-Bold", 34, .largeTitle)
        static let greetingSubtitle = font("HelveticaNeue-Light", 20, .title3)
        static let body = font("HelveticaNeue-Light", 16, .body)
        static let bodyItalic = font("HelveticaNeue-LightItalic", 16, .body)
        static let cardTitle = font("HelveticaNeue-Bold", 18, .headline)
        static let rowTitle = font("HelveticaNeue-Medium", 16, .body)
        static let chipLabel = font("HelveticaNeue-Medium", 16, .callout)
        static let tabLabel = font("HelveticaNeue-Medium", 14, .footnote)
        static let button = font("HelveticaNeue-Medium", 14, .subheadline)
        static let caption = font("HelveticaNeue-Medium", 11, .caption2)
        static let brand = font("HelveticaNeue-Bold", 16, .headline)

        /// Kit letter spacing: 5% of the point size for uppercase buttons and captions.
        static let buttonTracking: CGFloat = 0.7
        static let captionTracking: CGFloat = 0.55
        /// Kit body line height is 1.45 × 16pt.
        static let bodyLineSpacing: CGFloat = 7

        static func font(_ name: String, _ size: CGFloat, _ style: Font.TextStyle) -> Font {
            .custom(name, size: size, relativeTo: style)
        }
    }

    // MARK: Metrics (points, from the kit's 414pt frames)

    enum Metrics {
        static let gutter: CGFloat = 20
        static let cardSpacing: CGFloat = 20
        static let cardRadius: CGFloat = 10
        static let primaryButtonHeight: CGFloat = 63
        static let fieldHeight: CGFloat = 63
        static let fieldRadius: CGFloat = 15
        static let pillSize = CGSize(width: 70, height: 35)
        static let chipSize: CGFloat = 65
        static let chipRadius: CGFloat = 25
        static let tabIndicatorSize: CGFloat = 46
        static let tabIndicatorRadius: CGFloat = 18
        static let minimumTapTarget: CGFloat = 44
    }
}

extension Color {
    /// A dynamic color that follows the current light/dark appearance.
    nonisolated init(token: ThemeColor) {
        self.init(
            uiColor: UIColor { traits in
                UIColor(rgb: traits.userInterfaceStyle == .dark ? token.dark : token.light)
            }
        )
    }
}

extension UIColor {
    nonisolated convenience init(rgb: RGBColor) {
        self.init(
            red: CGFloat(rgb.red) / 255,
            green: CGFloat(rgb.green) / 255,
            blue: CGFloat(rgb.blue) / 255,
            alpha: 1
        )
    }
}

extension View {
    /// Caption style from the kit (Medium 11, tracking 0.55), uppercased by default.
    /// Pass `uppercase: false` for text that must keep its case, such as IPA (/ɪ/ is not /I/).
    func captionStyle(uppercase: Bool = true) -> some View {
        font(Theme.Typography.caption)
            .tracking(Theme.Typography.captionTracking)
            .textCase(uppercase ? .uppercase : nil)
    }
}
