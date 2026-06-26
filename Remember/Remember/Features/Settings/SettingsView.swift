import SwiftUI

struct SettingsView: View {
    @Environment(\.importService) private var importService
    @State private var isImporting = false
    @State private var lastResult: String?

    var body: some View {
        NavigationStack {
            List {
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
            .navigationTitle(L10n.Settings.title)
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

    private func runImport(source: MemorySource) async {
        isImporting = true
        let result = await importService.importFrom(source)
        isImporting = false
        lastResult = L10n.Settings.importResult(result.imported, sourceName: result.source.displayName)
    }
}
