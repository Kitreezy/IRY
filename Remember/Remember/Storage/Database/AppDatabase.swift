import Foundation
import GRDB
import Observation

@Observable
final class AppDatabase: Sendable {
    static let shared = AppDatabase()

    let writer: any DatabaseWriter

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
            let pool = try DatabasePool(path: url.path, configuration: config)
            writer = pool
            try AppDatabase.migrate(writer)
        } catch {
            fatalError("Database initialization failed: \(error)")
        }
    }

    init(inMemory: Bool) throws {
        let config = Configuration()
        writer = try DatabaseQueue(configuration: config)
        try AppDatabase.migrate(writer)
    }

    private static func databaseURL() -> URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let dir = appSupport.appendingPathComponent("Remember", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("remember.sqlite")
    }

    private static func migrate(_ writer: any DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(writer)
    }
}
