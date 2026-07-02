import SwiftUI
import UIKit

struct MemoryCardView: View {
    let memory: MemoryItem
    var query: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Фото превью если есть
            if let url = memory.imageURL, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(memory.source.displayName, systemImage: memory.source.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let audioURL = memory.audioURL {
                        CompactAudioButton(url: audioURL)
                    }
                    Text(memory.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                memory.title.highlighted(query: query, base: .headline, highlightColor: .primary)
                    .lineLimit(1)

                let preview = memory.why.isEmpty ? memory.content : memory.why
                if !preview.isEmpty {
                    preview.highlighted(query: query, base: .subheadline, highlightColor: .primary)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
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
        case .userCreated: L10n.MemorySource.user
        case .appleNotes: L10n.MemorySource.notes
        case .calendar: L10n.MemorySource.calendar
        case .photos: L10n.MemorySource.photos
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
