import SwiftUI

struct SearchView: View {
    @Environment(\.memoryRepository) private var repository
    @State private var viewModel: SearchViewModel?
    @State private var showCreate: Bool = false
    @State private var showVoice: Bool = false

    var body: some View {
        NavigationStack {
            resultsArea
                .navigationTitle(L10n.Search.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showCreate = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button {
                            showVoice = true
                        } label: {
                            Image(systemName: "mic")
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
                    prompt: L10n.Search.prompt
                )
                .sheet(isPresented: $showCreate) {
                    CaptureMemoryView { memory in
                        await viewModel?.saveMemory(memory)
                    }
                }
                .sheet(isPresented: $showVoice) {
                    VoiceCaptureView { memory in
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
                List {
                    if let answer = viewModel.answer {
                        answerCard(text: answer)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else if viewModel.isAnswering {
                        answerLoadingCard
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    ForEach(viewModel.results) { memory in
                        NavigationLink {
                            MemoryDetailView(memory: memory)
                        } label: {
                            MemoryCardView(memory: memory, query: viewModel.query)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        } else {
            Color.clear
        }
    }

    // MARK: - Answer Card

    private func answerCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.Search.answerLabel, systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var answerLoadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(L10n.Search.answerLoading)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Empty States

    private var emptyStart: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L10n.Search.emptyTitle)
                .font(.headline)
            Text(L10n.Search.emptySubtitle)
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
            Text(L10n.Search.notFoundTitle)
                .font(.headline)
            Text(L10n.Search.notFoundSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
