import SwiftUI

enum AppTab: CaseIterable, Hashable {
    case today
    case words
    case settings

    var title: String {
        switch self {
        case .today: "Hôm nay"
        case .words: "Từ vựng"
        case .settings: "Cài đặt"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max.fill"
        case .words: "book.closed.fill"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct RootView: View {
    @State private var selection: AppTab = DebugLaunchOptions.initialTab ?? .today

    var body: some View {
        Group {
            switch selection {
            case .today: TodayView()
            case .words: WordListView()
            case .settings: SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MoonTabBar(selection: $selection)
        }
    }
}

/// Custom tab bar following the kit: the selected tab's icon sits in a rounded square.
struct MoonTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = selection == tab
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(isSelected ? Theme.onAccent : Theme.textSecondary)
                            .frame(width: Theme.Metrics.tabIndicatorSize, height: Theme.Metrics.tabIndicatorSize)
                            .background {
                                RoundedRectangle(cornerRadius: Theme.Metrics.tabIndicatorRadius, style: .continuous)
                                    .fill(isSelected ? Theme.accentStrong : Color.clear)
                            }
                        Text(tab.title)
                            .font(Theme.Typography.tabLabel)
                            .foregroundStyle(isSelected ? Theme.accentText : Theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: Theme.Metrics.minimumTapTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityShowsLargeContentViewer {
                    Label(tab.title, systemImage: tab.systemImage)
                }
            }
        }
        // Like the system tab bar: cap the label size and offer the Large Content Viewer instead.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.horizontal, Theme.Metrics.gutter)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(
            Theme.tabBar.shadow(.drop(color: Theme.tabBarShadow, radius: 17, x: 2, y: -5)),
            ignoresSafeAreaEdges: .bottom
        )
    }
}
