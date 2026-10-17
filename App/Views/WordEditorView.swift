import SwiftUI
import VocabularyKit

/// Add/edit form presented as a sheet (kit sign-up form styling).
struct WordEditorView: View {
    enum Mode: Identifiable, Hashable {
        case add
        case edit(VocabularyWord)

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let word): "edit-\(word.id)"
            }
        }
    }

    let mode: Mode

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WordDraft
    /// Fields the user has changed; errors are only shown for these to avoid shouting at an empty form.
    @State private var touchedFields: Set<WordField> = []
    @State private var saveError: String?

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add: _draft = State(initialValue: WordDraft())
        case .edit(let word): _draft = State(initialValue: WordDraft(word: word))
        }
    }

    private var editingID: String? {
        if case .edit(let word) = mode { return word.id }
        return nil
    }

    var body: some View {
        // Validate once per render: each validation folds every existing term for the duplicate
        // check, which is noticeable on every keystroke near the 5,000-word cap.
        let issues = model.library.validate(draft, editingID: editingID)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(editingID == nil ? "Thêm từ mới" : "Sửa từ")
                        .font(Theme.Typography.screenTitle)
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(WordField.allCases, id: \.self) { field in
                        MoonTextField(
                            placeholder: field.placeholder,
                            text: binding(for: field),
                            isValid: isValid(field, issues: issues),
                            errorMessage: visibleError(for: field, issues: issues),
                            axis: field.isMultiline ? .vertical : .horizontal
                        )
                    }

                    VStack(spacing: 10) {
                        PrimaryButton(title: "Lưu", isEnabled: issues.isEmpty) { save() }
                        if let reason = disabledReason(for: issues) {
                            Text(reason)
                                .font(Theme.Typography.font("HelveticaNeue-Medium", 13, .footnote))
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        if let saveError {
                            Label(saveError, systemImage: "exclamationmark.triangle")
                                .font(Theme.Typography.font("HelveticaNeue-Medium", 13, .footnote))
                                .foregroundStyle(Theme.error)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .padding(Theme.Metrics.gutter)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                        .foregroundStyle(Theme.accentText)
                }
            }
        }
    }

    private func binding(for field: WordField) -> Binding<String> {
        Binding(
            get: { draft[field] },
            set: { newValue in
                draft[field] = newValue
                touchedFields.insert(field)
                saveError = nil
            }
        )
    }

    private func visibleError(for field: WordField, issues: [WordValidationIssue]) -> String? {
        guard touchedFields.contains(field) else { return nil }
        return issues.first { $0.field == field }?.message
    }

    private func isValid(_ field: WordField, issues: [WordValidationIssue]) -> Bool {
        touchedFields.contains(field)
            && !WordValidator.normalize(draft[field]).isEmpty
            && !issues.contains { $0.field == field }
    }

    /// Why "Lưu" is disabled, shown in words rather than by the dimmed button alone.
    private func disabledReason(for issues: [WordValidationIssue]) -> String? {
        guard let first = issues.first else { return nil }
        if case .required = first {
            return "Cần nhập từ tiếng Anh và nghĩa tiếng Việt để lưu."
        }
        return first.message
    }

    private func save() {
        do throws(AppModelError) {
            switch mode {
            case .add: try model.addWord(draft)
            case .edit(let word): try model.updateWord(id: word.id, with: draft)
            }
            dismiss()
        } catch {
            touchedFields = Set(WordField.allCases)
            saveError = error.message
        }
    }
}
