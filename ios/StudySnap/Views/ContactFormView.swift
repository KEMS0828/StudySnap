import SwiftUI

nonisolated enum ContactCategory: String, CaseIterable, Identifiable {
    case bug = "バグ報告"
    case feature = "機能リクエスト"
    case other = "その他"

    nonisolated var id: String { rawValue }

    var icon: String {
        switch self {
        case .bug: return "ladybug.fill"
        case .feature: return "lightbulb.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

struct ContactFormView: View {
    @State private var selectedCategory: ContactCategory = .bug
    @State private var message: String = ""
    @State private var isSending: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @Environment(\.dismiss) private var dismiss

    private var canSend: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        Form {
            Section {
                Picker(selection: $selectedCategory) {
                    ForEach(ContactCategory.allCases) { category in
                        Text(category.rawValue)
                            .tag(category)
                    }
                } label: {
                    Label("カテゴリ", systemImage: "tag.fill")
                }
                .pickerStyle(.menu)
            } header: {
                Text("お問い合わせの種類")
            }

            Section {
                TextEditor(text: $message)
                    .frame(minHeight: 120)
                    .overlay(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("お問い合わせ内容を入力してください...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            } header: {
                Text("メッセージ")
            } footer: {
                Text("できるだけ詳しくお書きください。返信はメールで届きます。")
            }

            Section {
                Button {
                    sendInquiry()
                } label: {
                    HStack {
                        Spacer()
                        if isSending {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("送信中...")
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("送信する")
                        }
                        Spacer()
                    }
                    .fontWeight(.semibold)
                    .padding(.vertical, 4)
                }
                .disabled(!canSend)
            }
        }
        .navigationTitle("お問い合わせ")
        .navigationBarTitleDisplayMode(.inline)
        .alert("送信完了", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("お問い合わせを受け付けました。ありがとうございます。")
        }
        .alert("送信に失敗しました", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func sendInquiry() {
        isSending = true
        let body = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = selectedCategory.rawValue

        Task {
            do {
                try await ContactService.send(category: category, message: body)
                isSending = false
                showSuccess = true
            } catch {
                isSending = false
                errorMessage = "通信エラーが発生しました。時間をおいて再度お試しください。"
                showError = true
            }
        }
    }
}
