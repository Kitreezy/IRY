import Foundation
import AVFoundation
import Speech

// MARK: - Errors

enum VoiceRecorderError: Error, LocalizedError {
    case permissionDenied
    case speechRecognitionUnavailable
    case recordingFailed
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Microphone or speech recognition access is denied."
        case .speechRecognitionUnavailable: "Speech recognition is not available on this device."
        case .recordingFailed: "Recording failed to start."
        case .transcriptionFailed: "Could not transcribe the recording."
        }
    }
}

// MARK: - Service

actor VoiceRecorderService {
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private(set) var isRecording = false

    // MARK: - Permissions

    func requestPermissions() async throws {
        let micStatus = await AVAudioApplication.requestRecordPermission()
        guard micStatus else { throw VoiceRecorderError.permissionDenied }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { throw VoiceRecorderError.permissionDenied }
    }

    // MARK: - Recording

    func startRecording() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)

        guard let recorder = try? AVAudioRecorder(url: url, settings: settings) else {
            throw VoiceRecorderError.recordingFailed
        }
        recorder.isMeteringEnabled = true
        recorder.record()

        audioRecorder = recorder
        recordingURL = url
        isRecording = true
    }

    func currentPower() -> Float {
        guard let recorder = audioRecorder, isRecording else { return -60 }
        recorder.updateMeters()
        return recorder.averagePower(forChannel: 0)
    }

    func stopAndTranscribe() async throws -> (transcript: String, audioPath: String?) {
        guard let recorder = audioRecorder, let url = recordingURL else {
            throw VoiceRecorderError.recordingFailed
        }

        recorder.stop()
        isRecording = false
        audioRecorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)

        let transcript = try await transcribe(url: url)
        let audioPath = persistRecording(at: url)
        return (transcript, audioPath)
    }

    // MARK: - Persistence

    private func persistRecording(at tempURL: URL) -> String? {
        MemoryMediaStore.copy(from: tempURL, subdirectory: "memories/audio", fileExtension: "m4a")
    }

    // MARK: - Transcription

    private func transcribe(url: URL) async throws -> String {
        let candidates = ["ru-RU", "en-US"]
            .compactMap { SFSpeechRecognizer(locale: Locale(identifier: $0)) }
            .filter { $0.isAvailable }

        guard !candidates.isEmpty else {
            throw VoiceRecorderError.speechRecognitionUnavailable
        }

        // Try each recognizer, pick the longest non-empty result
        var collected: [String] = []
        for recognizer in candidates {
            if let text = try? await recognize(with: recognizer, url: url),
               !text.trimmingCharacters(in: .whitespaces).isEmpty {
                collected.append(text)
            }
        }

        guard let best = collected.max(by: { $0.count < $1.count }) else {
            throw VoiceRecorderError.transcriptionFailed
        }
        return best
    }

    private func recognize(with recognizer: SFSpeechRecognizer, url: URL) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if let error {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
