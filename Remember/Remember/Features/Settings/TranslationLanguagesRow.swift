import SwiftUI
import Translation

/// Языки для перевода — для языка человека, которого модель на устройстве
/// не знает. Без них мост через перевод отказывает, а скачать их можно
/// только так: сессией из `.translationTask`, которая сама спрашивает
/// человека системным окном.
@available(iOS 26.0, *)
struct TranslationLanguagesRow: View {
    @State private var model = TranslationLanguagesModel()
    /// Что скачать. Пока `nil`, `.translationTask` ничего не делает.
    @State private var download: TranslationSession.Configuration?

    var body: some View {
        content
            .task { await model.refresh() }
            // Замыкание — вне главного актора: сессия не Sendable. Модель
            // строки захвачена явно, к ней возвращаемся через await.
            .translationTask(download) { @Sendable [model] session in
                try? await session.prepareTranslation()
                // Окно закрывается раньше, чем кончается загрузка: система
                // качает дальше сама. Ждём готовности, пока строка на экране.
                await model.waitForDownload()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.route {
        case .none, .direct:
            EmptyView()
        case let .translate(language):
            Label(L10n.Settings.aiLanguagesReady(language.displayName), systemImage: "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case let .needsDownload(language):
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Settings.aiLanguagesNeeded(language.displayName))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if model.isDownloading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(L10n.Settings.aiLanguagesDownloading).font(.footnote)
                    }
                } else {
                    Button(L10n.Settings.aiLanguagesDownload) {
                        model.isDownloading = true
                        // Повторное нажатие после отказа: та же конфигурация
                        // задачу не перезапустит — её объявляют недействительной.
                        if download != nil {
                            download?.invalidate()
                        } else {
                            download = TranslationSession.Configuration(source: language, target: model.pivot)
                        }
                    }
                }
            }
        case let .unsupported(language):
            Text(L10n.Settings.aiLanguagesUnsupported(language.displayName))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

@available(iOS 26.0, *)
@MainActor
@Observable
final class TranslationLanguagesModel {
    private(set) var route: BridgeRoute?
    var isDownloading = false

    private let bridge = OnDeviceLanguageBridge()
    let pivot = OnDeviceLanguageBridge.pivot

    /// Язык человека — первый из предпочитаемых в системе.
    private var language: Locale.Language {
        Locale.preferredLanguages.first.map(Locale.Language.init(identifier:)) ?? Locale.current.language
    }

    func refresh() async {
        route = await bridge.route(for: language)
    }

    func waitForDownload() async {
        while !Task.isCancelled {
            await refresh()
            guard case .needsDownload = route else { break }
            try? await Task.sleep(for: .seconds(2))
        }
        isDownloading = false
    }
}
