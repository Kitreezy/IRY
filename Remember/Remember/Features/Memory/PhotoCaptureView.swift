import SwiftUI
import PhotosUI
import AVFoundation

struct PhotoCaptureView: View {
    let onSave: (MemoryItem) async -> Void
    @Environment(\.dismiss) private var dismiss

    enum FlowState {
        case camera
        case reflecting(UIImage)
        case saving
    }

    @State private var flowState: FlowState = .camera
    @State private var camera = CameraService()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch flowState {
            case .camera:
                cameraScreen
                    .transition(.opacity)
            case .reflecting(let image):
                ReflectionScreen(
                    image: image,
                    onSave: { memory in
                        flowState = .saving
                        await onSave(memory)
                        dismiss()
                    },
                    onRetake: {
                        flowState = .camera
                    },
                    onDismiss: {
                        dismiss()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            case .saving:
                ProgressView()
                    .tint(.white)
            }
        }
        .ignoresSafeArea()
        .animation(.spring(duration: 0.4), value: flowState == .camera)
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }

    // MARK: - Camera Screen

    private var cameraScreen: some View {
        ZStack {
            // Live preview
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            // Controls overlay
            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Button {
                        camera.flipCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()

                // Bottom bar — шаттер по центру, галерея слева
                ZStack {
                    // Шаттер строго по центру
                    ShutterButton {
                        Task {
                            if let image = try? await camera.capturePhoto() {
                                withAnimation { flowState = .reflecting(image) }
                            }
                        }
                    }

                    // Галерея — левее
                    HStack {
                        LibraryPickerButton { image in
                            withAnimation { flowState = .reflecting(image) }
                        }
                        .padding(.leading, 44)
                        Spacer()
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Shutter Button

private struct ShutterButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(.white)
                    .frame(width: 60, height: 60)
                    .scaleEffect(isPressed ? 0.85 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }
            .onEnded { _ in isPressed = false }
        )
        .animation(.spring(duration: 0.15), value: isPressed)
    }
}

// MARK: - Library Picker Button

private struct LibraryPickerButton: View {
    let onPick: (UIImage) -> Void
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 26))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    onPick(image)
                }
            }
        }
    }
}

// MARK: - Reflection Screen

private struct ReflectionScreen: View {
    let image: UIImage
    let onSave: (MemoryItem) async -> Void
    let onRetake: () -> Void
    let onDismiss: () -> Void

    private enum VoiceState { case idle, recording, transcribing, done(String), failed }

    @State private var voiceState: VoiceState = .idle
    @State private var why = ""
    @State private var isSuggestingWhy = false
    @State private var recorder = VoiceRecorderService()
    @State private var waveformLevels: [Float] = Array(repeating: 0.3, count: 24)
    @State private var recordingElapsed: Double = 0

    private let maxDuration: Double = 30
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Фото на весь экран
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                // Затемнение снизу
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: geo.size.width, height: 500)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .ignoresSafeArea()

                // Контент — ширина задана явным числом (geo.size.width),
                // а не .infinity, чтобы исключить любую двусмысленность
                // в распространении размера сверху вниз по дереву.
                VStack(spacing: 0) {
                    topBar(width: geo.size.width)
                    Spacer(minLength: 12)
                    bottomPanel(width: geo.size.width)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
        .onReceive(timer) { _ in
            if case .recording = voiceState {
                recordingElapsed += 0.1
                Task { await updateWaveform() }
                if recordingElapsed >= maxDuration { Task { await stopRecording() } }
            }
        }
    }

    // MARK: - Top Bar

    private func topBar(width: CGFloat) -> some View {
        HStack {
            Button(action: onRetake) {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .frame(width: width, alignment: .leading)
    }

    // MARK: - Bottom Panel
    // No ScrollView here on purpose: content height is bounded by lineLimit/maxHeight
    // on every child, so a fixed VStack avoids ScrollView retaining a stale scroll
    // offset across state changes (which clipped/shifted content sideways).
    // Width is passed down as an explicit CGFloat (from GeometryReader), not
    // .infinity, so every descendant Text is guaranteed a bounded width to wrap
    // against instead of negotiating an ambiguous proposed size.

    private func bottomPanel(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.Photo.reflectionHint)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: width - 40, alignment: .leading)

            voicePanel
                .frame(width: width - 40, alignment: .leading)

            if case .done = voiceState { whyField(width: width) }
            if case .failed = voiceState { whyField(width: width) }

            if canSave {
                Button {
                    Task { await save() }
                } label: {
                    Text(L10n.Capture.save)
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: width - 40)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 34)
        .frame(width: width, alignment: .leading)
    }

    private var canSave: Bool {
        switch voiceState {
        case .done: return true
        case .failed: return !why.isEmpty
        default: return false
        }
    }

    // MARK: - Voice Panel

    @ViewBuilder
    private var voicePanel: some View {
        switch voiceState {
        case .idle:
            HStack(spacing: 16) {
                Button { Task { await startRecording() } } label: {
                    micButton(icon: "mic.fill", color: .white)
                }
                Text(L10n.Photo.tapToRecord)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer(minLength: 0)
            }

        case .recording:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    Button { Task { await stopRecording() } } label: {
                        micButton(icon: "stop.fill", color: .red)
                    }
                    waveform
                    Spacer(minLength: 0)
                }
                // Таймер
                let remaining = Int(maxDuration - recordingElapsed)
                Text(String(format: "0:%02d", max(0, remaining)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.leading, 72)
            }

        case .transcribing:
            HStack(spacing: 16) {
                ProgressView().tint(.white)
                Text(L10n.Voice.transcribing)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer(minLength: 0)
            }

        case .done(let transcript):
            VStack(alignment: .leading, spacing: 8) {
                if isSuggestingWhy {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text(L10n.Voice.aiSuggesting)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer(minLength: 0)
                    }
                } else {
                    // Показываем что сказал пользователь
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Voice.transcriptLabel)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Text(transcript)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

        case .failed:
            HStack(spacing: 16) {
                Button { Task { await startRecording() } } label: {
                    micButton(icon: "mic.fill", color: .white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Photo.transcriptionFailed)
                        .font(.subheadline)
                        .foregroundStyle(.red.opacity(0.9))
                    Text(L10n.Photo.tapToRetry)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func micButton(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 56, height: 56)
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
        }
        .fixedSize()
    }

    private var waveform: some View {
        HStack(spacing: 2) {
            ForEach(Array(waveformLevels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 3, height: CGFloat(max(4, level * 40)))
            }
        }
        .frame(height: 40)
        .animation(.easeInOut(duration: 0.1), value: waveformLevels)
    }

    // MARK: - Why Field

    private func whyField(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Capture.whyTitle)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.7))
            ZStack(alignment: .topLeading) {
                if why.isEmpty {
                    Text(L10n.Capture.whyPlaceholder)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(8)
                }
                TextEditor(text: $why)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.white)
                    .frame(minHeight: 80, maxHeight: 100)
                    .padding(4)
            }
            .frame(width: width - 40)
            .background(.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(width: width - 40, alignment: .leading)
    }

    // MARK: - Actions

    private func startRecording() async {
        do {
            try await recorder.requestPermissions()
            try await recorder.startRecording()
            recordingElapsed = 0
            voiceState = .recording
        } catch {
            voiceState = .idle
        }
    }

    private func stopRecording() async {
        voiceState = .transcribing
        do {
            let transcript = try await recorder.stopAndTranscribe()
            if transcript.trimmingCharacters(in: .whitespaces).isEmpty {
                voiceState = .failed
            } else {
                voiceState = .done(transcript)
                why = transcript
                await suggestWhy(transcript: transcript)
            }
        } catch {
            voiceState = .failed
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

    private func suggestWhy(transcript: String) async {
        let provider = LLMProviderService.shared.textCompletion
        guard provider.isAvailable else { return }
        isSuggestingWhy = true
        let prompt = """
        A user took a photo and recorded this voice memory: "\(transcript)"
        Rewrite it as ONE short reflective sentence (max 15 words) capturing why this moment matters.
        Reply in the same language as the input. Output only the sentence, no quotes.
        """
        if let suggestion = try? await provider.complete(prompt: prompt) {
            let trimmed = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { why = trimmed }
        }
        isSuggestingWhy = false
    }

    private func save() async {
        let transcript: String
        if case .done(let t) = voiceState { transcript = t } else { transcript = "" }

        let title = await generateTitle(from: why.isEmpty ? transcript : why)
        let path = saveImageToDisk(image)

        let memory = MemoryItem(
            title: title,
            content: transcript,
            why: why.trimmingCharacters(in: .whitespaces),
            source: .photos,
            imagePath: path
        )
        await onSave(memory)
    }

    private func generateTitle(from text: String) async -> String {
        let provider = LLMProviderService.shared.textCompletion
        guard provider.isAvailable, !text.isEmpty else {
            return String(text.prefix(50).trimmingCharacters(in: .whitespaces))
        }
        let prompt = """
        Create a SHORT title (3-6 words max) for this memory: "\(text)"
        Reply in the same language as the input. Output only the title, no quotes, no punctuation at end.
        """
        let title = (try? await provider.complete(prompt: prompt)) ?? text
        return String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
    }

    private func saveImageToDisk(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("memories")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(UUID().uuidString + ".jpg")
        try? data.write(to: url)
        return url.path
    }
}

// MARK: - FlowState Equatable для animation

extension PhotoCaptureView.FlowState: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.camera, .camera), (.saving, .saving): return true
        case (.reflecting, .reflecting): return true
        default: return false
        }
    }
}
