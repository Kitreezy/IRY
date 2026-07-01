import SwiftUI
import UIKit

struct MemorySidebarView: View {
    @Binding var isShowing: Bool
    let memories: [MemoryItem]
    let onSelect: (MemoryItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            memoriesList
        }
        .frame(width: min(UIScreen.main.bounds.width * 0.82, 360))
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 4, y: 0)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(L10n.Home.sidebarTitle)
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isShowing = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: - List

    private var memoriesList: some View {
        Group {
            if memories.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(memories) { memory in
                            sidebarRow(memory)
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        }
    }

    private func sidebarRow(_ memory: MemoryItem) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isShowing = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onSelect(memory)
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                if let path = memory.imagePath, let image = UIImage(contentsOfFile: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !memory.why.isEmpty {
                        Text(memory.why)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else if !memory.content.isEmpty {
                        Text(memory.content)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Text(memory.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "brain")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(L10n.Search.emptyTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
