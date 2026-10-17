import SwiftUI

/// Step-by-step guide for adding the widget to the Lock Screen and StandBy (iOS 17+).
struct WidgetGuideView: View {
    @Environment(\.dismiss) private var dismiss

    private let lockScreenSteps = [
        "Mở khóa iPhone, rồi chạm và giữ Màn hình khóa.",
        "Chọn “Tùy chỉnh”, sau đó chọn “Màn hình khóa”.",
        "Chạm vào ô widget bên dưới đồng hồ (hoặc dòng phía trên đồng hồ).",
        "Tìm “Từ Vựng” và chọn kiểu widget bạn thích.",
    ]

    private let standBySteps = [
        "Vào Cài đặt › StandBy và bật StandBy.",
        "Cắm sạc iPhone, khóa máy và đặt nằm ngang.",
        "Vuốt đến màn hình widget, chạm và giữ, rồi nhấn “+”.",
        "Chọn “Từ Vựng” để thêm widget.",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text("Thêm widget")
                        .font(Theme.Typography.screenTitle)
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    GuideSection(title: "Màn hình khóa", systemImage: "lock.iphone", steps: lockScreenSteps)
                    GuideSection(title: "StandBy", systemImage: "iphone.landscape", steps: standBySteps)

                    Text("Từ trên widget tự đổi theo chu kỳ trong Cài đặt, không cần mở app.")
                        .font(Theme.Typography.body)
                        .lineSpacing(Theme.Typography.bodyLineSpacing)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(Theme.Metrics.gutter)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                        .foregroundStyle(Theme.accentText)
                }
            }
        }
    }
}

private struct GuideSection: View {
    let title: String
    let systemImage: String
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("\(index + 1)")
                        .font(Theme.Typography.button)
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Theme.accentStrong))
                        .accessibilityHidden(true)
                    Text(step)
                        .font(Theme.Typography.body)
                        .lineSpacing(Theme.Typography.bodyLineSpacing)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Bước \(index + 1): \(step)")
            }
        }
    }
}
