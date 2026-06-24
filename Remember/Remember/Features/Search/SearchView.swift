import SwiftUI

struct SearchView: View {
    @Environment(\.memoryRepository) private var repository
    @State private var viewModel: SearchViewModel?
    @State private var showCreate: Bool = false

    var body: some View {
        NavigationStack {
            resultsArea
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showCreate = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .searchable(
                    text: Binding(
                        get: { viewModel?.query ?? "" },
                        set: {
                            viewModel?.query = $0
                            viewModel?.onQueryChanged()
                        }
                    ),
                    prompt: "What do you remember?"
                )
                .sheet(isPresented: $showCreate) {
                    CreateMemoryView { memory in
                        await viewModel?.saveMemory(memory)
                    }
                }
        }
        .task {
            let vm = SearchViewModel(repository: repository)
            viewModel = vm
            await vm.performSearch()
        }
    }

    @ViewBuilder
    private var resultsArea: some View {
        if let viewModel {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                emptyState
            } else if viewModel.results.isEmpty {
                emptyStart
            } else {
                List(viewModel.results) { memory in
                    MemoryCardView(memory: memory, query: viewModel.query)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
        } else {
            Color.clear
        }
    }

    private var emptyStart: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No memories yet")
                .font(.headline)
            Text("Tap + to add your first memory.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Nothing found")
                .font(.headline)
            Text("Try different words.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
