import SwiftUI

struct HomeView: View {
    @Environment(\.memoryRepository) private var repository
    @State private var viewModel: HomeViewModel?
    @State private var navigationPath = NavigationPath()
    @State private var showSidebar = false
    @State private var showSettings = false
    @State private var showVoice = false
    @State private var showText = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .leading) {
                screenContent
                sidebarOverlay
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navigationBar }
            .navigationDestination(for: MemoryItem.self) { memory in
                MemoryDetailView(memory: memory)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showVoice) {
            VoiceCaptureView { memory in
                await viewModel?.saveMemory(memory)
            }
        }
        .sheet(isPresented: $showText) {
            CaptureMemoryView { memory in
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

    @ViewBuilder
    private var screenContent: some View {
        if let vm = viewModel {
            Group {
                if vm.isQueryActive || searchFocused {
                    activeSearchLayout(vm)
                } else {
                    idleLayout(vm)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: vm.isQueryActive)
            .animation(.easeInOut(duration: 0.2), value: searchFocused)
        }
    }

    // MARK: - Idle Layout (centered)

    private func idleLayout(_ vm: HomeViewModel) -> some View {
        // Spacer–content–Spacer centers count+search on the full height.
        // Capture is overlaid separately so it doesn't shift the center.
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                countView(count: vm.memoriesCount)
                searchBarView(vm)
                    .padding(.horizontal, 24)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            captureSection
                .padding(.bottom, 44)
        }
    }

    // MARK: - Active Search Layout

    private func activeSearchLayout(_ vm: HomeViewModel) -> some View {
        VStack(spacing: 0) {
            searchBarView(vm)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

            Divider()

            searchResultsSection(vm)
        }
    }

    // MARK: - Count View

    private func countView(count: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

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
                // Photo capture — upcoming sprint
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

            MemorySidebarView(
                isShowing: $showSidebar,
                memories: viewModel?.allMemories ?? []
            ) { memory in
                navigationPath.append(memory)
            }
            .transition(.move(edge: .leading))
        }
    }
}
