import SwiftUI
import VocabularyKit

/// "Cài đặt" tab: rotation interval and word source (kit Reminders layout). Changes apply immediately.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var errorMessage: String?
    @State private var customAmount = ""
    @State private var customUnit: RotationInterval.TimeUnit = .minutes

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cài đặt")
                        .font(Theme.Typography.settingsTitle)
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Chọn tần suất đổi từ và những từ sẽ xuất hiện trên widget.")
                        .font(Theme.Typography.body)
                        .lineSpacing(Theme.Typography.bodyLineSpacing)
                        .foregroundStyle(Theme.textSecondary)
                }

                section("Đổi sang từ mới mỗi") {
                    VStack(alignment: .leading, spacing: 20) {
                        FlowLayout(spacing: 12) {
                            ForEach(RotationInterval.presets, id: \.self) { interval in
                                ChoiceChip(title: interval.title, isSelected: model.settings.interval == interval) {
                                    apply { () throws(AppModelError) in try model.setInterval(interval) }
                                }
                            }
                        }

                        CustomIntervalEditor(
                            amountText: $customAmount,
                            unit: $customUnit,
                            current: model.settings.interval
                        ) { interval in
                            apply { () throws(AppModelError) in try model.setInterval(interval) }
                        }
                    }
                }

                section("Nguồn từ") {
                    FlowLayout(spacing: 12) {
                        ForEach(WordSourceFilter.allCases, id: \.self) { filter in
                            ChoiceChip(title: filter.title, isSelected: model.settings.sourceFilter == filter) {
                                apply { () throws(AppModelError) in try model.setSourceFilter(filter) }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(Theme.Typography.font("HelveticaNeue-Medium", 14, .subheadline))
                        .foregroundStyle(Theme.error)
                }

                NoticeList(notices: model.notices)

                VStack(alignment: .leading, spacing: 8) {
                    Text("iOS quyết định thời điểm làm mới widget, nên từ mới có thể xuất hiện trễ.")
                    Text(
                        "Bộ từ có sẵn: \(model.library.builtInWords.count) từ · Từ của bạn: \(model.library.userWords.count) từ"
                    )
                }
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Theme.Metrics.gutter)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear(perform: prefillCustomInterval)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    /// Starts the custom editor from the interval in use, so editing "45 giây" begins at 45 / giây.
    private func prefillCustomInterval() {
        guard customAmount.isEmpty, case .every(let amount, let unit) = model.settings.interval else { return }
        customAmount = String(amount)
        customUnit = unit
    }

    private func apply(_ change: () throws(AppModelError) -> Void) {
        do throws(AppModelError) {
            try change()
            errorMessage = nil
        } catch {
            errorMessage = error.message
        }
    }
}

/// Amount + unit editor for a custom rotation interval (20 seconds ... 24 hours).
private struct CustomIntervalEditor: View {
    @Binding var amountText: String
    @Binding var unit: RotationInterval.TimeUnit
    let current: RotationInterval
    let onApply: (RotationInterval) -> Void

    private var amount: Int? {
        Int(amountText.trimmingCharacters(in: .whitespaces))
    }

    private var candidate: RotationInterval? {
        amount.flatMap { RotationInterval.custom(amount: $0, unit: unit) }
    }

    private var issue: RotationInterval.ValidationIssue? {
        guard let amount else { return .notPositive }
        return RotationInterval.validate(amount: amount, unit: unit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tùy chỉnh")
                .font(Theme.Typography.rowTitle)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 12) {
                TextField("Số", text: $amountText, prompt: Text("Số").foregroundStyle(Theme.textSecondary))
                    .keyboardType(.numberPad)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 72)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Metrics.fieldRadius, style: .continuous)
                            .fill(Theme.field)
                    )
                    .accessibilityLabel("Số lượng")

                Picker("Đơn vị", selection: $unit) {
                    ForEach(RotationInterval.TimeUnit.allCases, id: \.self) { unit in
                        Text(unit.title.capitalized).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }

            if !amountText.isEmpty, let issue {
                Label(issue.message, systemImage: "exclamationmark.circle")
                    .font(Theme.Typography.font("HelveticaNeue-Medium", 13, .footnote))
                    .foregroundStyle(Theme.error)
            } else if let seconds = candidate?.durationSeconds, seconds < RotationInterval.widgetReliableSeconds {
                Label(
                    "Dưới 1 phút: trong app từ đổi đúng hạn, nhưng iOS giới hạn tần suất làm mới nên widget có thể đổi chậm hơn.",
                    systemImage: "info.circle"
                )
                .font(Theme.Typography.font("HelveticaNeue-Medium", 13, .footnote))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                PillButton(title: "Áp dụng") {
                    if let candidate { onApply(candidate) }
                }
                .disabled(candidate == nil || candidate == current)
                .opacity(candidate == nil || candidate == current ? 0.45 : 1)

                Text("Đang dùng: \(current.title)")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
