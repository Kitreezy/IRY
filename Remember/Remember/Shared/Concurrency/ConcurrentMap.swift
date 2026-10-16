import Foundation

/// Параллельная обработка независимых элементов с ограничением параллелизма.
///
/// Зачем ограничение: без него `withTaskGroup` создаст задачу на каждый элемент
/// сразу. Для 500 воспоминаний это 500 одновременных сетевых запросов к AI —
/// провайдер ответит 429, а устройство потратит память на буферы. Скользящее
/// окно держит в полёте не более `maxConcurrent` задач.
enum ConcurrencyLimit {
    /// Сетевые операции (embeddings, LLM). Компромисс между скоростью и rate limit.
    static let network = 4

    /// On-device LLM (Foundation Models). Модель одна на устройство —
    /// больше двух запросов только увеличивают очередь и расход памяти.
    static let onDeviceLLM = 2

    /// Чистые вычисления на CPU — упираемся в число ядер.
    static var cpu: Int { Swift.max(2, ProcessInfo.processInfo.activeProcessorCount) }
}

extension Sequence where Element: Sendable {

    /// Применяет `transform` к элементам параллельно, сохраняя порядок исходной
    /// последовательности.
    ///
    /// - Parameter maxConcurrent: максимум одновременно выполняемых задач.
    /// - Returns: результаты в том же порядке, что и входные элементы.
    func concurrentMap<T: Sendable>(
        maxConcurrent: Int = ConcurrencyLimit.network,
        _ transform: @Sendable @escaping (Element) async -> T
    ) async -> [T] {
        let items = Array(self)
        guard !items.isEmpty else { return [] }

        let limit = Swift.max(1, Swift.min(maxConcurrent, items.count))

        return await withTaskGroup(of: (Int, T).self) { group in
            var results: [Int: T] = [:]
            results.reserveCapacity(items.count)
            var next = 0

            // Заполняем окно
            while next < limit {
                let index = next
                group.addTask { (index, await transform(items[index])) }
                next += 1
            }

            // Как только одна задача завершилась — запускаем следующую
            while let (index, value) = await group.next() {
                results[index] = value
                guard !Task.isCancelled, next < items.count else { continue }
                let nextIndex = next
                group.addTask { (nextIndex, await transform(items[nextIndex])) }
                next += 1
            }

            return (0..<items.count).compactMap { results[$0] }
        }
    }

    /// Как `concurrentMap`, но отбрасывает `nil`. Порядок сохраняется.
    func concurrentCompactMap<T: Sendable>(
        maxConcurrent: Int = ConcurrencyLimit.network,
        _ transform: @Sendable @escaping (Element) async -> T?
    ) async -> [T] {
        await concurrentMap(maxConcurrent: maxConcurrent, transform).compactMap { $0 }
    }

    /// Выполняет `operation` для каждого элемента параллельно, не собирая результаты.
    func concurrentForEach(
        maxConcurrent: Int = ConcurrencyLimit.network,
        _ operation: @Sendable @escaping (Element) async -> Void
    ) async {
        _ = await concurrentMap(maxConcurrent: maxConcurrent) { element -> Bool in
            await operation(element)
            return true
        }
    }
}
