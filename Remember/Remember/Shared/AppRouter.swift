import Foundation
import Observation

/// Куда перейти по просьбе извне — из Siri, Shortcuts, поиска системы.
///
/// Интент работает вне экранов: он знает, что открыть, но не держит
/// навигацию. Он кладёт сюда маршрут, главный экран его забирает и
/// переходит. Маршрут один и забирается один раз: открыть одно и то же
/// дважды при каждом появлении экрана — хуже, чем не открыть.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum Route: Equatable {
        case search(String)
        case memory(UUID)
    }

    private(set) var pending: Route?

    func open(_ route: Route) {
        pending = route
    }

    /// Забрать маршрут — он исполняется ровно один раз.
    func take() -> Route? {
        defer { pending = nil }
        return pending
    }
}
