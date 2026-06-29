import SwiftUI

struct SettingsView: View {
    @Environment(\.importService) private var importService
    @State private var providerService = LLMProviderService.shared
    @State private var isImporting = false
    @State private var lastResult: String?
    @State private var apiKeyInput = ""
    @State private var isKeySaved = false

    var body: some View {
        NavigationStack {
            List {
                aiSection
                sourcesSection
            }
            .navigationTitle(L10n.Settings.title)
        }
        .onAppear {
            apiKeyInput = providerService.apiKey(for: .openAI) ?? ""
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
                Text(L10n.Settings.aiOpenAI).tag(LLMProviderKind.openAI)
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            if providerService.currentKind == .openAI {
                apiKeyRow
            }
        } header: {
            Text(L10n.Settings.sectionAI)
        } footer: {
            Text(privacyNote)
                .foregroundStyle(.secondary)
        }
    }

    private var apiKeyRow: some View {
        HStack {
            SecureField(L10n.Settings.aiKeyPlaceholder, text: $apiKeyInput)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: apiKeyInput) { _, _ in
                    isKeySaved = false
                }

            Button {
                saveAPIKey()
            } label: {
                Text(isKeySaved ? L10n.Settings.aiKeySaved : L10n.Settings.aiKeySave)
                    .foregroundStyle(isKeySaved ? Color.secondary : Color.accentColor)
                    .animation(.easeInOut(duration: 0.2), value: isKeySaved)
            }
            .disabled(apiKeyInput.isEmpty)
        }
    }

    private var privacyNote: String {
        switch providerService.currentKind {
        case .apple: L10n.Settings.aiPrivacyApple
        case .openAI: L10n.Settings.aiPrivacyOpenAI
        }
    }

    // MARK: - Sources Section

    private var sourcesSection: some View {
        Section {
            importRow(
                title: L10n.Settings.importCalendar,
                icon: "calendar",
                source: .calendar
            )
            importRow(
                title: L10n.Settings.importPhotos,
                icon: "photo",
                source: .photos
            )
        } header: {
            Text(L10n.Settings.sectionSources)
        } footer: {
            if let result = lastResult {
                Text(result)
                    .foregroundStyle(.secondary)
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
                if isImporting {
                    ProgressView()
                }
            }
        }
        .disabled(isImporting)
    }

    // MARK: - Actions

    private func saveAPIKey() {
        providerService.saveAPIKey(apiKeyInput, for: .openAI)
        isKeySaved = true
    }

    private func runImport(source: MemorySource) async {
        isImporting = true
        let result = await importService.importFrom(source)
        isImporting = false
        lastResult = L10n.Settings.importResult(result.imported, sourceName: result.source.displayName)
    }
}
