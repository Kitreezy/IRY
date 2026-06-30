import AVFoundation
import UIKit

@Observable
final class CameraService: NSObject, @unchecked Sendable {
    var capturedImage: UIImage? = nil
    var isSessionRunning = false
    var error: String? = nil

    private(set) var session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentPosition: AVCaptureDevice.Position = .back
    private var continuation: CheckedContinuation<UIImage, Error>?

    // MARK: - Setup

    func start() async {
        guard await requestPermission() else {
            error = "Camera access denied."
            return
        }
        setupSession()
        await startSession()
    }

    func stop() {
        Task.detached { [session] in
            session.stopRunning()
        }
    }

    // MARK: - Capture

    func capturePhoto() async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Flip

    func flipCamera() {
        currentPosition = currentPosition == .back ? .front : .back
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        addCameraInput()
        session.commitConfiguration()
    }

    // MARK: - Private

    private func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        addCameraInput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
    }

    private func addCameraInput() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
    }

    private func startSession() async {
        await Task.detached { [session] in
            session.startRunning()
        }.value
        isSessionRunning = true
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            continuation?.resume(throwing: error)
        } else if let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) {
            continuation?.resume(returning: image)
        } else {
            continuation?.resume(throwing: CameraError.captureFailed)
        }
        continuation = nil
    }
}

enum CameraError: Error {
    case captureFailed
}
