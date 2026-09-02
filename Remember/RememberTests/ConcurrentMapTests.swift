import Testing
import Foundation
@testable import Remember

/// Счётчик одновременно выполняющихся задач — проверяет, что окно параллелизма
/// действительно ограничено.
private actor ConcurrencyProbe {
    private var current = 0
    private(set) var peak = 0

    func enter() {
        current += 1
        peak = max(peak, current)
    }

    func leave() {
        current -= 1
    }
}

@Suite("Parallel processing")
struct ConcurrentMapTests {

    // MARK: - Корректность

    @Test("concurrentMap сохраняет порядок исходной последовательности")
    func preservesOrder() async {
        let input = Array(0..<50)
        let output = await input.concurrentMap(maxConcurrent: 8) { value -> Int in
            // Случайная задержка — при неверной реализации порядок сломается
            try? await Task.sleep(for: .milliseconds(Int.random(in: 1...20)))
            return value * 2
        }
        #expect(output == input.map { $0 * 2 })
    }

    @Test("concurrentMap на пустой последовательности возвращает пустой результат")
    func emptyInput() async {
        let output = await [Int]().concurrentMap { $0 }
        #expect(output.isEmpty)
    }

    @Test("concurrentCompactMap отбрасывает nil и сохраняет порядок")
    func compactMapDropsNils() async {
        let output = await Array(0..<10).concurrentCompactMap(maxConcurrent: 4) { value -> Int? in
            value.isMultiple(of: 2) ? value : nil
        }
        #expect(output == [0, 2, 4, 6, 8])
    }

    // MARK: - Ограничение параллелизма

    @Test("Одновременно выполняется не больше maxConcurrent задач")
    func respectsConcurrencyLimit() async {
        let probe = ConcurrencyProbe()
        let limit = 4

        _ = await Array(0..<40).concurrentMap(maxConcurrent: limit) { _ -> Bool in
            await probe.enter()
            try? await Task.sleep(for: .milliseconds(10))
            await probe.leave()
            return true
        }

        let peak = await probe.peak
        print("[Concurrency] peak in-flight: \(peak), limit: \(limit)")
        #expect(peak <= limit)
        #expect(peak > 1) // параллелизм действительно был
    }

    @Test("maxConcurrent = 1 даёт последовательное выполнение")
    func serialWhenLimitIsOne() async {
        let probe = ConcurrencyProbe()

        _ = await Array(0..<10).concurrentMap(maxConcurrent: 1) { _ -> Bool in
            await probe.enter()
            try? await Task.sleep(for: .milliseconds(5))
            await probe.leave()
            return true
        }

        let peak = await probe.peak
        #expect(peak == 1)
    }

    // MARK: - Ускорение

    @Test("Параллельная обработка быстрее последовательной")
    func parallelIsFaster() async {
        let items = Array(0..<20)
        let delay = Duration.milliseconds(30)

        let sequentialStart = ContinuousClock.now
        for _ in items {
            try? await Task.sleep(for: delay)
        }
        let sequential = ContinuousClock.now - sequentialStart

        let parallelStart = ContinuousClock.now
        _ = await items.concurrentMap(maxConcurrent: 5) { _ -> Bool in
            try? await Task.sleep(for: delay)
            return true
        }
        let parallel = ContinuousClock.now - parallelStart

        print("[Speedup] sequential: \(sequential), parallel: \(parallel)")
        // Окно в 5 задач — теоретически ~5x. Требуем хотя бы 2x с запасом
        // на планировщик, чтобы тест не был флаки на загруженной машине.
        #expect(parallel < sequential / 2)
    }

    // MARK: - Отмена

    @Test("Отмена задачи прекращает запуск новых элементов")
    func stopsOnCancellation() async {
        let probe = ConcurrencyProbe()
        let started = Mutex(0)

        let task = Task {
            await Array(0..<200).concurrentForEach(maxConcurrent: 2) { _ in
                started.increment()
                await probe.enter()
                try? await Task.sleep(for: .milliseconds(20))
                await probe.leave()
            }
        }

        try? await Task.sleep(for: .milliseconds(60))
        task.cancel()
        await task.value

        let count = started.value
        print("[Cancellation] started \(count) of 200")
        #expect(count < 200)
    }
}

/// Минимальный потокобезопасный счётчик для теста отмены.
private final class Mutex: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Int

    init(_ value: Int) { self.storage = value }

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
