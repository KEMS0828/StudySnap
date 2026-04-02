import SwiftUI

struct LoginView: View {
    let authService: AuthenticationService
    @State private var showEmailLogin = false
    @State private var showTerms = false
    @State private var showPrivacy = false

    var body: some View {
        ZStack {
            Color.indigo.opacity(0.08)
                .ignoresSafeArea()
                .background(Color(.systemBackground).ignoresSafeArea())

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    Image("AppIconImage")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(.rect(cornerRadius: 18))

                    Text("StudySnap")
                        .font(.largeTitle.bold())

                    Text("勉強をもっと楽しく、\nもっと確実に。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 48)

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        authService.signInWithApple()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                                .font(.title2)
                            Text("Appleでサインイン")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.black, in: .rect(cornerRadius: 14))
                        .foregroundStyle(.white)
                    }

                    Button {
                        authService.signInWithGoogle()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue, .blue.opacity(0.15))
                            Text("Googleでサインイン")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.white, in: .rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                        .foregroundStyle(.primary)
                    }

                    Button {
                        showEmailLogin = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(.title3)
                            Text("メールアドレスでサインイン")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
                        .foregroundStyle(.primary)
                    }

                    if let error = authService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                HStack(spacing: 0) {
                    Text("続行することで")
                    Button { showTerms = true } label: {
                        Text("利用規約")
                            .underline()
                            .foregroundStyle(.indigo)
                    }
                    Text("と")
                    Button { showPrivacy = true } label: {
                        Text("プライバシーポリシー")
                            .underline()
                            .foregroundStyle(.indigo)
                    }
                    Text("に同意")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }

            if authService.isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }
        }
        .animation(.default, value: authService.errorMessage)
        .sheet(isPresented: $showEmailLogin) {
            EmailLoginView(authService: authService, isPresented: $showEmailLogin)
        }
        .sheet(isPresented: $showTerms) {
            NavigationStack {
                TermsOfServiceView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { showTerms = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPrivacy) {
            NavigationStack {
                PrivacyPolicyView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { showPrivacy = false }
                        }
                    }
            }
        }
    }
}

struct EmailLoginView: View {
    let authService: AuthenticationService
    @Binding var isPresented: Bool
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSignUp: Bool = false
    @State private var confirmPassword: String = ""
    @State private var showPasswordReset: Bool = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password, confirmPassword
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "envelope.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.indigo)

                        Text(isSignUp ? "アカウント作成" : "メールでログイン")
                            .font(.title2.bold())

                        Text(isSignUp ? "新しいアカウントを作成します" : "メールアドレスとパスワードでログイン")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 16)

                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("メールアドレス")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            TextField("example@email.com", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .email)
                                .padding(14)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(.rect(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("パスワード")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            SecureField("6文字以上", text: $password)
                                .textContentType(isSignUp ? .newPassword : .password)
                                .focused($focusedField, equals: .password)
                                .padding(14)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(.rect(cornerRadius: 12))
                        }

                        if isSignUp {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("パスワード確認")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)

                                SecureField("もう一度入力", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .focused($focusedField, equals: .confirmPassword)
                                    .padding(14)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(.rect(cornerRadius: 12))
                            }
                        }
                    }

                    if let error = authService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        focusedField = nil
                        if isSignUp && password != confirmPassword {
                            authService.errorMessage = "パスワードが一致しません"
                            return
                        }
                        Task {
                            if isSignUp {
                                await authService.signUpWithEmail(email: email, password: password)
                            } else {
                                await authService.signInWithEmail(email: email, password: password)
                            }
                        }
                    } label: {
                        Text(isSignUp ? "アカウント作成" : "ログイン")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .disabled(authService.isLoading)

                    if !isSignUp {
                        Button {
                            showPasswordReset = true
                        } label: {
                            Text("パスワードを忘れた方")
                                .font(.subheadline)
                                .foregroundStyle(.indigo)
                        }
                    }

                    Button {
                        withAnimation {
                            isSignUp.toggle()
                            authService.errorMessage = nil
                        }
                    } label: {
                        Text(isSignUp ? "すでにアカウントをお持ちの方" : "アカウントをお持ちでない方")
                            .font(.subheadline)
                            .foregroundStyle(.indigo)
                    }
                }
                .padding(.horizontal, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { isPresented = false }
                }
            }
            .onChange(of: authService.isAuthenticated) { _, newValue in
                if newValue { isPresented = false }
            }
            .sheet(isPresented: $showPasswordReset) {
                PasswordResetView(authService: authService, isPresented: $showPasswordReset)
            }
        }
    }
}
