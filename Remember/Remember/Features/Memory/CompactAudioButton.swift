import SwiftUI

/// Small play/pause control for list rows (sidebar, search results).
/// A real Button, not wrapped inside another Button, so it can sit
/// safely alongside a row's own onTapGesture-based navigation without
/// the two conflicting.
struct CompactAudioButton: View {
    let url: URL
    @State private var player = MemoryAudioPlayer()

    var body: some View {
        Button {
            player.load(path: url.path)
            player.toggle()
        } label: {
            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }
}
