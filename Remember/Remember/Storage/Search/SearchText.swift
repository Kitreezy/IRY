import Foundation
import NaturalLanguage

/// Текст для полнотекстового поиска — в начальных формах слов.
///
/// Токенизатор FTS5 `unicode61` морфологии не знает: «стоматолог» не находил
/// «к стоматологу», «ключи» — «ключей». Поэтому индексируются и ищутся
/// леммы: «записалась к стоматологу» → «записаться к стоматолог». Лемматизатор
/// — NLTagger, на устройстве, и для коротких фраз ему надо назвать язык:
/// «подарок дедушки» без этого остаётся как есть.
enum SearchText {

    /// Леммы текста по порядку, в нижнем регистре. Слово без леммы — числа,
    /// имена, которых словарь не знает, — остаётся как написано.
    static func lemmas(of text: String) -> [String] {
        words(of: text).map(\.lemma)
    }

    /// Слова текста: как написано и в начальной форме, оба в нижнем регистре.
    static func words(of text: String) -> [(raw: String, lemma: String)] {
        guard !text.isEmpty else { return [] }
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        if let language = language(of: text) {
            tagger.setLanguage(language, range: text.startIndex..<text.endIndex)
        }
        var result: [(raw: String, lemma: String)] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma,
                             options: [.omitWhitespace, .omitPunctuation, .omitOther]) { tag, range in
            let raw = String(text[range]).lowercased()
            result.append((raw, tag?.rawValue.lowercased() ?? raw))
            return true
        }
        return result
    }

    /// Что положить в индекс для воспоминания: всё, по чему его ищут, —
    /// включая «почему это важно», которого в индексе раньше не было.
    static func index(title: String, content: String, why: String, tags: [String]) -> String {
        ([title, content, why] + tags)
            .filter { !$0.isEmpty }
            .map { lemmas(of: $0).joined(separator: " ") }
            .joined(separator: " ")
    }

    /// Запрос FTS5: леммы без служебных слов, через ИЛИ.
    ///
    /// Раньше требовались все слова запроса, и вопрос «какой пароль от
    /// вайфая на даче?» не находил ничего: в воспоминании нет «какой», «от»
    /// и «на». Через ИЛИ находится всё, где есть хоть одно значимое слово,
    /// а порядок задаёт bm25 — у кого совпало больше и реже встречающихся
    /// слов, тот выше. `nil` — значимых слов в запросе нет.
    ///
    /// Каждое слово ищется и леммой, и как написано. Лемматизатора может не
    /// быть — в симуляторе его нет, на устройстве его ресурсы могут
    /// появиться позже, — и тогда в индексе лежат слова как есть. С обеими
    /// формами запрос находит и то, и другое.
    static func pattern(for query: String) -> String? {
        let terms = words(of: query)
            .filter { !stopWords.contains($0.lemma) && !stopWords.contains($0.raw) }
            .flatMap { [$0.lemma, $0.raw] }
        guard !terms.isEmpty else { return nil }
        var seen = Set<String>()
        return terms
            .filter { seen.insert($0).inserted }
            // Кавычки — чтобы слово не читалось как оператор FTS5.
            .map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
            .joined(separator: " OR ")
    }

    private static func language(of text: String) -> NLLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        if let language = recognizer.dominantLanguage, language != .undetermined {
            return language
        }
        return nil
    }

    /// Служебные слова — в начальной форме, раз сравниваются леммы. Без них
    /// вопрос «где мои ключи» находил бы всё, где есть «где» или «мой».
    static let stopWords: Set<String> = [
        // русский
        "а", "без", "бы", "быть", "в", "вот", "все", "всё", "вы", "где", "да", "для", "до", "его",
        "ее", "её", "если", "есть", "еще", "ещё", "же", "за", "и", "из", "или", "к", "как", "какой",
        "когда", "кто", "ли", "мне", "меня", "мой", "мы", "на", "над", "не", "нет", "но", "о", "об",
        "он", "она", "они", "оно", "от", "по", "под", "при", "про", "с", "со", "так", "там", "то",
        "тот", "ты", "у", "уже", "что", "чтобы", "это", "этот", "я", "сколько", "почему", "зачем",
        "который", "свой", "себя", "мочь", "надо", "нужно", "через", "перед", "после", "между",
        "около", "ради", "кроме", "тоже", "также", "очень", "только", "сам", "весь",
        // английский
        "a", "an", "and", "are", "at", "be", "can", "do", "for", "from", "have", "how", "i", "in",
        "is", "it", "me", "my", "of", "on", "or", "the", "to", "what", "when", "where", "which",
        "who", "why", "with", "you", "your"
    ]
}
