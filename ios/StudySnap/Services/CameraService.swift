import AVFoundation
import UIKit
import CoreMotion
import CoreImage

@Observable
class CameraService: NSObject {
    static let maxPhotosPerSession = 15
    static let outdoorModeStorageKey = "outdoorModeEnabled"
    var capturedPhotos: [Data] = []
    var isRunning = false
    var isPaused = false
    var didReachPhotoLimit = false
    var previewSession: AVCaptureSession?
    var isSessionConfigured = false
    var permissionGranted = false
    var selectedMode: StudyMode = .normal

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private let videoQueue = DispatchQueue(label: "cameraVideoQueue")
    private var pendingSilentCapture = false
    private let sessionQueue = DispatchQueue(label: "cameraSessionQueue")
    private var captureTimer: Timer?
    private var currentMode: StudyMode = .normal
    private var scheduledFireDate: Date?
    private var pausedRemainingInterval: TimeInterval?
    private let motionManager = CMMotionManager()
    private var currentVideoRotationAngle: CGFloat = 90
    private var hasReceivedStableOrientation = false
    var isTransitioningToStudy = false
    var isLivePreviewActive = false

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    var isCameraAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return AVCaptureDevice.default(for: .video) != nil
        #endif
    }

    func requestPermissionAndSetup() async {
        guard !isSimulator else { return }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            permissionGranted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            permissionGranted = false
            return
        }

        guard permissionGranted, !isSessionConfigured else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                self?.configureSession()
                continuation.resume()
            }
        }
    }

    private func configureSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()

        let configuredSession = session
        let configuredOutput = output
        let configuredVideoOutput = videoOutput
        Task { @MainActor [weak self] in
            guard let self else { return }
            configuredVideoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
            self.captureSession = configuredSession
            self.photoOutput = configuredOutput
            self.videoDataOutput = configuredVideoOutput
            self.previewSession = configuredSession
            self.isSessionConfigured = true
        }
    }

    func startPreview() {
        guard !isSimulator else { return }
        guard let session = captureSession else { return }
        sessionQueue.async {
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stopPreview() {
        guard !isSimulator else { return }
        guard let session = captureSession else { return }
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func startCapturing(mode: StudyMode) {
        currentMode = mode
        capturedPhotos = []
        didReachPhotoLimit = false
        isRunning = true
        startOrientationTracking()

        guard !isSimulator else { return }
        guard captureSession != nil, photoOutput != nil else { return }

        if let session = captureSession, session.isRunning {
            sessionQueue.async {
                session.stopRunning()
            }
        }

        isTransitioningToStudy = false
        scheduleNextCapture()
    }

    func stopCapturing() {
        isRunning = false
        isPaused = false
        captureTimer?.invalidate()
        captureTimer = nil
        scheduledFireDate = nil
        pausedRemainingInterval = nil
        stopOrientationTracking()
        guard !isSimulator else { return }
        if let session = captureSession {
            sessionQueue.async {
                session.stopRunning()
            }
        }
    }

    func pauseCapturing() {
        guard isRunning, !isPaused else { return }
        isPaused = true
        if let fireDate = scheduledFireDate {
            let remaining = fireDate.timeIntervalSinceNow
            pausedRemainingInterval = max(0, remaining)
        }
        captureTimer?.invalidate()
        captureTimer = nil
    }

    func resumeCapturing() {
        guard isRunning, isPaused else { return }
        isPaused = false
        if let remaining = pausedRemainingInterval {
            pausedRemainingInterval = nil
            scheduleCapture(after: remaining)
        } else {
            scheduleNextCapture()
        }
    }

    private func scheduleNextCapture() {
        let interval = currentMode.randomInterval()
        scheduleCapture(after: interval)
    }

    private func scheduleCapture(after interval: TimeInterval) {
        guard isRunning, !isPaused, !isSimulator else { return }
        captureTimer?.invalidate()
        let effectiveInterval = max(0.1, interval)
        scheduledFireDate = Date().addingTimeInterval(effectiveInterval)
        let timer = Timer(timeInterval: effectiveInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning, !self.isPaused else { return }
                self.scheduledFireDate = nil
                self.capturePhoto()
                self.scheduleNextCapture()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        captureTimer = timer
    }

    private func capturePhoto() {
        guard !isSimulator else { return }
        guard let session = captureSession else { return }
        let isOutdoorMode = UserDefaults.standard.bool(forKey: Self.outdoorModeStorageKey)
        let rotationAngle = currentVideoRotationAngle

        if isOutdoorMode, let videoOutput = videoDataOutput {
            sessionQueue.async { [weak self] in
                guard let self else { return }
                if !session.isRunning {
                    session.startRunning()
                }
                Thread.sleep(forTimeInterval: 0.5)
                if let connection = videoOutput.connection(with: .video),
                   connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                }
                Task { @MainActor [weak self] in
                    self?.pendingSilentCapture = true
                }
            }
            return
        }

        guard let output = photoOutput else { return }
        let delegate = self
        sessionQueue.async {
            session.startRunning()
            Thread.sleep(forTimeInterval: 0.5)
            if let connection = output.connection(with: .video),
               connection.isVideoRotationAngleSupported(rotationAngle) {
                connection.videoRotationAngle = rotationAngle
            }
            let settings = AVCapturePhotoSettings()
            output.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func startOrientationTracking() {
        guard motionManager.isAccelerometerAvailable else { return }
        hasReceivedStableOrientation = false
        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let x = data.acceleration.x
            let y = data.acceleration.y
            let threshold: Double = 0.3
            guard max(abs(x), abs(y)) > threshold else {
                return
            }
            self.hasReceivedStableOrientation = true
            if abs(y) > abs(x) {
                self.currentVideoRotationAngle = y < 0 ? 90 : 270
            } else {
                self.currentVideoRotationAngle = x < 0 ? 180 : 0
            }
        }
    }

    private func stopOrientationTracking() {
        motionManager.stopAccelerometerUpdates()
    }

    private func stopSessionAfterCapture() {
        guard let session = captureSession else { return }
        if isLivePreviewActive { return }
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func startLivePreview() {
        guard !isSimulator else { return }
        guard let session = captureSession else { return }
        isLivePreviewActive = true
        sessionQueue.async {
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stopLivePreview() {
        isLivePreviewActive = false
        guard !isSimulator else { return }
        guard let session = captureSession else { return }
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task { @MainActor [weak self] in
            guard let self, self.pendingSilentCapture else { return }
            self.pendingSilentCapture = false
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            let uiImage = UIImage(cgImage: cgImage)
            guard let data = uiImage.jpegData(compressionQuality: 0.9) else { return }
            self.capturedPhotos.append(data)
            self.stopSessionAfterCapture()
            if self.capturedPhotos.count >= Self.maxPhotosPerSession {
                self.didReachPhotoLimit = true
                self.stopCapturing()
            }
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        let normalizedData = Self.normalizeImageOrientation(data)
        Task { @MainActor in
            self.capturedPhotos.append(normalizedData)
            self.stopSessionAfterCapture()
            if self.capturedPhotos.count >= Self.maxPhotosPerSession {
                self.didReachPhotoLimit = true
                self.stopCapturing()
            }
        }
    }

    nonisolated static func normalizeImageOrientation(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        if image.imageOrientation == .up {
            return data
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return normalized.jpegData(compressionQuality: 0.9) ?? data
    }
}
