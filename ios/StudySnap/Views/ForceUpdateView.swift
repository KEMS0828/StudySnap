import SwiftUI
import UIKit

struct ForceUpdateView: View {
    let latestVersion: String
    let currentVersion: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.12),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 120, height: 120)
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 72, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                    VStack(spacing: 12) {
                        Text("新しいバージョンが利用可能です")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text("最新の機能と改善をご利用いただくには、App Storeから最新バージョンにアップデートしてください。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)

                    HStack(spacing: 16) {
                        VersionBadge(label: "現在", value: currentVersion, tint: .secondary)
                        Image(systemName: "arrow.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        VersionBadge(label: "最新", value: latestVersion, tint: .blue)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        UIApplication.shared.open(AppVersionService.appStoreURL)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.app.fill")
                            Text("App Storeでアップデート")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 14))
                    }

                    Text("StudySnap")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .interactiveDismissDisabled(true)
    }
}

private struct VersionBadge: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(minWidth: 80)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 10))
    }
}
