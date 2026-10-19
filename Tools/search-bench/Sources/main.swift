//
//  Замер всей выдачи поиска по Benchmarks/search.json — так же, как ищут
//  экраны приложения: полнотекстовый поиск в репозитории, смысловой поверх.
//
//  Запуск: Tools/bench-search.sh
//

import Foundation

struct Dataset: Decodable {
    struct Memory: Decodable { let id: String; let title: String; let content: String; let why: String }
    struct Query: Decodable { let kind: String; let text: String; let relevant: [String] }
    let memories: [Memory]
    let queries: [Query]
}

func pad(_ s: String, _ n: Int) -> String { s.count >= n ? s : s + String(repeating: " ", count: n - s.count) }
func f(_ x: Double) -> String { String(format: "%.2f", x) }

let path = CommandLine.arguments.dropFirst().first ?? "Benchmarks/search.json"
let dataset = try JSONDecoder().decode(Dataset.self, from: Data(contentsOf: URL(fileURLWithPath: path)))

let database = try AppDatabase(inMemory: true)
let repository = GRDBMemoryRepository(writer: database.writer)
let semantic = SemanticSearchService(repository: repository,
                                     embedding: EmbeddingService(provider: OnDeviceEmbeddingProvider()))

var idOf: [UUID: String] = [:]
for memory in dataset.memories {
    let item = MemoryItem(title: memory.title, content: memory.content, why: memory.why)
    idOf[item.id] = memory.id
    try await repository.save(item)
    await semantic.indexMemory(item)
}

struct Score { var count = 0, hit1 = 0, hit3 = 0, empty = 0; var rr = 0.0, returned = 0 }
var byKind: [String: Score] = [:]
var total = Score()
let verbose = CommandLine.arguments.contains("-v")

for query in dataset.queries {
    let fts = (try? await repository.search(query: query.text)) ?? []
    let results = await semantic.search(query: query.text, ftsResults: fts)
    let ids = results.compactMap { idOf[$0.id] }
    let rank = ids.firstIndex { query.relevant.contains($0) }

    for key in [query.kind, "всего"] {
        var s = key == "всего" ? total : byKind[key, default: Score()]
        s.count += 1
        s.returned += ids.count
        if ids.isEmpty { s.empty += 1 }
        if let rank {
            if rank == 0 { s.hit1 += 1 }
            if rank < 3 { s.hit3 += 1 }
            s.rr += 1 / Double(rank + 1)
        }
        if key == "всего" { total = s } else { byKind[key] = s }
    }
    if verbose {
        print("\(rank.map { "#\($0 + 1)" } ?? "—")\t\(query.kind)\t\(query.text)\t→ \(ids.prefix(5).joined(separator: ", "))")
    }
}

print(pad("вид", 15), pad("запросов", 10), pad("R@1", 6), pad("R@3", 6), pad("MRR", 6), pad("пусто", 7), "в выдаче")
for kind in ["слова", "вопрос", "смысл", "почему", "межъязыковой", "всего"] {
    let s = kind == "всего" ? total : byKind[kind, default: Score()]
    guard s.count > 0 else { continue }
    let n = Double(s.count)
    print(pad(kind, 15), pad("\(s.count)", 10), pad(f(Double(s.hit1) / n), 6), pad(f(Double(s.hit3) / n), 6),
          pad(f(s.rr / n), 6), pad("\(s.empty)", 7), f(Double(s.returned) / n))
}
print("\nR@k — нужное в первых k; MRR — средняя обратная позиция; пусто — запросов без единого результата; в выдаче — сколько результатов в среднем.")
