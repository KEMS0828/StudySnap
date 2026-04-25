import SwiftUI
import UIKit

struct StudyingView: View {
    let cameraService: CameraService
    let store: StoreViewModel
    let todayShootingTime: TimeInterval
    var onFinish: (TimeInterval) -> Void

    private var isPremium: Bool { store.isPremium }

    private var mode: StudyMode { cameraService.selectedMode }
    private let freeDailyLimit: TimeInterval = 1 * 3600

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var startTime: Date = .now
    @State private var accumulatedTime: TimeInterval = 0
    @State private var photoCount: Int = 0
    @State private var showStopConfirm = false
    @State private var showPhotoLimitAlert = false
    @State private var showDailyLimitPaywall = false
    @State private var showDailyLimitAlert = false
    @State private var pulseAnimation = false
    @State private var isPaused = false
    @State private var showMiniPreview = false

    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack {
            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .overlay(alignment: isLandscape ? .topLeading : .bottomTrailing) {
            if showMiniPreview {
                miniPreviewCard
                    .padding(.leading, isLandscape ? 16 : 0)
                    .padding(.top, isLandscape ? 16 : 0)
                    .padding(.trailing, isLandscape ? 0 : 16)
                    .padding(.bottom, isLandscape ? 0 : 180)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.6, anchor: isLandscape ? .topLeading : .bottomTrailing).combined(with: .opacity),
                        removal: .scale(scale: 0.6, anchor: isLandscape ? .topLeading : .bottomTrailing).combined(with: .opacity)
                    ))
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            startTime = .now
            accumulatedTime = 0
            pulseAnimation = true
            startTimer()
            cameraService.startCapturing(mode: mode)
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            stopTimer()
            UIApplication.shared.isIdleTimerDisabled = false
            if showMiniPreview {
                cameraService.stopLivePreview()
                showMiniPreview = false
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                if !isPaused {
                    withAnimation(.spring(duration: 0.35)) {
                        pause()
                    }
                }
            }
        }
        .onChange(of: cameraService.capturedPhotos.count) { _, newCount in
            withAnimation(.spring(duration: 0.3)) {
                photoCount = newCount
            }
        }
        .onChange(of: cameraService.didReachPhotoLimit) { _, reached in
            if reached {
                if !isPaused {
                    withAnimation(.spring(duration: 0.35)) {
                        pause()
                    }
                }
                showPhotoLimitAlert = true
            }
        }
        .alert("撮影上限", isPresented: $showPhotoLimitAlert) {
            Button("OK") {
                stopStudy()
            }
        } message: {
            Text("一回のセッションでの撮影上限枚数に到達しました。")
        }
        .alert("本日の無料勉強時間が終了しました", isPresented: $showDailyLimitAlert) {
            Button("プランを見る") {
                showDailyLimitPaywall = true
            }
        } message: {
            Text("無料プランでは1日の勉強時間に制限があります。プレミアムにアップグレードすると無制限に勉強できます。")
        }
        .sheet(isPresented: $showDailyLimitPaywall, onDismiss: {
            if !store.isPremium {
                stopStudy()
            } else {
                withAnimation(.spring(duration: 0.35)) {
                    resume()
                }
            }
        }) {
            StudySnapPaywallView(store: store, dailyUsedTime: todayShootingTime + elapsedTime)
                .interactiveDismissDisabled()
        }
        .confirmationDialog("勉強を終了しますか？", isPresented: $showStopConfirm, titleVisibility: .visible) {
            Button("終了する", role: .destructive) {
                stopStudy()
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private var menuButton: some View {
        Menu {
            Button {
                withAnimation(.spring(duration: 0.4)) {
                    showMiniPreview = true
                }
                cameraService.startLivePreview()
            } label: {
                Label("写りを確認", systemImage: "camera.viewfinder")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(Color(.secondarySystemGroupedBackground), in: .circle)
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: isPaused ? "pause.circle.fill" : "book.and.wrench.fill")
                .font(.system(size: isLandscape ? 36 : 44))
                .foregroundStyle(isPaused ? Color.orange : Color.accentColor)
                .symbolEffect(.pulse, options: .repeating, isActive: !isPaused)
                .contentTransition(.symbolEffect(.replace))

            Text(isPaused ? "一時停止中" : "勉強中...")
                .font(.title3)
                .foregroundStyle(isPaused ? .orange : .secondary)
                .contentTransition(.numericText())
        }
    }

    private var timerText: some View {
        Text(formattedTime)
            .font(.system(size: isLandscape ? 48 : 64, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
            .opacity(isPaused ? 0.5 : 1.0)
    }

    private var statsCards: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Image(systemName: "camera.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("\(photoCount)")
                    .font(.title2.bold())
                Text("撮影枚数")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))

            VStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(mode.title)
                    .font(.title3.bold())
                Text("モード")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.35)) {
                    togglePause()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    Text(isPaused ? "再開" : "一時停止")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(isPaused ? .blue : .orange)
            .controlSize(.large)

            Button {
                showStopConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                    Text("勉強終了")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
    }

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                menuButton
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 32) {
                statusHeader
                timerText
                statsCards
                    .padding(.horizontal)
            }

            Spacer()

            actionButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }

    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                menuButton
            }
            .padding(.horizontal)
            .padding(.top, 4)

            HStack(alignment: .center, spacing: 24) {
                VStack(spacing: 16) {
                    statusHeader
                    timerText
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 12) {
                    statsCards
                    actionButtons
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private var miniPreviewCard: some View {
        let width: CGFloat = isLandscape ? 200 : 150
        let height: CGFloat = isLandscape ? width * 9 / 16 : width * 16 / 9
        ZStack {
            Color.black
            #if targetEnvironment(simulator)
            VStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                Text("プレビュー")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            #else
            if let session = cameraService.previewSession {
                CameraPreviewRepresentable(session: session)
            } else {
                ProgressView()
                    .tint(.white)
            }
            #endif
        }
        .frame(width: width, height: height)
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 6)
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.spring(duration: 0.35)) {
                    showMiniPreview = false
                }
                cameraService.stopLivePreview()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.6), in: .circle)
            }
            .padding(6)
        }
    }

    private var formattedTime: String {
        let total = Int(elapsedTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startTimer() {
        startTime = .now
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            withAnimation(.linear(duration: 0.3)) {
                elapsedTime = accumulatedTime + Date.now.timeIntervalSince(startTime)
            }
            if !isPremium {
                let totalToday = todayShootingTime + elapsedTime
                if totalToday >= freeDailyLimit {
                    Task { @MainActor in
                        if !isPaused {
                            withAnimation(.spring(duration: 0.35)) {
                                pause()
                            }
                        }
                        showDailyLimitAlert = true
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }

    private func pause() {
        guard !isPaused else { return }
        isPaused = true
        accumulatedTime += Date.now.timeIntervalSince(startTime)
        stopTimer()
        cameraService.pauseCapturing()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func resume() {
        guard isPaused else { return }
        isPaused = false
        startTimer()
        cameraService.resumeCapturing()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func closeMiniPreviewIfNeeded() {
        if showMiniPreview {
            cameraService.stopLivePreview()
            showMiniPreview = false
        }
    }

    private func stopStudy() {
        let finalTime: TimeInterval
        if isPaused {
            finalTime = accumulatedTime
        } else {
            finalTime = accumulatedTime + Date.now.timeIntervalSince(startTime)
        }
        stopTimer()
        closeMiniPreviewIfNeeded()
        cameraService.stopCapturing()
        onFinish(finalTime)
    }
}
