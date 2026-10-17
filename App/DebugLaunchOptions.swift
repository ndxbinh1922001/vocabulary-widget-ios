import Foundation

/// Debug-only launch arguments that open a given screen, so every screen can be captured on the
/// simulator without UI automation:
///
/// ```sh
/// xcrun simctl launch booted com.example.vocabwidget -VocabDebugTab words -VocabDebugSheet editor
/// ```
///
/// Release builds compile these to constant `nil`s.
enum DebugLaunchOptions {
    enum Sheet: String {
        case guide
        case editor
    }

    #if DEBUG
        static var initialTab: AppTab? {
            switch UserDefaults.standard.string(forKey: "VocabDebugTab") {
            case "today": .today
            case "words": .words
            case "settings": .settings
            default: nil
            }
        }

        static var initialSheet: Sheet? {
            UserDefaults.standard.string(forKey: "VocabDebugSheet").flatMap(Sheet.init(rawValue:))
        }
    #else
        static let initialTab: AppTab? = nil
        static let initialSheet: Sheet? = nil
    #endif
}
