import SwiftUI
import VocabularyKit

/// "Từ vựng" tab: browse, search, add, edit and delete words (kit Meditate / Sleep Stories layout).
struct WordListView: View {
    @Environment(AppModel.self) private var model
    @State private var filter: WordSourceFilter = .all
    @State private var query = ""
    @State private var editorMode: WordEditorView.Mode? = DebugLaunchOptions.initialSheet == .editor ? .add : nil
    @State private var detailWord: VocabularyWord?
    /// Action chosen in the detail sheet, performed only after the sheet has finished dismissing:
    /// UIKit drops an editor sheet or confirmation dialog requested while a dismissal is in flight.
    @State private var pendingDetailAction: DetailAction?
    @State private var pendingDeletion: VocabularyWord?
    @State private var errorMessage: String?

    var body: some View {
        let words = model.library.search(query, in: filter)

        List {
            header
                .listRowInsets(
                    EdgeInsets(top: 20, leading: Theme.Metrics.gutter, bottom: 8, trailing: Theme.Metrics.gutter)
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if words.isEmpty {
                emptyState
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(words) { word in
                    WordRow(word: word) { detailWord = word }
                        .listRowInsets(
                            EdgeInsets(top: 8, leading: Theme.Metrics.gutter, bottom: 8, trailing: Theme.Metrics.gutter)
                        )
                        .listRowSeparatorTint(Theme.field)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing) {
                            if word.source == .user {
                                Button("Xóa", role: .destructive) { pendingDeletion = word }
                                Button("Sửa") { editorMode = .edit(word) }
                                    .tint(Theme.accentStrong)
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Thêm từ") { editorMode = .add }
                .padding(.horizontal, Theme.Metrics.gutter)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Theme.background.opacity(0), Theme.background],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.35)
                    )
                )
        }
        .sheet(item: $editorMode) { mode in
            WordEditorView(mode: mode)
        }
        .sheet(item: $detailWord, onDismiss: performPendingDetailAction) { word in
            WordDetailView(
                word: word,
                onEdit: {
                    pendingDetailAction = .edit(word)
                    detailWord = nil
                },
                onDelete: {
                    pendingDetailAction = .delete(word)
                    detailWord = nil
                }
            )
        }
        .confirmationDialog(
            "Xóa từ này?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { word in
            Button("Xóa “\(word.term)”", role: .destructive) { delete(word) }
            Button("Hủy", role: .cancel) {}
        }
        .alert(
            "Không thực hiện được",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text("Từ vựng")
                    .font(Theme.Typography.screenTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Bộ từ có sẵn và những từ bạn tự thêm.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(WordSourceFilter.allCases, id: \.self) { option in
                        FilterChip(title: option.title, systemImage: option.systemImage, isSelected: filter == option) {
                            filter = option
                        }
                    }
                }
            }

            SearchField(text: $query)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !WordValidator.normalize(query).isEmpty {
            ContentUnavailableView.search(text: query)
        } else if filter == .user {
            ContentUnavailableView(
                "Bạn chưa thêm từ nào",
                systemImage: "text.badge.plus",
                description: Text("Nhấn “Thêm từ” để tạo từ của riêng bạn.")
            )
        } else {
            ContentUnavailableView(
                "Không có từ nào",
                systemImage: "books.vertical",
                description: Text("Không tải được bộ từ có sẵn.")
            )
        }
    }

    private func delete(_ word: VocabularyWord) {
        do throws(AppModelError) {
            try model.deleteWord(id: word.id)
        } catch {
            errorMessage = error.message
        }
        pendingDeletion = nil
    }

    private enum DetailAction {
        case edit(VocabularyWord)
        case delete(VocabularyWord)
    }

    private func performPendingDetailAction() {
        guard let action = pendingDetailAction else { return }
        pendingDetailAction = nil
        switch action {
        case .edit(let word): editorMode = .edit(word)
        case .delete(let word): pendingDeletion = word
        }
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            TextField(
                "Tìm từ hoặc nghĩa",
                text: $text,
                prompt: Text("Tìm từ hoặc nghĩa").foregroundStyle(Theme.textSecondary)
            )
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: Theme.Metrics.minimumTapTarget, height: Theme.Metrics.minimumTapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Xóa nội dung tìm kiếm")
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.fieldRadius, style: .continuous).fill(Theme.field)
        )
    }
}

/// List row in the kit's track-list style: round badge, title, uppercase caption.
private struct WordRow: View {
    let word: VocabularyWord
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 44

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(String(word.term.prefix(1)).uppercased())
                    .font(Theme.Typography.rowTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: badgeSize, height: badgeSize)
                    .overlay(Circle().strokeBorder(Theme.textSecondary, lineWidth: 1))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(word.term)
                        .font(Theme.Typography.rowTitle)
                        .foregroundStyle(Theme.textPrimary)
                    Text(word.meaningVi)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    if word.source == .builtIn {
                        Text("Có sẵn")
                            .captionStyle()
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(word.source == .user ? "Xem, sửa hoặc xóa" : "Xem chi tiết")
    }
}
