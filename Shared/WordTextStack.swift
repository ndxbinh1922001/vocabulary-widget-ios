import SwiftUI
import VocabularyKit

/// The word, its caption, meaning and example in the kit's type hierarchy.
/// Used by the app's word card and by the widget, so both read the same way.
struct WordTextStack: View {
    enum Size {
        /// Large card in the app.
        case hero
        /// Upcoming-word card in the app.
        case compact
        /// `systemSmall` widget (Home Screen and StandBy).
        case widget
    }

    let word: VocabularyWord
    var size: Size = .hero
    /// Foreground for the term and meaning; secondary lines use a softer opacity-free variant.
    var primary: Color = Theme.textPrimary
    var secondary: Color = Theme.textSecondary

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            if let caption = word.caption {
                // `caption` already uppercases the part of speech; the IPA half must keep its case.
                Text(caption)
                    .captionStyle(uppercase: false)
                    .foregroundStyle(secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(word.term)
                .font(termFont)
                .foregroundStyle(primary)
                .lineLimit(size == .hero ? 3 : 1)
                .minimumScaleFactor(size == .hero ? 0.6 : 0.5)
                .accessibilityAddTraits(.isHeader)

            Text(word.meaningVi)
                .font(meaningFont)
                .foregroundStyle(primary)
                .lineLimit(size == .hero ? nil : 2)
                .minimumScaleFactor(size == .widget ? 0.75 : 1)

            if size == .hero, let example = word.example {
                Text(example)
                    .font(Theme.Typography.bodyItalic)
                    .lineSpacing(Theme.Typography.bodyLineSpacing)
                    .foregroundStyle(primary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var spacing: CGFloat {
        switch size {
        case .hero: 10
        case .compact: 6
        case .widget: 4
        }
    }

    private var termFont: Font {
        switch size {
        case .hero: Theme.Typography.wordHero
        case .compact: Theme.Typography.cardTitle
        case .widget: Theme.Typography.font("HelveticaNeue-Bold", 22, .title2)
        }
    }

    private var meaningFont: Font {
        switch size {
        case .hero: Theme.Typography.font("HelveticaNeue-Medium", 18, .headline)
        case .compact: Theme.Typography.body
        case .widget: Theme.Typography.font("HelveticaNeue-Medium", 14, .subheadline)
        }
    }
}
