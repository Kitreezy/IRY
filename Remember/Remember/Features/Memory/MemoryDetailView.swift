import SwiftUI

struct MemoryDetailView: View {
    let memory: MemoryItem
    @Environment(\.memoryRepository) private var repository
    @State private var entities: [MemoryEntity] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                if !entities.isEmpty {
                    entitiesSection
                }
                contentSection
            }
            .padding()
        }
        .navigationTitle(memory.title)
        .navigationBarTitleDisplayMode(.large)
        .task { await loadEntities() }
    }

    // MARK: - Sections

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

    // MARK: - Data

    private func loadEntities() async {
        entities = (try? await repository.fetchEntities(for: memory.id)) ?? []
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
