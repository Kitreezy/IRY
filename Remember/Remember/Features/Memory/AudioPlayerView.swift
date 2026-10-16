import SwiftUI

struct AudioPlayerView: View {
    let path: String
    @State private var player = MemoryAudioPlayer()

    var body: some View {
        HStack(spacing: 12) {
            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: player.duration > 0 ? player.currentTime / player.duration : 0)
                    .tint(.accentColor)
                Text(timeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task { player.load(path: path) }
        .onDisappear { player.pause() }
    }

    private var timeLabel: String {
        "\(format(player.currentTime)) / \(format(player.duration))"
    }

    private func format(_ time: TimeInterval) -> String {
        let seconds = max(0, Int(time))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
