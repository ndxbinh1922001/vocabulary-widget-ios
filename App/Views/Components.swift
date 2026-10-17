import SwiftUI
import VocabularyKit

// MARK: - Buttons

/// Full-width capsule button (kit "GET STARTED": 63pt high, fully rounded).
struct PrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.button)
                .tracking(Theme.Typography.buttonTracking)
                .textCase(.uppercase)
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity, minHeight: Theme.Metrics.primaryButtonHeight)
                .background(Capsule().fill(Theme.accentStrong))
                .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// Small secondary pill (kit "START": 70×35).
struct PillButton: View {
    let title: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(Theme.Typography.button)
                .tracking(Theme.Typography.buttonTracking)
                .textCase(.uppercase)
                .foregroundStyle(role == .destructive ? Theme.error : Theme.pillText)
                .padding(.horizontal, 18)
                .frame(minWidth: Theme.Metrics.pillSize.width, minHeight: Theme.Metrics.minimumTapTarget)
                .background(Capsule().fill(Theme.pill))
        }
        .buttonStyle(.plain)
    }
}

/// Rounded-square filter chip with an icon and a label underneath (kit category chips, 65×65).
struct FilterChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: Theme.Metrics.chipRadius, style: .continuous)
                    .fill(isSelected ? Theme.accentStrong : Theme.chip)
                    .frame(width: Theme.Metrics.chipSize, height: Theme.Metrics.chipSize)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Theme.onAccent)
                    }
                Text(title)
                    .font(Theme.Typography.chipLabel)
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Capsule choice used in Settings (kit day-of-week selector): filled when selected.
struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.rowTitle)
                .foregroundStyle(isSelected ? Theme.background : Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 16)
                .frame(minWidth: 64, minHeight: Theme.Metrics.minimumTapTarget + 8)
                .background {
                    Capsule().fill(isSelected ? Theme.textPrimary : Color.clear)
                }
                .overlay {
                    Capsule().strokeBorder(isSelected ? Color.clear : Theme.textSecondary, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Left-aligned wrapping layout for chips: at large Dynamic Type sizes whole chips move to the
/// next row instead of their labels wrapping inside the capsule.
struct FlowLayout: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows = rowsFitting(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        rows.removeAll()
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rowsFitting(maxWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = clampedSize(of: subviews[index], maxWidth: bounds.width)
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rowsFitting(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = clampedSize(of: subviews[index], maxWidth: maxWidth)
            let proposedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty && proposedWidth > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }

    /// Ideal size, narrowed to the container so an oversized chip scales its text down instead of overflowing.
    private func clampedSize(of subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        guard ideal.width > maxWidth else { return ideal }
        return subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
    }
}

// MARK: - Inputs

/// Kit input field: light fill, 15pt radius, 63pt high, inline validation underneath.
struct MoonTextField: View {
    let placeholder: String
    @Binding var text: String
    var isValid = false
    var errorMessage: String?
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                TextField(
                    placeholder,
                    text: $text,
                    prompt: Text(placeholder).foregroundStyle(Theme.textSecondary),
                    axis: axis
                )
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(axis == .vertical ? 1...5 : 1...1)

                if isValid {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.success)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, axis == .vertical ? 20 : 0)
            .frame(minHeight: Theme.Metrics.fieldHeight)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.fieldRadius, style: .continuous).fill(Theme.field)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Metrics.fieldRadius, style: .continuous)
                    .strokeBorder(Theme.error, lineWidth: errorMessage == nil ? 0 : 1.5)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(Theme.Typography.font("HelveticaNeue-Medium", 13, .footnote))
                    .foregroundStyle(Theme.error)
                    .padding(.leading, 4)
            }
        }
    }
}

// MARK: - Decoration and status

/// Soft background shapes standing in for the kit's illustrations. Purely decorative.
struct BlobBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(Theme.blob)
                    .frame(width: proxy.size.width * 0.9)
                    .offset(x: proxy.size.width * 0.45, y: -proxy.size.height * 0.08)
                Circle()
                    .fill(Theme.blob.opacity(0.7))
                    .frame(width: proxy.size.width * 0.7)
                    .offset(x: -proxy.size.width * 0.4, y: proxy.size.height * 0.55)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// App name lockup in the kit's letter-spaced style ("Silent ◐ Moon").
struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("TỪ")
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Theme.accentStrong))
            Text("VỰNG")
        }
        .font(Theme.Typography.brand)
        .tracking(3)
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Từ Vựng")
        .accessibilityAddTraits(.isHeader)
    }
}

/// Persistent warnings from `AppModel`.
struct NoticeList: View {
    let notices: [AppNotice]

    var body: some View {
        if !notices.isEmpty {
            VStack(spacing: 10) {
                ForEach(notices) { notice in
                    Label {
                        Text(notice.message)
                            .font(Theme.Typography.font("HelveticaNeue-Medium", 14, .subheadline))
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(Theme.onAccent)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Metrics.cardRadius, style: .continuous)
                            .fill(Theme.darkCard)
                    )
                }
            }
        }
    }
}

// MARK: - Labels

extension WordSourceFilter {
    var title: String {
        switch self {
        case .all: "Tất cả"
        case .builtIn: "Có sẵn"
        case .user: "Của tôi"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2.fill"
        case .builtIn: "books.vertical.fill"
        case .user: "person.fill"
        }
    }
}

extension RotationInterval {
    var title: String {
        switch self {
        case .every(let amount, let unit): "\(amount) \(unit.title)"
        case .daily: "Mỗi ngày"
        }
    }
}

extension RotationInterval.TimeUnit {
    var title: String {
        switch self {
        case .seconds: "giây"
        case .minutes: "phút"
        case .hours: "giờ"
        }
    }
}

extension RotationInterval.ValidationIssue {
    var message: String {
        switch self {
        case .notPositive: "Hãy nhập một số nguyên lớn hơn 0."
        case .tooShort: "Tối thiểu \(RotationInterval.minimumSeconds) giây."
        case .tooLong: "Tối đa 24 giờ."
        }
    }
}

extension WordField {
    var placeholder: String {
        switch self {
        case .term: "Từ tiếng Anh *"
        case .ipa: "Phiên âm IPA (vd: /ˈwɜːd/)"
        case .partOfSpeech: "Loại từ (vd: noun, verb)"
        case .meaningVi: "Nghĩa tiếng Việt *"
        case .example: "Câu ví dụ"
        }
    }

    var isMultiline: Bool {
        self == .meaningVi || self == .example
    }
}

extension WordValidationIssue {
    var message: String {
        switch self {
        case .required(.term): "Hãy nhập từ tiếng Anh."
        case .required(.meaningVi): "Hãy nhập nghĩa tiếng Việt."
        case .required: "Trường này là bắt buộc."
        case .tooLong(_, let limit): "Tối đa \(limit) ký tự."
        case .duplicateTerm: "Từ này đã có trong danh sách."
        case .limitReached(let max): "Bạn đã lưu tối đa \(max) từ."
        }
    }
}
