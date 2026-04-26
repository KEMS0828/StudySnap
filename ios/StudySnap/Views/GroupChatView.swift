import SwiftUI

struct GroupChatView: View {
    let dataStore: DataStore
    private var blockService: BlockService { BlockService.shared }
    @Environment(\.dismiss) private var dismiss
    @State private var lastSentId: String?
    @State private var chatInputText: String = ""
    @State private var showNGWordAlert = false
    @FocusState private var chatInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            let filteredMessages = dataStore.chatMessages.filter { !blockService.blockedUserIds.contains($0.userId) }
                            if filteredMessages.isEmpty {
                                emptyChatView
                                    .padding(.top, 60)
                            } else {
                                ForEach(filteredMessages) { msg in
                                    let isMe = msg.userId == dataStore.currentUser?.id
                                    ChatBubbleView(message: msg, isMe: isMe)
                                        .id(msg.id)
                                        .transition(.asymmetric(
                                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                                            removal: .opacity
                                        ))
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: dataStore.chatMessages.count) { _, _ in
                        if let lastId = dataStore.chatMessages.last?.id {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let lastId = dataStore.chatMessages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }

                Divider()

                chatInputBar
            }
            .alert("送信できません", isPresented: $showNGWordAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("不適切な表現が含まれているため送信できません。")
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("チャット")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var emptyChatView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("まだメッセージがありません")
                .font(.headline)

            Text("定型文を送ってメンバーに声をかけよう！")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var chatInputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(alignment: .bottom, spacing: 6) {
                TextField("メッセージを入力", text: $chatInputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(1...5)
                    .focused($chatInputFocused)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(.secondarySystemBackground), in: .capsule)

            Button {
                trySendChat()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(canSendChat ? Color.blue : Color.gray.opacity(0.4), in: .circle)
            }
            .disabled(!canSendChat)
            .sensoryFeedback(.impact(weight: .light), trigger: dataStore.chatMessages.count)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var canSendChat: Bool {
        !chatInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func trySendChat() {
        let trimmed = chatInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if NGWordFilter.containsNGWord(in: trimmed) {
            showNGWordAlert = true
            return
        }
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
            _ = dataStore.sendChatText(trimmed)
        }
        chatInputText = ""
    }
}

struct ChatBubbleView: View {
    let message: ChatMessage
    let isMe: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMe { Spacer(minLength: 48) }

            if !isMe {
                ProfileAvatarView(
                    photoUrl: message.userPhotoUrl,
                    name: message.userName,
                    size: 32
                )
            }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                if !isMe {
                    Text(message.userName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }

                Text(message.message)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        isMe
                            ? AnyShapeStyle(LinearGradient(colors: [.blue, .blue.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                    )
                    .foregroundStyle(isMe ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(timeString(message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if !isMe { Spacer(minLength: 48) }
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "M/d HH:mm"
        }
        return formatter.string(from: date)
    }
}
