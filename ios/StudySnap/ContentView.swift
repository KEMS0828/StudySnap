import SwiftUI

struct ContentView: View {
    let authService: AuthenticationService
    @State private var dataStore = DataStore()
    @State private var store = StoreViewModel()
    @State private var selectedTab = 0
    @State private var isConfigured = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .transition(.opacity)
            } else if !authService.isInitialized {
                splashView
            } else if authService.isAuthenticated {
                if isConfigured && dataStore.currentUser?.isProfileCompleted == false {
                    ProfileSetupView(dataStore: dataStore)
                        .transition(.move(edge: .trailing))
                } else {
                    TabView(selection: $selectedTab) {
                        Tab("タイムライン", systemImage: "rectangle.stack.fill", value: 0) {
                            TimelineView(dataStore: dataStore, store: store)
                        }

                        Tab("レポート", systemImage: "chart.bar.fill", value: 1) {
                            ReportView(dataStore: dataStore)
                        }

                        Tab("目標", systemImage: "target", value: 2) {
                            GoalsView(dataStore: dataStore)
                        }

                        Tab("設定", systemImage: "gearshape.fill", value: 3) {
                            SettingsView(dataStore: dataStore, authService: authService, store: store)
                        }
                        .badge(dataStore.pendingMemberCount)
                    }
                }
            } else {
                LoginView(authService: authService)
            }
        }
        .animation(.default, value: authService.isAuthenticated)
        .animation(.default, value: dataStore.currentUser?.isProfileCompleted)
        .task(id: authService.currentCredentials?.userId) {
            guard let credentials = authService.currentCredentials else { return }
            dataStore.configure(
                authUserId: credentials.userId,
                displayName: credentials.displayName
            )
            isConfigured = true
            store.startIfNeeded()
        }
        .onChange(of: authService.isAuthenticated) { _, newValue in
            if !newValue {
                dataStore.reset()
                isConfigured = false
                selectedTab = 0
            }
        }
        .onChange(of: authService.currentCredentials?.userId) { _, newUserId in
            guard let _ = newUserId, let credentials = authService.currentCredentials else { return }
            if dataStore.currentUser == nil || isConfigured == false {
                dataStore.configure(
                    authUserId: credentials.userId,
                    displayName: credentials.displayName
                )
                isConfigured = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && isConfigured {
                dataStore.refreshTimeline()
            }
        }
        .alert("エラー", isPresented: Binding(
            get: { dataStore.generalError != nil },
            set: { if !$0 { dataStore.generalError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dataStore.generalError ?? "")
        }
        .alert("グループから退会させられました", isPresented: Binding(
            get: { dataStore.wasKickedFromGroup },
            set: { if !$0 { dataStore.wasKickedFromGroup = false } }
        )) {
            Button("OK", role: .cancel) {
                selectedTab = 0
            }
        } message: {
            Text("管理者によりグループから退会させられました。新しいグループを探してください。")
        }
    }

    private var splashView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
