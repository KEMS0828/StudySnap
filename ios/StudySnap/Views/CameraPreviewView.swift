import SwiftUI
import AVFoundation

struct CameraPreviewView: View {
    let cameraService: CameraService
    var onStart: () -> Void
    @Binding var isPresented: Bool

    private var mode: StudyMode { cameraService.selectedMode }

    var body: some View {
        ZStack {
            #if targetEnvironment(simulator)
            SimulatorCameraPlaceholder()
            #else
            if cameraService.isSessionConfigured, let session = cameraService.previewSession {
                CameraPreviewRepresentable(session: session)
                    .ignoresSafeArea()
            } else if !cameraService.permissionGranted && cameraService.isCameraAvailable {
                permissionDeniedView
            } else {
                SimulatorCameraPlaceholder()
            }
            #endif

            VStack {
                Spacer()

                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: mode.icon)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 4, y: 2)
                        Text(mode.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 4, y: 2)
                        Text("(\(mode.subtitle))")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.8), radius: 4, y: 2)
                    }

                    Text("勉強している姿が映るか確認してください")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.8), radius: 4, y: 2)

                    HStack(spacing: 12) {
                        Button {
                            cameraService.stopPreview()
                            isPresented = false
                        } label: {
                            Text("戻る")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                        }

                        Button {
                            cameraService.isTransitioningToStudy = true
                            onStart()
                        } label: {
                            Text("勉強開始")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.blue, in: .rect(cornerRadius: 12))
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(Color.black)
        .task {
            await cameraService.requestPermissionAndSetup()
            try? await Task.sleep(for: .milliseconds(300))
            cameraService.startPreview()
        }
        .onDisappear {
            if !cameraService.isTransitioningToStudy {
                cameraService.stopPreview()
            }
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("カメラへのアクセスが必要です")
                .font(.title2.bold())
            Text("設定アプリからStudySnapの\nカメラアクセスを許可してください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
    }
}

struct SimulatorCameraPlaceholder: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("カメラプレビュー")
                .font(.title2.bold())
            Text("実機にインストールすると\nカメラプレビューが表示されます")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
    }
}

struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView(session: session)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
    }
}

class CameraPreviewUIView: UIView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
        updateOrientation()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        updateOrientation()
    }

    private func updateOrientation() {
        guard let connection = previewLayer.connection else { return }
        let interfaceOrientation = window?.windowScene?.interfaceOrientation ?? .portrait
        let angle: CGFloat = switch interfaceOrientation {
        case .portrait: 90
        case .portraitUpsideDown: 270
        case .landscapeLeft: 0
        case .landscapeRight: 180
        default: 90
        }
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }
}
