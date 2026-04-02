import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage: Int = 0
    @State private var direction: NavigationDirection = .forward

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "camera.fill",
            iconColor: .indigo,
            title: "勉強をランダム撮影",
            description: "勉強中にランダムな間隔で\n自動的に写真を撮影します。"
        ),
        OnboardingPage(
            icon: "wand.and.stars",
            iconColor: .mint,
            title: "加工して投稿",
            description: "撮った写真の個人情報を見せないように\n加工して、グループに投稿しよう。"
        ),
        OnboardingPage(
            icon: "checkmark.seal.fill",
            iconColor: .teal,
            title: "承認で勉強時間に加算",
            description: "メンバーからの承認で\n勉強時間が記録されます。"
        ),
        OnboardingPage(
            icon: "person.3.fill",
            iconColor: .blue,
            title: "グループで一緒に頑張る",
            description: "仲間とグループを作って勉強を共有。\nお互いの投稿を承認し合うことで\nモチベーションもアップ。"
        ),
        OnboardingPage(
            icon: "chart.bar.xaxis.ascending",
            iconColor: .orange,
            title: "目標を立てて振り返る",
            description: "日・週ごとの目標設定とレポートで\n勉強習慣を可視化。\n成長を実感できます。"
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color.indigo.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    ForEach(pages.indices, id: \.self) { index in
                        if index == currentPage {
                            pageContent(pages[index])
                                .transition(pageTransition)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                pageIndicator
                    .padding(.bottom, 20)

                bottomButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: direction == .forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: direction == .forward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func goForward() {
        direction = .forward
        withAnimation(.spring(duration: 0.4, bounce: 0.1)) {
            currentPage += 1
        }
    }

    private func goBack() {
        direction = .backward
        withAnimation(.spring(duration: 0.4, bounce: 0.1)) {
            currentPage -= 1
        }
    }

    private func pageContent(_ page: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.1))
                    .frame(width: 140, height: 140)

                Image(systemName: page.icon)
                    .font(.system(size: 56))
                    .foregroundStyle(page.iconColor)
                    .symbolEffect(.pulse, options: .repeating.speed(0.4))
            }
            .padding(.bottom, 8)

            Text(page.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.indigo : Color.indigo.opacity(0.2))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(duration: 0.3), value: currentPage)
            }
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        VStack(spacing: 16) {
            if currentPage == pages.count - 1 {
                Button {
                    withAnimation {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text("はじめる")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
            } else {
                Button {
                    goForward()
                } label: {
                    Text("次へ")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
            }

            if currentPage > 0 {
                Button {
                    goBack()
                } label: {
                    Text("戻る")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private enum NavigationDirection {
    case forward, backward
}

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}
