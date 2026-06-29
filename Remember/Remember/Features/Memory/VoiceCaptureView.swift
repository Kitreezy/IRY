import SwiftUI

struct VoiceCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (MemoryItem) async -> Void

    private enum CaptureState {
        case idle
        case recording
        case transcribing
        case captured(String)
        case error(String)
    }

    @State private var state: CaptureState = .idle
    @State private var why: String = ""
    @State private var isSaving = false
    @State private var waveformLevels: [Float] = Array(repeating: 0.3, count: 20)

    private let recorder = VoiceRecorderService()
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var canSave: Bool {
        if case .captured = state { return !why.trimmingCharacters(in: .whitespaces).isEmpty }
        return false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                switch state {
                case .idle:
                    idleView
                case .recording:
                    recordingView
                case .transcribing:
                    transcribingView
                case .captured(let transcript):
                    capturedView(transcript: transcript)
                case .error(let message):
                    errorView(message: message)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Capture.cancel) { dismiss() }
                }
            }
        }
        .onReceive(timer) { _ in
            guard case .recording = state else { return }
            Task { await updateWaveform() }
        }
    }

    // MARK: - States

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(L10n.Voice.title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(L10n.Voice.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            recordButton(isRecording: false)
            Spacer()
        }
    }

    private var recordingView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(L10n.Voice.recording)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.red)

            waveformView

            recordButton(isRecording: true)

            Text(L10n.Voice.stopHint)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var transcribingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text(L10n.Voice.transcribing)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func capturedView(transcript: String) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Capture.whyTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(L10n.Capture.whySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.Voice.transcriptLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(transcript)
                    .font(.body)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            ZStack(alignment: .topLeading) {
                if why.isEmpty {
                    Text(L10n.Capture.whyPlaceholder)
                        .foregroundStyle(.tertiary)
                        .padding(8)
                }
                TextEditor(text: $why)
                    .frame(minHeight: 120)
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))

            Spacer()

            Button {
                Task { await save(transcript: transcript) }
            } label: {
                if isSaving {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text(L10n.Capture.save).frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSave || isSaving)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L10n.Voice.tryAgain) {
                state = .idle
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }

    // MARK: - Waveform

    private var waveformView: some View {
        HStack(spacing: 3) {
            ForEach(Array(waveformLevels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red)
                    .frame(width: 3, height: CGFloat(max(4, level * 60)))
            }
        }
        .frame(height: 60)
        .animation(.easeInOut(duration: 0.1), value: waveformLevels)
    }

    private func recordButton(isRecording: Bool) -> some View {
        Button {
            Task { await toggleRecording() }
        } label: {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.accentColor)
                    .frame(width: 72, height: 72)
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
        }
        .scaleEffect(isRecording ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true),
                   value: isRecording)
    }

    // MARK: - Actions

    private func toggleRecording() async {
        switch state {
        case .idle:
            await startRecording()
        case .recording:
            await stopRecording()
        default:
            break
        }
    }

    private func startRecording() async {
        do {
            try await recorder.requestPermissions()
            try await recorder.startRecording()
            state = .recording
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func stopRecording() async {
        state = .transcribing
        do {
            let transcript = try await recorder.stopAndTranscribe()
            if transcript.trimmingCharacters(in: .whitespaces).isEmpty {
                state = .error(L10n.Voice.emptyTranscript)
            } else {
                state = .captured(transcript)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func updateWaveform() async {
        let power = await recorder.currentPower()
        // Convert dB (-60..0) to normalized 0..1
        let normalized = Float(max(0, min(1, (power + 60) / 60)))
        var levels = waveformLevels
        levels.removeFirst()
        levels.append(normalized)
        waveformLevels = levels
    }

    private func save(transcript: String) async {
        isSaving = true
        let trimmedTitle = String(transcript.prefix(60))
        let memory = MemoryItem(
            title: trimmedTitle,
            content: transcript,
            why: why.trimmingCharacters(in: .whitespaces),
            source: .userCreated
        )
        await onSave(memory)
        dismiss()
    }
}
