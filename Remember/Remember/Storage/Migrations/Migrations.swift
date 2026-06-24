import GRDB

enum Migrations {
    static func register(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_memory_items") { db in
            try db.create(table: "memory_items") { t in
                t.primaryKey("id", .text).notNull()
                t.column("title", .text).notNull()
                t.column("content", .text).notNull()
                t.column("source", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("tags", .text).notNull()
            }

            try db.create(virtualTable: "memory_items_fts", using: FTS5()) { t in
                t.synchronize(withTable: "memory_items")
                t.tokenizer = .unicode61()
                t.column("title")
                t.column("content")
                t.column("tags")
            }
        }
    }
}
