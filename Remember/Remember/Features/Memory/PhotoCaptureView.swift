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

                // Bottom bar
                HStack(alignment: .center, spacing: 0) {
                    // Library picker
                    LibraryPickerButton { image in
                        withAnimation { flowState = .reflecting(image) }
                    }
                    .frame(maxWidth: .infinity)

                    // Shutter
                    ShutterButton {
                        Task {
                            if let image = try? await camera.capturePhoto() {
                                withAnimation { flowState = .reflecting(image) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Placeholder для симметрии
                    Color.clear.frame(maxWidth: .infinity)
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

    private enum VoiceState { case idle, recording, transcribing, done(String) }

    @State private var voiceState: VoiceState = .idle
    @State private var why = ""
    @State private var isSuggestingWhy = false
    @State private var recorder = VoiceRecorderService()
    @State private var waveformLevels: [Float] = Array(repeating: 0.3, count: 24)
    @State private var recordingElapsed: Double = 0

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Фото на весь экран с blur
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Затемнение снизу
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 420)
            }
            .ignoresSafeArea()

            // Контент поверх
            VStack(spacing: 0) {
                // Кнопка "переснять"
                HStack {
                    Button {
                        onRetake()
                    } label: {
                        Image(systemName: "arrow.uturn.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()

                // Нижняя панель
                VStack(alignment: .leading, spacing: 16) {
                    // Подсказка
                    Text(L10n.Photo.reflectionHint)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    // Голосовое состояние
                    voicePanel

                    // Поле why (появляется после транскрипции)
                    if case .done = voiceState {
                        whyField
                    }

                    // Кнопка сохранить
                    if case .done = voiceState {
                        Button {
                            Task { await save() }
                        } label: {
                            Text(L10n.Capture.save)
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
        .onReceive(timer) { _ in
            if case .recording = voiceState {
                recordingElapsed += 0.1
                Task { await updateWaveform() }
                if recordingElapsed >= 30 { Task { await stopRecording() } }
            }
        }
    }

    // MARK: - Voice Panel

    @ViewBuilder
    private var voicePanel: some View {
        HStack(spacing: 16) {
            switch voiceState {
            case .idle:
                Button { Task { await startRecording() } } label: {
                    micButton(icon: "mic.fill", color: .white)
                }
                Text(L10n.Photo.tapToRecord)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

            case .recording:
                Button { Task { await stopRecording() } } label: {
                    micButton(icon: "stop.fill", color: .red)
                }
                waveform

            case .transcribing:
                ProgressView().tint(.white)
                Text(L10n.Voice.transcribing)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

            case .done:
                if isSuggestingWhy {
                    ProgressView().tint(.white)
                    Text(L10n.Voice.aiSuggesting)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
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

    private var whyField: some View {
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
                    .frame(minHeight: 80, maxHeight: 120)
                    .padding(4)
            }
            .background(.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
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
            voiceState = .done(transcript)
            why = transcript
            await suggestWhy(transcript: transcript)
        } catch {
            voiceState = .idle
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
