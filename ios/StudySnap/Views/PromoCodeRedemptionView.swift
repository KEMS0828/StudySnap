import SwiftUI

struct PromoCodeRedemptionView: View {
    let store: StoreViewModel
    let userId: String?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var code: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSucceed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if didSucceed {
                    successView
                } else {
                    inputView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("キャンペーンコード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var inputView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 24)

                Text("キャンペーンコードを入力")
                    .font(.title3.bold())

                Text("先着特典のコードをお持ちの方は、こちらに入力してください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 8) {
                TextField("XPROMO2026", text: $code)
                    .focused($isFocused)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.title2, design: .monospaced).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isFocused ? Color.orange : Color(.separator), lineWidth: isFocused ? 2 : 1)
                    )
                    .onChange(of: code) { _, newValue in
                        let upper = newValue.uppercased()
                        if upper != newValue { code = upper }
                        if errorMessage != nil { errorMessage = nil }
                    }
                    .onSubmit { submit() }

                if let errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                        Text(errorMessage)
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)

            Button {
                submit()
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("適用する")
                            .font(.body.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [.orange, .orange.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: .rect(cornerRadius: 14)
                )
                .foregroundStyle(.white)
                .opacity(canSubmit ? 1 : 0.5)
            }
            .disabled(!canSubmit)
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .onAppear { isFocused = true }
        .animation(.default, value: errorMessage)
    }

    private var successView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .symbolEffect(.bounce, value: didSucceed)

            Text("生涯 Pro が有効になりました 🎉")
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text("これからずっと、StudySnap Pro のすべての機能をお使いいただけます。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("閉じる")
                    .font(.body.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.orange, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var canSubmit: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    private func submit() {
        guard canSubmit else { return }
        guard let userId, !userId.isEmpty else {
            errorMessage = "ログインが必要です"
            return
        }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                try await store.redeemPromoCode(trimmed, userId: userId)
                isSubmitting = false
                withAnimation(.spring(duration: 0.4)) {
                    didSucceed = true
                }
            } catch let error as PromoCodeError {
                isSubmitting = false
                errorMessage = error.errorDescription
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
