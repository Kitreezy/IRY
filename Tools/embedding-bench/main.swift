//
//  Замер смыслового поиска: как модели эмбеддингов находят воспоминания по
//  перефразированным запросам из Benchmarks/semantic-search.json.
//
//  Собирается из тех же файлов провайдеров, что и приложение, и запускается
//  на Mac: в симуляторе iOS моделей NaturalLanguage нет. Запуск —
//  Tools/bench-embeddings.sh; Gemini — если задан GEMINI_API_KEY.
//

import Foundation
import NaturalLanguage

struct Dataset: Decodable {
    struct Memory: Decodable { let id: String; let text: String }
    struct Query: Decodable { let text: String; let relevant: [String]; let crossLingual: Bool? }
    let memories: [Memory]
    let queries: [Query]
}

/// Способ считать вектор: что приложение делало раньше, что делает теперь,
/// и облако для сравнения.
struct Strategy {
    let name: String
    let threshold: Float
    let embed: (String) async throws -> TextEmbedding
}

/// Как было: английская модель предложений для любого текста.
func legacy() -> Strategy? {
    guard let model = NLEmbedding.sentenceEmbedding(for: .english) else { return nil }
    return Strategy(name: "до: NLEmbedding (англ.)", threshold: 0.55) { text in
        guard let vector = model.vector(for: text.lowercased()) else { throw LLMError.invalidResponse }
        return TextEmbedding(vector: vector.map(Float.init), model: "legacy")
    }
}

func cosine(_ a: [Float], _ b: [Float]) -> Float {
    guard a.count == b.count, !a.isEmpty else { return 0 }
    var dot: Float = 0, na: Float = 0, nb: Float = 0
    for i in a.indices { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i] }
    return na > 0 && nb > 0 ? dot / (na.squareRoot() * nb.squareRoot()) : 0
}

func pad(_ s: String, _ n: Int) -> String { s.count >= n ? s : s + String(repeating: " ", count: n - s.count) }
func f(_ x: Float) -> String { String(format: "%.2f", x) }

let path = CommandLine.arguments.dropFirst().first ?? "Benchmarks/semantic-search.json"
let data = try Data(contentsOf: URL(fileURLWithPath: path))
let dataset = try JSONDecoder().decode(Dataset.self, from: data)

var strategies: [Strategy] = []
if let legacy = legacy() { strategies.append(legacy) }
let onDevice = OnDeviceEmbeddingProvider()
strategies.append(Strategy(name: "после: NLContextualEmbedding", threshold: OnDeviceEmbeddingProvider.contextualThreshold) {
    try await onDevice.embed(text: $0)
})
if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty {
    let gemini = GeminiEmbeddingProvider(apiKey: key)
    strategies.append(Strategy(name: "облако: Gemini", threshold: 0.55) { try await gemini.embed(text: $0) })
}

print("Воспоминаний: \(dataset.memories.count), запросов: \(dataset.queries.count) (межъязыковых: \(dataset.queries.filter { $0.crossLingual == true }.count))\n")
print(pad("модель", 30), pad("R@1", 6), pad("R@3", 6), pad("MRR", 6), pad("межъяз. R@3", 13), pad("близкие", 9), pad("чужие", 9), pad("порог→F1", 14), pad("лучший", 12), "≤3 лучших: порог→F1")

/// Средний вектор коллекции по каждой модели — общий фон, который
/// центрирование вычитает.
func means(of vectors: [TextEmbedding]) -> [String: [Float]] {
    Dictionary(grouping: vectors, by: \.model).mapValues { group in
        var sum = [Float](repeating: 0, count: group[0].vector.count)
        for e in group { for i in sum.indices { sum[i] += e.vector[i] } }
        return sum.map { $0 / Float(group.count) }
    }
}

for strategy in strategies {
  var embedded: [String: TextEmbedding] = [:]
  for memory in dataset.memories {
      embedded[memory.id] = try? await strategy.embed(memory.text)
  }
  var queryVectors: [String: TextEmbedding] = [:]
  for query in dataset.queries {
      queryVectors[query.text] = try? await strategy.embed(query.text)
  }
  let background = means(of: Array(embedded.values))

  for centered in [false] {
    let started = Date()
    let center = { (e: TextEmbedding) -> TextEmbedding in
        guard centered, let mean = background[e.model] else { return e }
        return TextEmbedding(vector: zip(e.vector, mean).map { $0 - $1 }, model: e.model)
    }
    let memoryVectors = embedded.mapValues(center)

    var hits1 = 0, hits3 = 0, reciprocal: Float = 0, sameCount = 0
    var crossHits3 = 0, crossCount = 0
    var relevantScores: [Float] = [], otherScores: [Float] = []
    var pairs: [(score: Float, relevant: Bool)] = []
    /// Выдача каждого запроса по убыванию: что нужно и сколько там чего.
    var rankings: [(ranked: [Float], relevant: [Bool])] = []

    for query in dataset.queries {
        guard let q = queryVectors[query.text].map(center) else { continue }
        // Векторы разных моделей несравнимы: такие пары в выдачу не попадают.
        let ranked = dataset.memories.compactMap { memory -> (String, Float)? in
            guard let m = memoryVectors[memory.id], m.model == q.model else { return nil }
            return (memory.id, cosine(q.vector, m.vector))
        }.sorted { $0.1 > $1.1 }
        let rank = ranked.firstIndex { query.relevant.contains($0.0) }

        if query.crossLingual == true {
            crossCount += 1
            if let rank, rank < 3 { crossHits3 += 1 }
            continue
        }
        sameCount += 1
        if let rank {
            if rank == 0 { hits1 += 1 }
            if rank < 3 { hits3 += 1 }
            reciprocal += 1 / Float(rank + 1)
        }
        rankings.append((ranked.map(\.1), ranked.map { query.relevant.contains($0.0) }))
        for (id, score) in ranked {
            let isRelevant = query.relevant.contains(id)
            (isRelevant ? { relevantScores.append(score) } : { otherScores.append(score) })()
            pairs.append((score, isRelevant))
        }
    }

    func f1(at threshold: Float) -> Float {
        let tp = Float(pairs.filter { $0.relevant && $0.score >= threshold }.count)
        let fp = Float(pairs.filter { !$0.relevant && $0.score >= threshold }.count)
        let fn = Float(pairs.filter { $0.relevant && $0.score < threshold }.count)
        return tp == 0 ? 0 : 2 * tp / (2 * tp + fp + fn)
    }
    /// Выдача как в приложении: не больше `limit` лучших и только выше порога.
    func f1(top limit: Int, at threshold: Float) -> Float {
        var tp: Float = 0, returned: Float = 0, relevant: Float = 0
        for r in rankings {
            relevant += Float(r.relevant.filter { $0 }.count)
            for i in r.ranked.indices.prefix(limit) where r.ranked[i] >= threshold {
                returned += 1
                if r.relevant[i] { tp += 1 }
            }
        }
        return tp == 0 ? 0 : 2 * tp / (returned + relevant)
    }
    let candidates = stride(from: Float(0.3), through: 0.95, by: 0.01)
    let best = candidates.max { f1(at: $0) < f1(at: $1) } ?? 0
    let bestTop = candidates.max { f1(top: 3, at: $0) < f1(top: 3, at: $1) } ?? 0
    let mean = { (xs: [Float]) in xs.isEmpty ? 0 : xs.reduce(0, +) / Float(xs.count) }

    let n = Float(max(sameCount, 1))
    print(pad(strategy.name + (centered ? " −фон" : ""), 30),
          pad(f(Float(hits1) / n), 6), pad(f(Float(hits3) / n), 6), pad(f(reciprocal / n), 6),
          pad("\(crossHits3)/\(crossCount)", 13),
          pad(f(mean(relevantScores)), 9), pad(f(mean(otherScores)), 9),
          pad("\(f(strategy.threshold))→\(f(f1(at: strategy.threshold)))", 14),
          pad("\(f(best))→\(f(f1(at: best)))", 12),
          "\(f(bestTop))→\(f(f1(top: 3, at: bestTop)))",
          String(format: "  (%.1f с)", Date().timeIntervalSince(started)))
  }
}
print("""

R@k — доля запросов, где нужное воспоминание в первых k; MRR — средняя обратная позиция.
Близкие/чужие — среднее сходство запроса с нужным и с остальными воспоминаниями.
Порог→F1 — насколько хорошо порог приложения отделяет нужное от лишнего.
«≤3 лучших» — выдача как в приложении: не больше трёх совпадений, и только выше порога.
""")
