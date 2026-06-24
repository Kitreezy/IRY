import SwiftUI

struct MemoryCardView: View {
    let memory: MemoryItem
    var query: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(memory.source.displayName, systemImage: memory.source.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(memory.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            memory.title.highlighted(query: query, base: .headline, highlightColor: .primary)
                .lineLimit(1)

            if !memory.content.isEmpty {
                memory.content.highlighted(query: query, base: .subheadline, highlightColor: .primary)
                    .lineLimit(2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

extension MemorySource {
    var displayName: String {
        switch self {
        case .userCreated: "Memory"
        case .appleNotes:  "Notes"
        case .calendar:    "Calendar"
        case .photos:      "Photos"
        }
    }

    var icon: String {
        switch self {
        case .userCreated: "brain"
        case .appleNotes:  "note.text"
        case .calendar:    "calendar"
        case .photos:      "photo"
        }
    }
}
