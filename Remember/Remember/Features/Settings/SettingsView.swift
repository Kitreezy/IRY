import SwiftUI

struct SettingsView: View {
    @Environment(\.importService) private var importService
    @Environment(\.memoryRepository) private var repository
    @State private var providerService = LLMProviderService.shared
    @State private var isImporting = false
    @State private var lastResult: String?
    @State private var geminiKeyInput = ""
    @State private var savedGeminiKey: String? = nil
    @State private var showResetConfirm = false
    @State private var isResetting = false
    @State private var aiTestResult: AITestResult? = nil
    @State private var isTesting = false
    @State private var isReindexing = false
    @State private var reindexResult: String? = nil

    private enum AITestResult {
        case success(text: String, embedding: Int)
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            List {
                aiSection
                sourcesSection
                #if DEBUG
                debugSection
                #endif
            }
            .navigationTitle(L10n.Settings.title)
        }
        .onAppear {
            savedGeminiKey = providerService.apiKey(for: .gemini)
        }
        .confirmationDialog(
            L10n.Settings.resetConfirmTitle,
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.Settings.resetConfirmAction, role: .destructive) {
                Task { await resetAllData() }
            }
        } message: {
            Text(L10n.Settings.resetConfirmMessage)
        }
    }

    // MARK: - AI Section

    private var aiSection: some View {
        Section {
            Picker(L10n.Settings.sectionAI, selection: Binding(
                get: { providerService.currentKind },
                set: { providerService.select($0) }
            )) {
                Text(L10n.Settings.aiApple).tag(LLMProviderKind.apple)
                Text(L10n.Settings.aiGemini).tag(LLMProviderKind.gemini)
                // TODO: re-enable when OpenAI credits available
                // Text(L10n.Settings.aiOpenAI).tag(LLMProviderKind.openAI)
                // TODO: re-enable when Claude API key available
                // Text(L10n.Settings.aiClaude).tag(LLMProviderKind.claude)
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            if providerService.currentKind == .gemini {
                geminiKeySection
            }
        } header: {
            Text(L10n.Settings.sectionAI)
        } footer: {
            Text(privacyNote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var geminiKeySection: some View {
        if let key = savedGeminiKey, !key.isEmpty {
            HStack {
                Label(maskedKey(key), systemImage: "key.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    deleteGeminiKey()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } else {
            HStack {
                SecureField(L10n.Settings.aiGeminiKeyPlaceholder, text: $geminiKeyInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button(L10n.Settings.aiKeySave) {
                    saveGeminiKey()
                }
                .foregroundStyle(Color.accentColor)
                .disabled(geminiKeyInput.isEmpty)
            }
        }
    }

    private var privacyNote: String {
        switch providerService.currentKind {
        case .apple: L10n.Settings.aiPrivacyApple
        case .gemini: L10n.Settings.aiPrivacyGemini
        case .openAI: L10n.Settings.aiPrivacyOpenAI
        case .claude: L10n.Settings.aiPrivacyClaude
        }
    }

    private func maskedKey(_ key: String) -> String {
        let prefix = String(key.prefix(8))
        let suffix = String(key.suffix(4))
        return "\(prefix)••••\(suffix)"
    }

    // MARK: - Sources Section

    private var sourcesSection: some View {
        Section {
            importRow(title: L10n.Settings.importCalendar, icon: "calendar", source: .calendar)
            importRow(title: L10n.Settings.importPhotos, icon: "photo", source: .photos)
        } header: {
            Text(L10n.Settings.sectionSources)
        } footer: {
            if let result = lastResult {
                Text(result).foregroundStyle(.secondary)
            }
        }
    }

    private func importRow(title: String, icon: String, source: MemorySource) -> some View {
        Button {
            Task { await runImport(source: source) }
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if isImporting { ProgressView() }
            }
        }
        .disabled(isImporting)
    }

    // MARK: - DEBUG Section

    #if DEBUG
    private var debugSection: some View {
        Section {
            Button {
                Task { await runAITest() }
            } label: {
                HStack {
                    Label("Test AI Provider", systemImage: "cpu")
                    Spacer()
                    if isTesting { ProgressView() }
                }
            }
            .disabled(isTesting)

            if let result = aiTestResult {
                aiTestResultView(result)
            }

            Button {
                Task { await runReindex() }
            } label: {
                HStack {
                    Label("Re-index Memories", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    if isReindexing { ProgressView() }
                }
            }
            .disabled(isReindexing)

            if let result = reindexResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                HStack {
                    Label(L10n.Settings.resetAll, systemImage: "trash")
                    Spacer()
                    if isResetting { ProgressView() }
                }
            }
            .disabled(isResetting)
        } header: {
            Text("DEBUG")
        } footer: {
            Text(L10n.Settings.resetFooter)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func aiTestResultView(_ result: AITestResult) -> some View {
        switch result {
        case .success(let text, let dims):
            VStack(alignment: .leading, spacing: 4) {
                Label("Provider: \(providerService.currentKind.displayName)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                Text("💬 \(text)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("📐 Embedding: \(dims) dims")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        case .failure(let error):
            Label(error, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }
    #endif

    // MARK: - Actions

    private func saveGeminiKey() {
        let key = geminiKeyInput.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        providerService.saveAPIKey(key, for: .gemini)
        savedGeminiKey = key
        geminiKeyInput = ""
    }

    private func deleteGeminiKey() {
        APIKeyStore.delete(for: .gemini)
        savedGeminiKey = nil
        geminiKeyInput = ""
    }

    private func runAITest() async {
        isTesting = true
        aiTestResult = nil
        do {
            let text = try await providerService.textCompletion.complete(
                prompt: "Ответь одним словом на русском: какой сейчас сезон года?"
            )
            let embedding = try await providerService.embedding.embed(text: "тест памяти")
            aiTestResult = .success(text: text, embedding: embedding.count)
        } catch {
            aiTestResult = .failure(error.localizedDescription)
        }
        isTesting = false
    }

    private func runReindex() async {
        isReindexing = true
        reindexResult = nil
        let memories = (try? await repository.fetchAll()) ?? []
        let semantic = SemanticSearchService(repository: repository)
        await semantic.reindexAll(memories: memories)
        isReindexing = false
        reindexResult = "✓ Re-indexed \(memories.count) memories with \(providerService.currentKind.displayName)"
    }

    private func runImport(source: MemorySource) async {
        isImporting = true
        let result = await importService.importFrom(source)
        isImporting = false
        lastResult = L10n.Settings.importResult(result.imported, sourceName: result.source.displayName)
    }

    private func resetAllData() async {
        isResetting = true
        try? await repository.deleteAll()
        isResetting = false
        lastResult = nil
    }
}
