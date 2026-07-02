import SwiftUI
import PhotosUI

struct VoiceCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (MemoryItem) async -> Void
    @Binding var selectedDetent: PresentationDetent

    private enum CaptureState {
        case idle
        case recording
        case transcribing
        case captured
        case error(String)
    }

    private let maxDuration: Double = 30

    @State private var state: CaptureState = .idle
    @State private var capturedTranscript: String = ""
    @State private var why: String = ""
    @State private var isSaving = false
    @State private var recordingElapsed: Double = 0
    @State private var waveformLevels: [Float] = Array(repeating: 0.3, count: 20)
    @State private var attachedImage: UIImage?
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?

    private let recorder = VoiceRecorderService()
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

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
                case .captured:
                    capturedView
                case .error(let message):
                    errorView(message: message)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Capture.cancel) { dismiss() }
                }
            }
        }
        .onReceive(timer) { _ in
            guard case .recording = state else { return }
            recordingElapsed += 0.1
            Task { await updateWaveform() }
            if recordingElapsed >= maxDuration {
                Task { await stopRecording() }
            }
        }
        .sheet(isPresented: $showCamera) {
            SystemCameraPicker { image in
                attachedImage = image
            }
            .ignoresSafeArea()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    attachedImage = image
                }
                libraryItem = nil
            }
        }
    }

    // MARK: - States

    private var idleView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text(L10n.Voice.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(L10n.Voice.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            recordButton(isRecording: false)
        }
        .padding(.top, 24)
    }

    private var recordingView: some View {
        VStack(spacing: 24) {
            // Countdown
            let remaining = max(0, Int(ceil(maxDuration - recordingElapsed)))
            Text("0:\(String(format: "%02d", remaining))")
                .font(.system(size: 42, weight: .semibold, design: .monospaced))
                .foregroundStyle(remaining <= 10 ? .red : .primary)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: remaining)

            waveformView

            recordButton(isRecording: true)

            Text(L10n.Voice.stopHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    private var transcribingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(L10n.Voice.transcribing)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }

    private var capturedView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Editable transcript
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.Voice.transcriptLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $capturedTranscript)
                    .frame(minHeight: 80, maxHeight: 120)
                    .padding(6)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .font(.body)
            }

            // Why field
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.Capture.whyTitle)
                    .font(.headline)
                Text(L10n.Capture.whySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    if why.isEmpty {
                        Text(L10n.Capture.whyPlaceholder)
                            .foregroundStyle(.tertiary)
                            .padding(8)
                    }
                    TextEditor(text: $why)
                        .frame(minHeight: 100)
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))
            }

            photoAttachmentSection

            Spacer()

            Button {
                Task { await save() }
            } label: {
                if isSaving {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text(L10n.Capture.save).frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isSaving || capturedTranscript.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Photo Attachment

    @ViewBuilder
    private var photoAttachmentSection: some View {
        if let attachedImage {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: attachedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    self.attachedImage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .black.opacity(0.5))
                }
                .padding(8)
            }
        } else {
            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label(L10n.Photo.takePhoto, systemImage: "camera")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)

                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Label(L10n.Photo.choosePhoto, systemImage: "photo.on.rectangle")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
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
            Button(L10n.Voice.tryAgain) { state = .idle }
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
        case .idle: await startRecording()
        case .recording: await stopRecording()
        default: break
        }
    }

    private func startRecording() async {
        do {
            try await recorder.requestPermissions()
            try await recorder.startRecording()
            recordingElapsed = 0
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
                capturedTranscript = transcript
                selectedDetent = .large
                state = .captured
                // Try AI suggestion silently in background — no blocking loader
                Task { await suggestWhy(for: transcript) }
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func suggestWhy(for transcript: String) async {
        let provider = LLMProviderService.shared.textCompletion
        guard provider.isAvailable else { return }
        let prompt = """
        A user just recorded this memory: "\(transcript)"
        Suggest in ONE short sentence (max 15 words) why this moment might matter to them.
        Reply in the same language as the memory text.
        Be personal and specific. Output only the sentence, no quotes, no explanation.
        """
        if let suggestion = try? await provider.complete(prompt: prompt) {
            let trimmed = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                why = trimmed
            }
        }
    }

    private func updateWaveform() async {
        let power = await recorder.currentPower()
        let normalized = Float(max(0, min(1, (power + 60) / 60)))
        var levels = waveformLevels
        levels.removeFirst()
        levels.append(normalized)
        waveformLevels = levels
    }

    private func save() async {
        isSaving = true
        let transcript = capturedTranscript.trimmingCharacters(in: .whitespaces)
        let memory = MemoryItem(
            title: String(transcript.prefix(60)),
            content: transcript,
            why: why.trimmingCharacters(in: .whitespaces),
            source: .userCreated,
            imagePath: attachedImage?.saveToMemoriesDirectory()
        )
        await onSave(memory)
        dismiss()
    }
}
