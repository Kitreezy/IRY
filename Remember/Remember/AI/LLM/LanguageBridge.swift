import Foundation
import NaturalLanguage
import FoundationModels
import Translation

/// Как модели на устройстве работать с данными на этом языке.
enum BridgeRoute: Sendable, Equatable {
    /// Модель язык знает — напрямую.
    case direct
    /// Не знает, но переводчик на устройстве знает и языки скачаны.
    case translate(Locale.Language)
    /// Переводчик знает, но языков на устройстве ещё нет.
    case needsDownload(Locale.Language)
    /// Не знает никто.
    case unsupported(Locale.Language)
}

/// Мост через перевод для модели, которая не знает языка данных.
///
/// Foundation Models на устройстве знает около двадцати языков, и русского
/// среди них нет. Translation — отдельная модель Apple, тоже на устройстве,
/// — русский знает. Мост переводит данные на английский, задача решается
/// по-английски, результат переводится обратно. Ничего не покидает
/// телефон.
///
/// Протокол — ради тестов: в симуляторе нет ни языковой модели, ни
/// переводчика.
protocol LanguageBridge: Sendable {
    func route(for texts: [String]) async -> BridgeRoute
    func translate(_ texts: [String], from source: Locale.Language, to target: Locale.Language) async throws -> [String]
}

extension LanguageBridge {
    /// Язык, на котором модель работает лучше всего и на который переводим.
    static var pivot: Locale.Language { Locale.Language(identifier: "en") }

    /// Решить задачу над `texts` на языке, который модель знает.
    ///
    /// `work` получает данные — исходные или переведённые — и возвращает
    /// строки результата; они переводятся обратно одной пачкой.
    func bridged(_ texts: [String], _ work: ([String]) async throws -> [String]) async throws -> [String] {
        switch await route(for: texts) {
        case .direct:
            return try await work(texts)
        case let .translate(language):
            let translated = try await translate(texts, from: language, to: Self.pivot)
            let result = try await work(translated)
            return try await translate(result, from: Self.pivot, to: language)
        case let .needsDownload(language):
            throw LLMError.translationNeedsDownload(language.displayName)
        case let .unsupported(language):
            throw LLMError.languageUnsupported(language.displayName)
        }
    }
}

extension Locale.Language {
    /// Название языка для человека — на языке его системы.
    var displayName: String {
        languageCode.flatMap { Locale.current.localizedString(forLanguageCode: $0.identifier) }
            ?? minimalIdentifier
    }
}

// MARK: - На устройстве

@available(iOS 26.0, *)
struct OnDeviceLanguageBridge: LanguageBridge {

    func route(for texts: [String]) async -> BridgeRoute {
        // Не распознали — пробуем напрямую: короткое «ок» языка не выдаёт.
        guard let language = Self.language(of: texts) else {
            return .direct
        }
        return await route(for: language)
    }

    func route(for language: Locale.Language) async -> BridgeRoute {
        let model = SystemLanguageModel.default
        if model.supportedLanguages.contains(where: { $0.languageCode == language.languageCode }) {
            return .direct
        }
        // Переводить надо в обе стороны: туда — данные, обратно — результат.
        let availability = LanguageAvailability()
        let there = await availability.status(from: language, to: Self.pivot)
        let back = await availability.status(from: Self.pivot, to: language)
        switch (there, back) {
        case (.installed, .installed):
            return .translate(language)
        case (.unsupported, _), (_, .unsupported):
            return .unsupported(language)
        default:
            return .needsDownload(language)
        }
    }

    func translate(_ texts: [String], from source: Locale.Language, to target: Locale.Language) async throws -> [String] {
        // Пустое переводчику не отдаём: ошибка на одной строке валит пачку.
        let indexed = texts.enumerated().filter {
            !$0.element.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !indexed.isEmpty else {
            return texts
        }
        // Сессия без SwiftUI переводит только скачанными языками — скачивает
        // экран настроек через `.translationTask`.
        let session = TranslationSession(installedSource: source, target: target)
        let responses = try await session.translations(from: indexed.map {
            TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset))
        })
        // Порядок ответов не обещан — сводим по идентификатору.
        var result = texts
        for response in responses {
            if let id = response.clientIdentifier, let index = Int(id) {
                result[index] = response.targetText
            }
        }
        return result
    }

    /// Язык данных — по всем кускам сразу.
    static func language(of texts: [String]) -> Locale.Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(texts.joined(separator: "\n"))
        guard let language = recognizer.dominantLanguage, language != .undetermined else {
            return nil
        }
        return Locale.Language(identifier: language.rawValue)
    }
}
