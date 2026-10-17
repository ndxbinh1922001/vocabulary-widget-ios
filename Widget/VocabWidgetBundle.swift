import SwiftUI
import WidgetKit

@main
struct VocabWidgetBundle: WidgetBundle {
    var body: some Widget {
        VocabularyWidget()
    }
}

/// One widget for the Lock Screen (inline, rectangular) and StandBy / Home Screen (small).
struct VocabularyWidget: Widget {
    static let kind = "VocabularyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: Provider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName("Từ vựng")
        .description("Một từ tiếng Anh mới trên Màn hình khóa và StandBy.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular, .systemSmall])
    }
}
