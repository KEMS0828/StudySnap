import AVFoundation
import UIKit
import CoreMotion

@Observable
class CameraService: NSObject {
    static let maxPhotosPerSession = 15
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
    private let sessionQueue = DispatchQueue(label: "cameraSessionQueue")
    private var captureTimer: Timer?
    private var currentMode: StudyMode = .normal
    private let motionManager = CMMotionManager()
    private var currentVideoRotationAngle: CGFloat = 90
    private var hasReceivedStableOrientation = false
    var isTransitioningToStudy = false
    var isLivePreviewActive = false
    private var isSessionInterrupted = false
    private var interruptionObservers: [NSObjectProtocol] = []

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

        session.commitConfiguration()

        let configuredSession = session
        let configuredOutput = output
        Task { @MainActor [weak self] in
            self?.captureSession = configuredSession
            self?.photoOutput = configuredOutput
            self?.previewSession = configuredSession
            self?.isSessionConfigured = true
            self?.registerInterruptionObservers(for: configuredSession)
        }
    }

    private func registerInterruptionObservers(for session: AVCaptureSession) {
        removeInterruptionObservers()
        let center = NotificationCenter.default
        let interruptedObserver = center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            self?.isSessionInterrupted = true
        }
        let endedObserver = center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.isSessionInterrupted = false
            if self.isRunning && !self.isPaused {
                self.scheduleNextCapture(immediate: true)
            }
        }
        let runtimeErrorObserver = center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.sessionQueue.async {
                if !session.isRunning {
                    session.startRunning()
                }
            }
        }
        interruptionObservers = [interruptedObserver, endedObserver, runtimeErrorObserver]
    }

    private func removeInterruptionObservers() {
        let center = NotificationCenter.default
        for observer in interruptionObservers {
            center.removeObserver(observer)
        }
        interruptionObservers = []
    }

    deinit {
        let observers = interruptionObservers
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
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
        isPaused = false
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
        stopOrientationTracking()
        guard !isSimulator else { return }
        if let session = captureSession {
            sessionQueue.async {
                session.stopRunning()
            }
        }
    }

    func pauseCapturing() {
        guard isRunning else { return }
        isPaused = true
        captureTimer?.invalidate()
        captureTimer = nil
    }

    func resumeCapturing() {
        guard isRunning else { return }
        isPaused = false
        scheduleNextCapture(immediate: false)
    }

    func ensureCapturingScheduled() {
        guard isRunning, !isPaused, !isSimulator else { return }
        if captureTimer == nil || !(captureTimer?.isValid ?? false) {
            scheduleNextCapture(immediate: true)
        }
    }

    private func scheduleNextCapture(immediate: Bool = false) {
        guard isRunning, !isPaused, !isSimulator else { return }
        captureTimer?.invalidate()
        captureTimer = nil
        let interval = immediate ? min(2.0, currentMode.randomInterval()) : currentMode.randomInterval()
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning, !self.isPaused else { return }
                self.capturePhoto()
                self.scheduleNextCapture()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        captureTimer = timer
    }

    private func capturePhoto() {
        guard !isSimulator else { return }
        guard let session = captureSession, let output = photoOutput else { return }
        let delegate = self
        let rotationAngle = currentVideoRotationAngle
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
