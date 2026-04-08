import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import CryptoKit

nonisolated enum AuthProvider: String, Codable, Sendable {
    case google
    case email
    case apple
}

nonisolated struct AuthCredentials: Codable, Sendable {
    let provider: AuthProvider
    let userId: String
    let email: String?
    let displayName: String?
}

@Observable
class AuthenticationService {
    var isAuthenticated: Bool = false
    var isInitialized: Bool = false
    var currentCredentials: AuthCredentials?
    var isLoading: Bool = false
    var errorMessage: String?
    var signUpSuccessMessage: String?
    var passwordResetSent: Bool = false

    private let credentialsKey = "auth_credentials"
    private let isAuthenticatedKey = "is_authenticated"
    private var currentNonce: String?
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var isConfigured: Bool = false

    init() {
    }

    func configureIfNeeded() {
        guard !isConfigured else { return }
        guard FirebaseApp.app() != nil else { return }
        isConfigured = true
        restoreSession()
        startAuthStateListener()
        isInitialized = true
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    private func restoreSession() {
        guard FirebaseApp.app() != nil else { return }
        guard let firebaseUser = Auth.auth().currentUser else { return }
        let credentials = credentialsFromFirebaseUser(firebaseUser)
        currentCredentials = credentials
        isAuthenticated = true
    }

    private func startAuthStateListener() {
        guard FirebaseApp.app() != nil else { return }
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let credentials = user.map { self?.credentialsFromFirebaseUser($0) } ?? nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let credentials {
                    if self.currentCredentials?.userId != credentials.userId || !self.isAuthenticated {
                        self.currentCredentials = credentials
                        self.isAuthenticated = true
                    }
                } else {
                    if self.isAuthenticated {
                        self.currentCredentials = nil
                        self.isAuthenticated = false
                    }
                }
            }
        }
    }

    private func credentialsFromFirebaseUser(_ firebaseUser: User) -> AuthCredentials {
        let provider: AuthProvider
        if firebaseUser.providerData.contains(where: { $0.providerID == "apple.com" }) {
            provider = .apple
        } else if firebaseUser.providerData.contains(where: { $0.providerID == "google.com" }) {
            provider = .google
        } else {
            provider = .email
        }
        return AuthCredentials(
            provider: provider,
            userId: firebaseUser.uid,
            email: firebaseUser.email,
            displayName: firebaseUser.displayName
        )
    }

    func ensureValidToken() async {
        guard let user = Auth.auth().currentUser else { return }
        do {
            let _ = try await user.getIDTokenResult(forcingRefresh: true)
        } catch {
            print("[AuthService] Token refresh failed: \(error.localizedDescription)")
        }
    }

    private func saveCredentials(_ credentials: AuthCredentials) {
        currentCredentials = credentials
        isAuthenticated = true
    }

    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase設定エラーが発生しました"
            isLoading = false
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "画面の取得に失敗しました"
            isLoading = false
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let error {
                    let nsError = error as NSError
                    if nsError.code == GIDSignInError.canceled.rawValue {
                        self.isLoading = false
                        return
                    }
                    self.errorMessage = "Googleサインインに失敗しました"
                    self.isLoading = false
                    return
                }

                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.errorMessage = "Googleサインインに失敗しました"
                    self.isLoading = false
                    return
                }

                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: user.accessToken.tokenString
                )

                do {
                    let authResult = try await Auth.auth().signIn(with: credential)
                    let credentials = AuthCredentials(
                        provider: .google,
                        userId: authResult.user.uid,
                        email: authResult.user.email,
                        displayName: authResult.user.displayName
                    )
                    self.saveCredentials(credentials)
                    self.isLoading = false
                } catch {
                    self.errorMessage = self.firebaseErrorMessage(error)
                    self.isLoading = false
                }
            }
        }
    }

    func signUpWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        signUpSuccessMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください"
            isLoading = false
            return
        }

        guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
            errorMessage = "有効なメールアドレスを入力してください"
            isLoading = false
            return
        }

        guard trimmedPassword.count >= 6 else {
            errorMessage = "パスワードは6文字以上にしてください"
            isLoading = false
            return
        }

        do {
            let authResult = try await Auth.auth().createUser(withEmail: trimmedEmail, password: trimmedPassword)
            let credentials = AuthCredentials(
                provider: .email,
                userId: authResult.user.uid,
                email: trimmedEmail,
                displayName: nil
            )
            saveCredentials(credentials)
        } catch {
            errorMessage = firebaseErrorMessage(error)
        }
        isLoading = false
    }

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください"
            isLoading = false
            return
        }

        guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
            errorMessage = "有効なメールアドレスを入力してください"
            isLoading = false
            return
        }

        guard trimmedPassword.count >= 6 else {
            errorMessage = "パスワードは6文字以上にしてください"
            isLoading = false
            return
        }

        do {
            let authResult = try await Auth.auth().signIn(withEmail: trimmedEmail, password: trimmedPassword)
            let credentials = AuthCredentials(
                provider: .email,
                userId: authResult.user.uid,
                email: trimmedEmail,
                displayName: authResult.user.displayName
            )
            saveCredentials(credentials)
        } catch {
            errorMessage = firebaseErrorMessage(error)
        }
        isLoading = false
    }

    func sendPasswordReset(email: String) async {
        isLoading = true
        errorMessage = nil
        passwordResetSent = false

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedEmail.isEmpty else {
            errorMessage = "メールアドレスを入力してください"
            isLoading = false
            return
        }

        guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
            errorMessage = "有効なメールアドレスを入力してください"
            isLoading = false
            return
        }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: trimmedEmail)
            passwordResetSent = true
        } catch {
            errorMessage = firebaseErrorMessage(error)
        }
        isLoading = false
    }

    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        guard let nonce = randomNonceString() else {
            errorMessage = "セキュリティトークンの生成に失敗しました。もう一度お試しください。"
            isLoading = false
            return
        }
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let authorization):
                    self.handleAppleAuthorization(authorization)
                case .failure(let error):
                    let nsError = error as NSError
                    if nsError.domain == ASAuthorizationError.errorDomain,
                       nsError.code == ASAuthorizationError.canceled.rawValue {
                        self.isLoading = false
                        return
                    }
                    print("[AppleSignIn] ASAuthorization error: \(error.localizedDescription) (domain: \(nsError.domain), code: \(nsError.code))")
                    self.errorMessage = "Appleサインインに失敗しました: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
        controller.delegate = delegate
        self.appleSignInDelegate = delegate
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let provider = ApplePresentationProvider(window: window)
            self.applePresentationProvider = provider
            controller.presentationContextProvider = provider
        }
        controller.performRequests()
    }

    private var appleSignInDelegate: AppleSignInDelegate?
    private var applePresentationProvider: ApplePresentationProvider?

    private func handleAppleAuthorization(_ authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("[AppleSignIn] credential is not ASAuthorizationAppleIDCredential")
            errorMessage = "Apple認証情報の取得に失敗しました"
            isLoading = false
            return
        }
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("[AppleSignIn] identityToken is nil")
            errorMessage = "AppleトークンIDの取得に失敗しました"
            isLoading = false
            return
        }
        guard let nonce = currentNonce else {
            print("[AppleSignIn] currentNonce is nil")
            errorMessage = "認証ナンスが見つかりません"
            isLoading = false
            return
        }

        let credential = OAuthProvider.credential(
            providerID: .apple,
            idToken: idTokenString,
            rawNonce: nonce,
            accessToken: nil
        )

        var displayName: String?
        if let fullName = appleIDCredential.fullName {
            let components = [fullName.familyName, fullName.givenName].compactMap { $0 }
            if !components.isEmpty {
                displayName = components.joined(separator: " ")
            }
        }

        Task {
            do {
                let authResult = try await Auth.auth().signIn(with: credential)
                if let displayName, !displayName.isEmpty {
                    let changeRequest = authResult.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try? await changeRequest.commitChanges()
                }
                let credentials = AuthCredentials(
                    provider: .apple,
                    userId: authResult.user.uid,
                    email: authResult.user.email ?? appleIDCredential.email,
                    displayName: authResult.user.displayName ?? displayName
                )
                self.saveCredentials(credentials)
                self.isLoading = false
            } catch {
                print("[AppleSignIn] Firebase signIn error: \(error.localizedDescription)")
                self.errorMessage = "Firebase認証エラー: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private func randomNonceString(length: Int = 32) -> String? {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            return nil
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {}
        currentCredentials = nil
        isAuthenticated = false
    }

    func deleteAccount(password: String? = nil) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザーが見つかりません"])
        }

        if user.providerData.contains(where: { $0.providerID == "phone" }) {
            do {
                try await user.unlink(fromProvider: "phone")
            } catch {}
        }

        do {
            try await user.delete()
        } catch {
            let nsError = error as NSError
            if nsError.domain == AuthErrorDomain,
               AuthErrorCode(rawValue: nsError.code) == .requiresRecentLogin {
                try await reauthenticateAndDelete(user: user, password: password)
            } else {
                throw error
            }
        }
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        currentCredentials = nil
        isAuthenticated = false
    }

    private func reauthenticateAndDelete(user: User, password: String?) async throws {
        let providerID = user.providerData.first?.providerID ?? ""

        if providerID == "password", let email = user.email, let pw = password, !pw.isEmpty {
            let credential = EmailAuthProvider.credential(withEmail: email, password: pw)
            try await user.reauthenticate(with: credential)
        } else if providerID == "google.com" {
            try await reauthenticateWithGoogle()
        } else if providerID == "apple.com" {
            try await reauthenticateWithApple()
        } else {
            throw NSError(domain: "AuthService", code: -2, userInfo: [NSLocalizedDescriptionKey: "アカウントを削除するにはパスワードが必要です"])
        }

        try await user.delete()
    }

    private func reauthenticateCurrentUser() async throws {
        guard let user = Auth.auth().currentUser else { return }
        let providerID = user.providerData.first?.providerID ?? ""

        if providerID == "google.com" {
            try await reauthenticateWithGoogle()
        } else if providerID == "apple.com" {
            try await reauthenticateWithApple()
        } else {
            throw NSError(domain: "AuthService", code: -2, userInfo: [NSLocalizedDescriptionKey: "再認証が必要です。一度サインアウトしてから再度サインインし、もう一度お試しください。"])
        }
    }

    private func reauthenticateWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "AuthService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Firebase設定エラー"])
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "AuthService", code: -4, userInfo: [NSLocalizedDescriptionKey: "画面の取得に失敗しました"])
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "AuthService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Google再認証に失敗しました"])
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await Auth.auth().currentUser?.reauthenticate(with: credential)
    }

    private func reauthenticateWithApple() async throws {
        guard let nonce = randomNonceString() else {
            throw NSError(domain: "AuthService", code: -7, userInfo: [NSLocalizedDescriptionKey: "セキュリティトークンの生成に失敗しました"])
        }
        let hashedNonce = sha256(nonce)

        let credential: AuthCredential = try await withCheckedThrowingContinuation { continuation in
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate { result in
                switch result {
                case .success(let authorization):
                    guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let appleIDToken = appleIDCredential.identityToken,
                          let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                        continuation.resume(throwing: NSError(domain: "AuthService", code: -6, userInfo: [NSLocalizedDescriptionKey: "Apple再認証に失敗しました"]))
                        return
                    }
                    let oauthCredential = OAuthProvider.credential(
                        providerID: .apple,
                        idToken: idTokenString,
                        rawNonce: nonce,
                        accessToken: nil
                    )
                    continuation.resume(returning: oauthCredential)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            controller.delegate = delegate
            self.appleSignInDelegate = delegate
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let provider = ApplePresentationProvider(window: window)
                self.applePresentationProvider = provider
                controller.presentationContextProvider = provider
            }
            controller.performRequests()
        }
        try await Auth.auth().currentUser?.reauthenticate(with: credential)
    }

    private func firebaseErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain else {
            return "エラーが発生しました。もう一度お試しください。"
        }
        switch AuthErrorCode(rawValue: nsError.code) {
        case .emailAlreadyInUse:
            return "このメールアドレスは既に登録されています"
        case .invalidEmail:
            return "有効なメールアドレスを入力してください"
        case .wrongPassword, .invalidCredential:
            return "メールアドレスまたはパスワードが正しくありません"
        case .userNotFound:
            return "このメールアドレスのアカウントが見つかりません"
        case .weakPassword:
            return "パスワードが弱すぎます。6文字以上にしてください"
        case .networkError:
            return "ネットワークエラーが発生しました。接続を確認してください"
        case .tooManyRequests:
            return "リクエストが多すぎます。しばらく待ってからお試しください"
        case .userDisabled:
            return "このアカウントは無効になっています"
        default:
            return "エラーが発生しました。もう一度お試しください。"
        }
    }
}
