import SwiftUI

struct CaptureMemoryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var why: String = ""
    @State private var step: Step = .what
    @State private var isSaving = false

    let onSave: (MemoryItem) async -> Void

    private enum Step { case what, why }

    private var canProceed: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var canSave: Bool {
        !why.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .what: whatStep
                case .why: whyStep
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .animation(.easeInOut(duration: 0.2), value: step)
        }
    }

    // MARK: - Step 1: What

    private var whatStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Capture.whatTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(L10n.Capture.whatSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField(L10n.Capture.titlePlaceholder, text: $title)
                    .font(.body)
                    .textFieldStyle(.roundedBorder)

                ZStack(alignment: .topLeading) {
                    if content.isEmpty {
                        Text(L10n.Capture.contentPlaceholder)
                            .foregroundStyle(.tertiary)
                            .padding(8)
                    }
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))
            }

            Spacer()

            Button {
                withAnimation { step = .why }
            } label: {
                Text(L10n.Capture.next)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canProceed)
        }
        .padding()
    }

    // MARK: - Step 2: Why

    private var whyStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Capture.whyTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(L10n.Capture.whySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if why.isEmpty {
                    Text(L10n.Capture.whyPlaceholder)
                        .foregroundStyle(.tertiary)
                        .padding(8)
                }
                TextEditor(text: $why)
                    .frame(minHeight: 160)
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))

            Spacer()

            Button {
                Task { await save() }
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(L10n.Capture.save)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSave || isSaving)
        }
        .padding()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(L10n.Capture.cancel) {
                if step == .why {
                    withAnimation { step = .what }
                } else {
                    dismiss()
                }
            }
        }
        ToolbarItem(placement: .principal) {
            stepIndicator
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
            Circle()
                .fill(step == .why ? Color.accentColor : Color(.systemGray4))
                .frame(width: 8, height: 8)
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        let memory = MemoryItem(
            title: title.trimmingCharacters(in: .whitespaces),
            content: content.trimmingCharacters(in: .whitespaces),
            why: why.trimmingCharacters(in: .whitespaces),
            source: .userCreated
        )
        await onSave(memory)
        dismiss()
    }
}
