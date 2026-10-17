import SwiftUI
import VocabularyKit

/// Read-only view of one word; user words also offer edit and delete.
struct WordDetailView: View {
    let word: VocabularyWord
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeroWordCard(word: word)

                if word.source == .user {
                    HStack(spacing: 12) {
                        PillButton(title: "Sửa", action: onEdit)
                        PillButton(title: "Xóa", role: .destructive, action: onDelete)
                    }
                } else {
                    Label("Từ có sẵn, chỉ xem", systemImage: "lock.fill")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(Theme.Metrics.gutter)
            .padding(.top, 12)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
