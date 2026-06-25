import SwiftUI

struct CreateMemoryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isSaving: Bool = false

    let onSave: (MemoryItem) async -> Void

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !content.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.CreateMemory.placeholderTitle, text: $title)
                } header: {
                    Text(L10n.CreateMemory.sectionAbout)
                }

                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 160)
                } header: {
                    Text(L10n.CreateMemory.sectionContent)
                }
            }
            .navigationTitle(L10n.CreateMemory.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.CreateMemory.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.CreateMemory.save) { Task { await save() } }
                        .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        let memory = MemoryItem(
            title: title.trimmingCharacters(in: .whitespaces),
            content: content.trimmingCharacters(in: .whitespaces),
            source: .userCreated
        )
        await onSave(memory)
        dismiss()
    }
}
