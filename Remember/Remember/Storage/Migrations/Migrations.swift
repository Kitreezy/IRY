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

        migrator.registerMigration("v2_embeddings") { db in
            try db.create(table: "memory_embeddings") { t in
                t.primaryKey("memory_id", .text).notNull()
                    .references("memory_items", onDelete: .cascade)
                t.column("vector", .blob).notNull()
            }
        }

        migrator.registerMigration("v4_why_and_summary") { db in
            try db.alter(table: "memory_items") { t in
                t.add(column: "why", .text).notNull().defaults(to: "")
                t.add(column: "summary", .text).notNull().defaults(to: "")
            }
        }

        migrator.registerMigration("v5_image_path") { db in
            try db.alter(table: "memory_items") { t in
                t.add(column: "image_path", .text)
            }
        }

        migrator.registerMigration("v6_audio_path") { db in
            try db.alter(table: "memory_items") { t in
                t.add(column: "audio_path", .text)
            }
        }

        // Вектор без модели несравним ни с чем: после смены провайдера поиск
        // молча переставал находить. Старые строки получают пустую модель —
        // она не совпадёт ни с одной настоящей, и при запуске их пересчитают.
        migrator.registerMigration("v7_embedding_model") { db in
            try db.alter(table: "memory_embeddings") { t in
                t.add(column: "model", .text).notNull().defaults(to: "")
            }
        }

        // Полнотекстовый индекс — по леммам и с «почему это важно». Индекс
        // пересоздаётся: колонки FTS5 после создания не добавить. Леммы для
        // уже сохранённого считаются здесь же, до перестройки индекса.
        migrator.registerMigration("v8_search_text") { db in
            try db.alter(table: "memory_items") { t in
                t.add(column: "search_text", .text).notNull().defaults(to: "")
            }
            let rows = try Row.fetchAll(db, sql: "SELECT id, title, content, why, tags FROM memory_items")
            for row in rows {
                let tags: String = row["tags"]
                let text = SearchText.index(title: row["title"], content: row["content"], why: row["why"],
                                            tags: tags.isEmpty ? [] : tags.split(separator: ",").map(String.init))
                try db.execute(sql: "UPDATE memory_items SET search_text = ? WHERE id = ?",
                               arguments: [text, row["id"] as String])
            }

            try db.dropFTS5SynchronizationTriggers(forTable: "memory_items_fts")
            try db.drop(table: "memory_items_fts")
            try db.create(virtualTable: "memory_items_fts", using: FTS5()) { t in
                t.synchronize(withTable: "memory_items")
                t.tokenizer = .unicode61()
                t.column("title")
                t.column("content")
                t.column("why")
                t.column("tags")
                t.column("search_text")
            }
        }

        migrator.registerMigration("v3_entities") { db in
            try db.create(table: "memory_entities") { t in
                t.primaryKey("id", .text).notNull()
                t.column("memory_id", .text).notNull()
                    .references("memory_items", onDelete: .cascade)
                t.column("value", .text).notNull()
                t.column("type", .text).notNull()
            }
            try db.create(
                index: "idx_entities_memory_id",
                on: "memory_entities",
                columns: ["memory_id"]
            )
            try db.create(
                index: "idx_entities_type",
                on: "memory_entities",
                columns: ["type"]
            )
        }
    }
}
