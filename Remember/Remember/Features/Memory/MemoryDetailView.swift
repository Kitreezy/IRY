import SwiftUI
import UIKit

struct MemoryDetailView: View {
    let memory: MemoryItem
    @Environment(\.memoryRepository) private var repository
    @Environment(\.dismiss) private var dismiss
    @State private var entities: [MemoryEntity] = []
    @State private var related: [MemoryItem] = []
    @State private var showDeleteConfirm = false

    private var relatedService: RelatedMemoriesService {
        RelatedMemoriesService(repository: repository)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let path = memory.imagePath, let image = UIImage(contentsOfFile: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                }
                headerSection
                    .padding(.horizontal)
                if !memory.why.isEmpty {
                    whySection
                        .padding(.horizontal)
                }
                if !entities.isEmpty {
                    entitiesSection
                        .padding(.horizontal)
                }
                if !memory.content.isEmpty && memory.content != memory.why {
                    contentSection
                        .padding(.horizontal)
                }
                if !related.isEmpty {
                    relatedSection
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(memory.title)
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .confirmationDialog(
            L10n.Memory.deleteConfirmTitle,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.Memory.delete, role: .destructive) {
                Task {
                    try? await repository.delete(id: memory.id)
                    dismiss()
                }
            }
        } message: {
            Text(L10n.Memory.deleteConfirmMessage)
        }
    }

    // MARK: - Sections

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.MemoryDetail.whyTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(memory.why)
                .font(.body)
                .italic()
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var headerSection: some View {
        HStack {
            Label(memory.source.displayName, systemImage: memory.source.icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(memory.createdAt.formatted(date: .long, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var contentSection: some View {
        Text(memory.content)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var entitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(EntityType.allCases, id: \.self) { type in
                let group = entities.filter { $0.type == type }
                if !group.isEmpty {
                    EntityGroupView(type: type, entities: group)
                }
            }
        }
    }

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.MemoryDetail.relatedTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(related) { item in
                NavigationLink {
                    MemoryDetailView(memory: item)
                } label: {
                    MemoryCardView(memory: item)
                }
            }
        }
    }

    // MARK: - Data

    private func load() async {
        async let entitiesResult = repository.fetchEntities(for: memory.id)
        async let relatedResult = relatedService.findRelated(to: memory)
        entities = (try? await entitiesResult) ?? []
        related = await relatedResult
    }
}

// MARK: - Entity Group

private struct EntityGroupView: View {
    let type: EntityType
    let entities: [MemoryEntity]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(type.localizedLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(entities) { entity in
                        EntityChipView(entity: entity)
                    }
                }
            }
        }
    }
}

// MARK: - Entity Chip

private struct EntityChipView: View {
    let entity: MemoryEntity

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: entity.type.icon)
                .font(.caption2)
            Text(entity.value)
                .font(.subheadline)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary)
        .clipShape(Capsule())
    }
}

// MARK: - EntityType extensions

extension EntityType: CaseIterable {
    public static var allCases: [EntityType] { [.person, .place, .topic, .company] }

    var localizedLabel: String {
        switch self {
        case .person: L10n.EntityType.person
        case .place: L10n.EntityType.place
        case .topic: L10n.EntityType.topic
        case .company: L10n.EntityType.company
        }
    }

    var icon: String {
        switch self {
        case .person: "person"
        case .place: "mappin"
        case .topic: "tag"
        case .company: "building.2"
        }
    }
}
