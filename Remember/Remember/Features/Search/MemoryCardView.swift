import SwiftUI

struct MemoryCardView: View {
    let memory: MemoryItem

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

            Text(memory.title)
                .font(.headline)
                .lineLimit(1)

            if !memory.content.isEmpty {
                Text(memory.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

private extension MemorySource {
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
