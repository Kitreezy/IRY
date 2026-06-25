import SwiftUI

struct PeopleView: View {
    @Environment(\.memoryRepository) private var repository
    @State private var viewModel: PeopleViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel: viewModel)
                }
            }
            .navigationTitle(L10n.People.title)
        }
        .task {
            let vm = PeopleViewModel(repository: repository)
            viewModel = vm
            await vm.load()
        }
    }

    @ViewBuilder
    private func content(viewModel: PeopleViewModel) -> some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.people.isEmpty {
            emptyState
        } else {
            List(viewModel.people) { person in
                NavigationLink {
                    PersonMemoriesView(person: person)
                } label: {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.name)
                                .font(.headline)
                            Text(L10n.People.mentions(person.mentions))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L10n.People.emptyTitle)
                .font(.headline)
            Text(L10n.People.emptySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Person Memories

struct PersonMemoriesView: View {
    let person: PeopleViewModel.PersonEntry

    var body: some View {
        List(person.memories) { memory in
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.title)
                    .font(.headline)
                Text(memory.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(memory.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.large)
    }
}
