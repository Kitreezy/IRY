import SwiftUI

struct HomeView: View {
    @Environment(\.memoryRepository) private var repository
    @State private var viewModel: HomeViewModel?
    @State private var navigationPath = NavigationPath()
    @State private var isSearchActive = false
    @State private var showSidebar = false
    @State private var showSettings = false
    @State private var showVoice = false
    @State private var showText = false
    @State private var showPhoto = false
    @State private var voiceSheetDetent: PresentationDetent = .medium
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack(path: $navigationPath) {
                ZStack {
                    screenContent
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { navigationBar }
                .navigationDestination(for: MemoryItem.self) { memory in
                    MemoryDetailView(memory: memory, onDelete: {
                        Task { await viewModel?.load() }
                    })
                }
            }

            sidebarOverlay
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showVoice, onDismiss: { voiceSheetDetent = .medium }) {
            VoiceCaptureView(onSave: { memory in
                await viewModel?.saveMemory(memory)
            }, selectedDetent: $voiceSheetDetent)
            .presentationDetents([.medium, .large], selection: $voiceSheetDetent)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showText) {
            CaptureMemoryView { memory in
                await viewModel?.saveMemory(memory)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showPhoto) {
            PhotoCaptureView { memory in
                await viewModel?.saveMemory(memory)
            }
        }
        .task {
            let vm = HomeViewModel(repository: repository)
            viewModel = vm
            await vm.load()
        }
    }

    // MARK: - Navigation Bar

    @ToolbarContentBuilder
    private var navigationBar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showSidebar = true }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .fontWeight(.medium)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
        }
    }

    // MARK: - Screen Content
    // Single layout — TextField never leaves the tree so focus is stable.

    // isSearchActive now means "query has text" — focus alone doesn't switch layout
    @ViewBuilder
    private var screenContent: some View {
        if let vm = viewModel {
            VStack(spacing: 0) {
                if !isSearchActive {
                    Spacer()
                    countView(count: vm.memoriesCount)
                        .padding(.bottom, 20)
                        .offset(y: -50)
                }

                searchBarView(vm)
                    .padding(.horizontal, 24)
                    .padding(.vertical, isSearchActive ? 12 : 0)
                    .offset(y: isSearchActive ? 0 : -50)

                if isSearchActive {
                    Divider()
                    searchResultsSection(vm)
                } else {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if !isSearchActive {
                    captureSection.padding(.bottom, 44)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isSearchActive)
            .onChange(of: vm.isQueryActive) { _, active in
                isSearchActive = active
            }
        }
    }

    // MARK: - Count View

    private func countView(count: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(L10n.Home.memoriesLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Search Bar

    private func searchBarView(_ vm: HomeViewModel) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(L10n.Home.searchPlaceholder, text: Binding(
                get: { vm.query },
                set: {
                    vm.query = $0
                    vm.onQueryChanged()
                }
            ))
            .focused($searchFocused)
            .autocorrectionDisabled()

            if vm.query.isEmpty {
                Button {
                    searchFocused = false
                    showVoice = true
                } label: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    vm.query = ""
                    vm.onQueryChanged()
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Search Results

    private func searchResultsSection(_ vm: HomeViewModel) -> some View {
        Group {
            if vm.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.results.isEmpty {
                emptyResultsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if let answer = vm.answer {
                            answerCard(text: answer)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        } else if vm.isAnswering {
                            answerLoadingCard
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }

                        ForEach(vm.results) { memory in
                            Button {
                                searchFocused = false
                                navigationPath.append(memory)
                            } label: {
                                MemoryCardView(memory: memory, query: vm.query)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await vm.deleteMemory(memory) }
                                } label: {
                                    Label(L10n.Memory.delete, systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Capture Section

    private var captureSection: some View {
        HStack(spacing: 44) {
            captureButton(icon: "camera.fill", label: L10n.Home.capturePhoto) {
                showPhoto = true
            }
            captureButton(icon: "mic.fill", label: L10n.Home.captureVoice) {
                showVoice = true
            }
            captureButton(icon: "pencil", label: L10n.Home.captureText) {
                showText = true
            }
        }
    }

    private func captureButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(.primary)
                }
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Answer Cards

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

    private var emptyResultsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(L10n.Search.notFoundTitle)
                .font(.headline)
            Text(L10n.Search.notFoundSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sidebar Overlay

    @ViewBuilder
    private var sidebarOverlay: some View {
        if showSidebar {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) { showSidebar = false }
                }
                .transition(.opacity)
                .zIndex(10)

            MemorySidebarView(
                isShowing: $showSidebar,
                memories: viewModel?.allMemories ?? []
            ) { memory in
                navigationPath.append(memory)
            }
            .transition(.move(edge: .leading))
            .zIndex(11)
        }
    }
}
