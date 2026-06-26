import SwiftUI

struct TimelineView: View {
    @Environment(\.memoryRepository) private var repository
    @State private var viewModel: TimelineViewModel?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.Timeline.title)
                .navigationBarTitleDisplayMode(.large)
        }
        .task {
            let vm = TimelineViewModel(repository: repository)
            viewModel = vm
            await vm.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.sections.isEmpty {
                emptyState
            } else {
                memoriesList(viewModel: viewModel)
            }
        } else {
            Color.clear
        }
    }

    private func memoriesList(viewModel: TimelineViewModel) -> some View {
        List {
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.memories) { memory in
                        NavigationLink {
                            MemoryDetailView(memory: memory)
                        } label: {
                            MemoryCardView(memory: memory)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text(section.formattedDate)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L10n.Timeline.emptyTitle)
                .font(.headline)
            Text(L10n.Timeline.emptySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
