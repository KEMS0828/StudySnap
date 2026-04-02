import SwiftUI
import FirebaseAuth

struct PhoneVerificationView: View {
    let dataStore: DataStore
    @Binding var isPresented: Bool
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var verificationID: String?
    @State private var isCodeSent: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var canResend: Bool = false
    @State private var resendCountdown: Int = 0
    private let authUIDelegate = PhoneAuthUIDelegate()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !isCodeSent {
                    phoneInputContent
                } else {
                    codeInputContent
                }
            }
            .navigationTitle(isCodeSent ? "認証コード入力" : "電話番号認証")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { isPresented = false }
                }
            }
            .alert("エラー", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var phoneInputContent: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            VStack(spacing: 12) {
                Image(systemName: "phone.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("電話番号を入力してください")
                    .font(.title3.bold())

                Text("SMSで認証コードを送信します")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("電話番号")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text("+81")
                        .font(.body.monospaced())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemBackground), in: .rect(cornerRadius: 10))

                    TextField("09012345678", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemBackground), in: .rect(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 24)

            Button {
                Task { await sendVerificationCode() }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    Text("認証コードを送信")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(phoneNumber.isEmpty || isLoading)
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var codeInputContent: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            VStack(spacing: 12) {
                Image(systemName: "ellipsis.message.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("認証コードを入力")
                    .font(.title3.bold())

                Text("SMSに届いた6桁のコードを入力してください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("123456", text: $verificationCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.title2.monospaced().bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(Color(.tertiarySystemBackground), in: .rect(cornerRadius: 10))
                .padding(.horizontal, 60)

            Button {
                Task { await verifyCode() }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    Text("認証する")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(verificationCode.count < 6 || isLoading)
            .padding(.horizontal, 24)

            if canResend {
                Button {
                    Task { await sendVerificationCode() }
                } label: {
                    Text("コードを再送信")
                        .font(.subheadline)
                }
            } else if resendCountdown > 0 {
                Text("再送信まで\(resendCountdown)秒")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                isCodeSent = false
                verificationCode = ""
                verificationID = nil
            } label: {
                Text("電話番号を変更する")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func sendVerificationCode() async {
        let cleaned = phoneNumber.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        let fullNumber: String
        if cleaned.hasPrefix("0") {
            fullNumber = "+81" + String(cleaned.dropFirst())
        } else {
            fullNumber = "+81" + cleaned
        }

        isLoading = true
        errorMessage = nil

        do {
            let vID = try await PhoneAuthProvider.provider().verifyPhoneNumber(fullNumber, uiDelegate: authUIDelegate)
            verificationID = vID
            isCodeSent = true
            startResendCountdown()
        } catch {
            let nsError = error as NSError
            print("[PhoneAuth] Error domain: \(nsError.domain), code: \(nsError.code), desc: \(nsError.localizedDescription)")
            print("[PhoneAuth] Full error: \(nsError)")
            errorMessage = phoneAuthErrorMessage(error)
        }

        isLoading = false
    }

    private func verifyCode() async {
        guard let verificationID else {
            errorMessage = "認証IDが見つかりません。再度お試しください。"
            return
        }

        isLoading = true
        errorMessage = nil

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )

        do {
            guard let currentUser = Auth.auth().currentUser else {
                errorMessage = "ユーザーが見つかりません"
                isLoading = false
                return
            }

            if currentUser.providerData.contains(where: { $0.providerID == "phone" }) {
                try? await currentUser.unlink(fromProvider: "phone")
            }

            try await currentUser.link(with: credential)
            if var user = dataStore.currentUser {
                user.isPhoneVerified = true
                dataStore.saveUserProfile(user)
            }
            isLoading = false
            isPresented = false
        } catch let error as NSError {
            isLoading = false
            if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                errorMessage = "この電話番号は既に他のアカウントで使用されています。"
            } else {
                errorMessage = phoneAuthErrorMessage(error)
            }
        }
    }

    private func startResendCountdown() {
        canResend = false
        resendCountdown = 60
        Task {
            while resendCountdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                resendCountdown -= 1
            }
            canResend = true
        }
    }

    private func phoneAuthErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        let debugInfo = "(\(nsError.domain):\(nsError.code))"
        guard nsError.domain == AuthErrorDomain else {
            return "\(error.localizedDescription) \(debugInfo)"
        }
        switch AuthErrorCode(rawValue: nsError.code) {
        case .invalidPhoneNumber:
            return "無効な電話番号です。正しい番号を入力してください。"
        case .tooManyRequests:
            return "リクエストが多すぎます。しばらく待ってからお試しください。"
        case .invalidVerificationCode:
            return "認証コードが正しくありません。再度入力してください。"
        case .sessionExpired:
            return "セッションが期限切れです。コードを再送信してください。"
        case .credentialAlreadyInUse:
            return "この電話番号は既に他のアカウントに登録されています。"
        case .providerAlreadyLinked:
            return "既に電話番号が登録されています。"
        case .networkError:
            return "ネットワークエラーが発生しました。接続を確認してください。"
        default:
            return "エラーが発生しました: \(nsError.localizedDescription) \(debugInfo)"
        }
    }
}
