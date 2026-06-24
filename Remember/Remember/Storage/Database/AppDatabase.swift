import Foundation
import GRDB
import Observation

@Observable
final class AppDatabase: Sendable {
    static let shared = AppDatabase()

    let pool: DatabasePool

    private init() {
        let url = AppDatabase.databaseURL()
        var config = Configuration()
        config.prepareDatabase { db in
            db.trace(options: .profile) { event in
                #if DEBUG
                print("[DB]", event)
                #endif
            }
        }

        do {
            pool = try DatabasePool(path: url.path, configuration: config)
            try AppDatabase.migrate(pool)
        } catch {
            fatalError("Database initialization failed: \(error)")
        }
    }

    init(inMemory: Bool) throws {
        let config = Configuration()
        pool = try DatabasePool(path: ":memory:", configuration: config)
        try AppDatabase.migrate(pool)
    }

    private static func databaseURL() -> URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let dir = appSupport.appendingPathComponent("Remember", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("remember.sqlite")
    }

    private static func migrate(_ pool: DatabasePool) throws {
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(pool)
    }
}
