import SwiftUI
import VocabularyKit
import WidgetKit

struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            InlineWordView(word: entry.word)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            RectangularWordView(word: entry.word)
                .containerBackground(for: .widget) { Color.clear }
        default:
            SmallWordView(word: entry.word)
                .containerBackground(for: .widget) { Theme.widgetBackground }
        }
    }
}

/// One line above the Lock Screen clock.
struct InlineWordView: View {
    let word: VocabularyWord?

    var body: some View {
        if let word {
            Text("\(word.term) · \(word.meaningVi)")
        } else {
            Text("Thêm từ trong app Từ Vựng")
        }
    }
}

/// Below the Lock Screen clock. Always rendered monochrome, so hierarchy comes from type only.
struct RectangularWordView: View {
    let word: VocabularyWord?

    var body: some View {
        Group {
            if let word {
                VStack(alignment: .leading, spacing: 1) {
                    Text(word.term)
                        .font(Theme.Typography.font("HelveticaNeue-Bold", 17, .headline))
                        .widgetAccentable()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let ipa = word.ipa, !ipa.isEmpty {
                        Text(ipa)
                            .font(Theme.Typography.font("HelveticaNeue", 12, .caption))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(word.meaningVi)
                        .font(Theme.Typography.font("HelveticaNeue-Medium", 14, .subheadline))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chưa có từ")
                        .font(Theme.Typography.font("HelveticaNeue-Bold", 15, .headline))
                    Text("Mở app để thêm từ")
                        .font(Theme.Typography.font("HelveticaNeue", 13, .subheadline))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// StandBy and Home Screen. Brand colors only when the system shows our background in full color;
/// StandBy hides the background (and tints everything red at night), so fall back to system styles.
struct SmallWordView: View {
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    @Environment(\.widgetRenderingMode) private var renderingMode
    let word: VocabularyWord?

    private var usesBrandColors: Bool {
        showsBackground && renderingMode == .fullColor
    }

    var body: some View {
        let primary: Color = usesBrandColors ? Theme.onAccent : .primary
        let secondary: Color = usesBrandColors ? Theme.onAccent : .secondary

        Group {
            if let word {
                WordTextStack(word: word, size: .widget, primary: primary, secondary: secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Chưa có từ")
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(primary)
                    Text("Mở app Từ Vựng để thêm từ hoặc đổi nguồn từ.")
                        .font(Theme.Typography.font("HelveticaNeue-Medium", 13, .footnote))
                        .foregroundStyle(secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview("Small", as: .systemSmall) {
    VocabularyWidget()
} timeline: {
    WordEntry.sample
    WordEntry(
        date: Date(),
        word: VocabularyWord(
            id: "long", term: "uncharacteristically", ipa: "/ʌnˌkærəktəˈrɪstɪkli/", partOfSpeech: "adverb",
            meaningVi: "một cách khác thường, không đúng tính cách", source: .user)
    )
    WordEntry(date: Date(), word: nil)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    VocabularyWidget()
} timeline: {
    WordEntry.sample
    WordEntry(date: Date(), word: nil)
}

#Preview("Inline", as: .accessoryInline) {
    VocabularyWidget()
} timeline: {
    WordEntry.sample
}
