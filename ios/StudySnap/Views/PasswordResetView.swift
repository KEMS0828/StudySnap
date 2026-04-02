import SwiftUI

struct PasswordResetView: View {
    let authService: AuthenticationService
    @Binding var isPresented: Bool
    @State private var email: String = ""
    @FocusState private var focusedField: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: authService.passwordResetSent ? "paperplane.circle.fill" : "envelope.badge.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(authService.passwordResetSent ? .green : .indigo)

                        Text(authService.passwordResetSent ? "メールを送信しました" : "パスワード再設定")
                            .font(.title2.bold())

                        if authService.passwordResetSent {
                            Text("**\(email)** にパスワード再設定用のリンクを送信しました。\nメールを確認してリンクからパスワードを変更してください。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("登録済みのメールアドレスを入力すると、パスワード再設定用のリンクがメールで届きます。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 16)

                    if authService.passwordResetSent {
                        Button {
                            isPresented = false
                        } label: {
                            Text("ログイン画面に戻る")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)

                        Button {
                            authService.passwordResetSent = false
                            authService.errorMessage = nil
                        } label: {
                            Text("別のメールアドレスで再送信")
                                .font(.subheadline)
                                .foregroundStyle(.indigo)
                        }
                    } else {
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
                                    .focused($focusedField)
                                    .padding(14)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(.rect(cornerRadius: 12))
                            }
                        }

                        if let errorMessage = authService.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button {
                            focusedField = false
                            Task {
                                await authService.sendPasswordReset(email: email)
                            }
                        } label: {
                            if authService.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            } else {
                                Text("再設定メールを送信")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .disabled(authService.isLoading)
                    }
                }
                .padding(.horizontal, 24)
            }
            .animation(.default, value: authService.passwordResetSent)
            .animation(.default, value: authService.errorMessage)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(authService.passwordResetSent ? "閉じる" : "キャンセル") {
                        isPresented = false
                    }
                }
            }
            .onDisappear {
                authService.passwordResetSent = false
                authService.errorMessage = nil
            }
        }
    }
}
