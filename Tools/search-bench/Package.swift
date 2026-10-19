// swift-tools-version: 6.0
//
// Замер всей выдачи поиска на Mac: настоящий SQLite FTS5 через GRDB и
// настоящая модель эмбеддингов. Исходники приложения подключены ссылками
// из Sources/App — замер всегда проверяет текущий код, а не копию.
// В симуляторе iOS моделей NaturalLanguage нет, поэтому — Mac.

import PackageDescription

let package = Package(
    name: "search-bench",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0")
    ],
    targets: [
        .executableTarget(
            name: "search-bench",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
