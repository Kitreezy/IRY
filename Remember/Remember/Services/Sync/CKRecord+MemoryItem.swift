import Foundation
import CloudKit

extension CKRecord {
    static let memoryRecordType = "MemoryItem"

    convenience init(memoryItem: MemoryItem) {
        let recordID = CKRecord.ID(recordName: memoryItem.id.uuidString)
        self.init(recordType: CKRecord.memoryRecordType, recordID: recordID)
        self["title"] = memoryItem.title
        self["content"] = memoryItem.content
        self["source"] = memoryItem.source.rawValue
        self["createdAt"] = memoryItem.createdAt
        self["updatedAt"] = memoryItem.updatedAt
        self["tags"] = memoryItem.tags
    }
}

extension MemoryItem {
    init?(record: CKRecord) {
        guard
            let title = record["title"] as? String,
            let content = record["content"] as? String,
            let sourceRaw = record["source"] as? String,
            let source = MemorySource(rawValue: sourceRaw),
            let createdAt = record["createdAt"] as? Date,
            let updatedAt = record["updatedAt"] as? Date,
            let id = UUID(uuidString: record.recordID.recordName)
        else { return nil }

        let tags = record["tags"] as? [String] ?? []
        self.init(id: id, title: title, content: content, source: source,
                  createdAt: createdAt, updatedAt: updatedAt, tags: tags)
    }
}
