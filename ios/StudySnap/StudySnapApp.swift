import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import RevenueCat
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        #if targetEnvironment(simulator)
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        #endif

        let rcKey = Config.EXPO_PUBLIC_REVENUECAT_API_KEY
        if !rcKey.isEmpty && !Purchases.isConfigured {
            #if DEBUG
            Purchases.logLevel = .debug
            #endif
            Purchases.configure(withAPIKey: rcKey)
        }

        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    nonisolated func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    nonisolated func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[APNs] Failed to register: \(error)")
    }

    nonisolated func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }

    nonisolated func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        return false
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@main
struct StudySnapApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authService: AuthenticationService = AuthenticationService()
    @State private var versionService: AppVersionService = AppVersionService()

    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    init() {
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(authService: authService)
                if case let .updateRequired(latest, current) = versionService.status {
                    ForceUpdateView(latestVersion: latest, currentVersion: current)
                        .transition(.opacity)
                }
            }
                .preferredColorScheme(appTheme.colorScheme)
                .task {
                    authService.configureIfNeeded()
                    await versionService.check()
                }
                .onOpenURL { url in
                    guard FirebaseApp.app() != nil else { return }
                    if Auth.auth().canHandle(url) {
                        return
                    }
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
