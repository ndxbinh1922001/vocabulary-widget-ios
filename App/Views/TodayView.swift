import SwiftUI
import VocabularyKit

/// "Hôm nay" tab: the word currently on the Lock Screen and the next ones (kit Home layout).
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var showsGuide = DebugLaunchOptions.initialSheet == .guide

    var body: some View {
        TimelineView(RotationSchedule(rotation: model.rotation)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    BrandHeader()
                    NoticeList(notices: model.notices)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(greeting(at: context.date))
                            .font(Theme.Typography.screenTitle)
                            .foregroundStyle(Theme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("Từ đang hiện trên màn hình khóa")
                            .font(Theme.Typography.greetingSubtitle)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    if let word = model.currentWord(at: context.date) {
                        HeroWordCard(word: word)
                    } else {
                        EmptyRotationCard()
                    }

                    GuideCard { showsGuide = true }

                    UpcomingSection(
                        items: model.upcomingWords(after: context.date, count: 6),
                        showsDay: model.settings.interval == .daily,
                        showsSeconds: (model.settings.interval.durationSeconds ?? .max) < 60,
                        timeZone: model.timeZone
                    )
                }
                .padding(.horizontal, Theme.Metrics.gutter)
                .padding(.vertical, 20)
            }
            .background(BlobBackground())
        }
        .sheet(isPresented: $showsGuide) {
            WidgetGuideView()
        }
    }

    private func greeting(at date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = model.timeZone
        switch calendar.component(.hour, from: date) {
        case 5..<11: return "Chào buổi sáng"
        case 11..<13: return "Chào buổi trưa"
        case 13..<18: return "Chào buổi chiều"
        default: return "Chào buổi tối"
        }
    }
}

/// Large periwinkle card with the current word (kit course card).
struct HeroWordCard: View {
    let word: VocabularyWord

    var body: some View {
        WordTextStack(word: word, size: .hero, primary: Theme.onAccent, secondary: Theme.onAccent)
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: Theme.Metrics.cardRadius, style: .continuous)
                    .fill(Theme.accentStrong)
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(Theme.onAccent.opacity(0.08))
                            .frame(width: 160, height: 160)
                            .offset(x: 50, y: -60)
                            .accessibilityHidden(true)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cardRadius, style: .continuous))
            }
    }
}

private struct EmptyRotationCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chưa có từ để hiển thị")
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Theme.textPrimary)
            Text("Thêm từ ở tab Từ vựng hoặc chọn nguồn từ khác trong Cài đặt.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardRadius, style: .continuous).fill(Theme.field)
        )
    }
}

/// Dark card that opens the widget guide (kit "Daily Thought").
private struct GuideCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cách thêm widget")
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.onAccent)
                    Text("Màn hình khóa · StandBy")
                        .captionStyle()
                        .foregroundStyle(Theme.cardCaption)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.darkCard)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.onAccent))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.cardRadius, style: .continuous).fill(Theme.darkCard)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cách thêm widget vào Màn hình khóa và StandBy")
    }
}

/// Horizontal carousel of the next words (kit "Recommended for you").
private struct UpcomingSection: View {
    let items: [ScheduledWord]
    let showsDay: Bool
    let showsSeconds: Bool
    let timeZone: TimeZone

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sắp hiện")
                    .font(Theme.Typography.settingsTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Theme.Metrics.cardSpacing) {
                        ForEach(items, id: \.start) { item in
                            UpcomingCard(item: item, timeLabel: timeLabel(for: item.start))
                        }
                    }
                    .padding(.horizontal, Theme.Metrics.gutter)
                }
                .padding(.horizontal, -Theme.Metrics.gutter)
            }
        }
    }

    private func timeLabel(for date: Date) -> String {
        let style = Date.FormatStyle(timeZone: timeZone)
        if showsDay {
            return date.formatted(style.weekday(.wide).day().month())
        }
        let time = showsSeconds ? style.hour().minute().second() : style.hour().minute()
        return "Lúc \(date.formatted(time))"
    }
}

private struct UpcomingCard: View {
    let item: ScheduledWord
    let timeLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.word.term)
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Theme.onAccent)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(16)
                .frame(width: 162, height: 113, alignment: .bottomLeading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cardRadius, style: .continuous)
                        .fill(Theme.accentStrong)
                )
            Text(item.word.meaningVi)
                .font(Theme.Typography.rowTitle)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text(timeLabel)
                .captionStyle()
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(width: 162, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Re-renders the Today screen at every rotation boundary (down to the 20-second minimum) and at
/// least once a minute so the greeting stays current.
nonisolated struct RotationSchedule: TimelineSchedule {
    let rotation: WordRotation

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> UnfoldFirstSequence<Date> {
        sequence(first: startDate) { date in
            let nextMinute = Date(
                timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60 + 60)
            return min(rotation.nextBoundary(after: date), nextMinute)
        }
    }
}
