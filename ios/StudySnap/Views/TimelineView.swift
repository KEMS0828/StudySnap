import SwiftUI

enum TimelineFeedItem: Identifiable {
    case post(StudyPost)
    case chat(ChatMessage)

    var id: String {
        switch self {
        case .post(let p): return "post_\(p.id)"
        case .chat(let c): return "chat_\(c.id)"
        }
    }

    var date: Date {
        switch self {
        case .post(let p): return p.createdAt
        case .chat(let c): return c.createdAt
        }
    }
}

struct PhotoEditContext: Identifiable {
    let id = UUID()
    let duration: TimeInterval
}

struct TimelineView: View {
    let dataStore: DataStore
    var store: StoreViewModel
    var scrollToBottomTrigger: Int = 0
    private var blockService: BlockService { BlockService.shared }
    @State private var cameraService = CameraService()
    @State private var showModeSelection = false
    @State private var modeConfirmed = false
    @State private var showSubjectSelection = false
    @State private var selectedSubject: String = ""
    @State private var showPreview = false
    @State private var showStudying = false
    @State private var photoEditContext: PhotoEditContext?
    @State private var pendingDurationForContext: TimeInterval = 0
    @State private var showGroupDetail = false
    @State private var showDraftEdit = false
    @State private var showDraftOverwriteWarning = false
    @State private var showUploadError = false
    @State private var showPaywall = false
    @State private var chatInputText: String = ""
    @State private var showNGWordAlert = false
    @FocusState private var chatInputFocused: Bool
    @State private var showLimitReachedAlert = false
    @State private var showApprovalError = false
    @State private var hasInitiallyScrolled = false
    @State private var needsScrollToBottom = false
    @State private var isRefreshing = false
    @State private var selectedMember: UserProfile?

    private enum PendingNavigation {
        case cameraPreview
        case studying
        case photoEdit
    }
    @State private var pendingNavigation: PendingNavigation?

    var body: some View {
        NavigationStack {
            navigationBody
        }
    }

    private var navigationBody: some View {
        navigationBaseContent
            .sheet(item: $photoEditContext) { context in
                photoEditSheet(duration: context.duration)
            }
            .sheet(isPresented: $showDraftEdit) {
                draftEditSheet
            }
            .sheet(isPresented: $showPaywall) {
                StudySnapPaywallView(store: store, dailyUsedTime: dataStore.todayTotalUsedTime)
            }
            .alert("投稿に失敗しました", isPresented: $showUploadError) {
                Button("OK", role: .cancel) { dataStore.uploadError = nil }
            } message: {
                Text(dataStore.uploadError ?? "")
            }
            .alert("制限中", isPresented: $showLimitReachedAlert) {
            Button("プランを見る") {
                showPaywall = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("本日の無料勉強時間を使い切りました。プレミアムにアップグレードすると無制限に勉強できます。")
        }
        .alert("承認エラー", isPresented: $showApprovalError) {
                Button("OK", role: .cancel) { dataStore.approvalError = nil }
            } message: {
                Text(dataStore.approvalError ?? "")
            }
            .alert("送信できません", isPresented: $showNGWordAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("不適切な表現が含まれているため送信できません。")
            }
            .alert("前回の下書きがあります", isPresented: $showDraftOverwriteWarning) {
                Button("新たに記録する", role: .destructive) {
                    dataStore.deleteDraft()
                    proceedStartStudyFlow()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("新たに記録すると前回の下書きは消去されます")
            }
    }

    private var navigationBaseContent: some View {
        Group {
            if dataStore.currentGroup == nil {
                GroupSearchView(dataStore: dataStore)
            } else {
                timelineContent
            }
        }
        .navigationTitle(dataStore.currentGroup != nil ? "" : "タイムライン")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(dataStore.currentGroup != nil ? .hidden : .visible, for: .navigationBar)
        .sheet(isPresented: $showGroupDetail) {
            groupDetailSheet
        }
        .sheet(item: $selectedMember) { member in
            NavigationStack {
                MemberProfileView(
                    member: member,
                    isAdmin: member.id == dataStore.currentGroup?.adminId,
                    dataStore: dataStore
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") { selectedMember = nil }
                    }
                }
            }
        }
        .task(id: dataStore.currentGroup?.id) {
            if dataStore.currentGroup != nil {
                await dataStore.loadGroupMembers()
                dataStore.startPresenceListening()
            } else {
                dataStore.stopPresenceListening()
            }
        }
        .onChange(of: dataStore.uploadError) { _, newValue in
            showUploadError = newValue != nil
        }
        .onChange(of: dataStore.approvalError) { _, newValue in
            showApprovalError = newValue != nil
        }
        .sheet(isPresented: $showModeSelection, onDismiss: {
            if modeConfirmed {
                modeConfirmed = false
                showSubjectSelection = true
            }
        }) {
            ModeSelectionView(
                isPresented: $showModeSelection
            ) { mode in
                cameraService.selectedMode = mode
                modeConfirmed = true
                Task { @MainActor in
                    showModeSelection = false
                }
            }
        }
        .sheet(isPresented: $showSubjectSelection, onDismiss: {
            if pendingNavigation == .cameraPreview {
                pendingNavigation = nil
                showPreview = true
            }
        }) {
            SubjectSelectionView(
                isPresented: $showSubjectSelection
            ) { subject in
                selectedSubject = subject
                pendingNavigation = .cameraPreview
                showSubjectSelection = false
            }
        }
        .fullScreenCover(isPresented: $showPreview, onDismiss: {
            if pendingNavigation == .studying {
                pendingNavigation = nil
                showStudying = true
            }
        }) {
            CameraPreviewView(
                cameraService: cameraService,
                onStart: {
                    pendingNavigation = .studying
                    showPreview = false
                },
                isPresented: $showPreview
            )
        }
        .fullScreenCover(isPresented: $showStudying, onDismiss: {
            if pendingNavigation == .photoEdit {
                let duration = pendingDurationForContext
                pendingNavigation = nil
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    photoEditContext = PhotoEditContext(duration: duration)
                }
            }
        }) {
            StudyingView(
                cameraService: cameraService,
                store: store,
                todayShootingTime: dataStore.todayTotalUsedTime,
                dataStore: dataStore
            ) { duration in
                pendingDurationForContext = duration
                pendingNavigation = .photoEdit
                showStudying = false
            }
        }
    }

    @ViewBuilder
    private var groupDetailSheet: some View {
        if let group = dataStore.currentGroup {
            NavigationStack {
                GroupDetailView(group: group, dataStore: dataStore)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { showGroupDetail = false }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func photoEditSheet(duration: TimeInterval) -> some View {
        PhotoEditView(
            capturedPhotos: cameraService.capturedPhotos,
            duration: duration,
            dataStore: dataStore,
            studyMode: cameraService.selectedMode,
            onPost: { subject, reflection, photos in
                dataStore.deleteDraft()
                postSession(subject: subject, reflection: reflection, photos: photos, duration: duration)
                photoEditContext = nil
            },
            isPresented: Binding(
                get: { photoEditContext != nil },
                set: { if !$0 { photoEditContext = nil } }
            ),
            initialSubject: selectedSubject
        )
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var draftEditSheet: some View {
        if let draft = dataStore.loadDraft() {
            PhotoEditView(
                capturedPhotos: draft.capturedPhotos,
                duration: draft.duration,
                dataStore: dataStore,
                studyMode: draft.mode,
                onPost: { subject, reflection, photos in
                    dataStore.deleteDraft()
                    postDraftSession(subject: subject, reflection: reflection, photos: photos, draft: draft)
                    showDraftEdit = false
                },
                isPresented: $showDraftEdit,
                initialSubject: draft.subject,
                initialReflection: draft.reflection,
                initialEditedPhotos: draft.editedPhotos,
                initialEditablePhotos: draft.editablePhotos
            )
            .interactiveDismissDisabled()
        }
    }

    private var mergedFeedItems: [TimelineFeedItem] {
        let blocked = blockService.blockedUserIds
        let postItems = dataStore.timelinePosts
            .filter { !blocked.contains($0.userId) }
            .map { TimelineFeedItem.post($0) }
        let chatItems = dataStore.chatMessages
            .filter { !blocked.contains($0.userId) }
            .map { TimelineFeedItem.chat($0) }
        return (postItems + chatItems).sorted { $0.date < $1.date }
    }

    private var timelineContent: some View {
        VStack(spacing: 0) {
            unifiedHeader

            if dataStore.hasDraft {
                draftCard
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .background(Color(.systemGroupedBackground))
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if dataStore.isLoading {
                            ProgressView("投稿中...")
                                .padding()
                        }

                        let items = mergedFeedItems
                        if items.isEmpty && !dataStore.isLoading {
                            emptyTimelineView
                        } else {
                            ForEach(items, id: \.id) { item in
                                switch item {
                                case .post(let post):
                                    PostCardView(post: post, dataStore: dataStore)
                                case .chat(let msg):
                                    ChatMessageRow(message: msg, isMe: msg.userId == dataStore.currentUser?.id)
                                }
                            }
                        }

                        Color.clear.frame(height: 1).id("timeline_bottom")

                        if isRefreshing {
                            ProgressView()
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
                .defaultScrollAnchor(.top)
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    let maxOffset = geo.contentSize.height - geo.containerSize.height + geo.contentInsets.top + geo.contentInsets.bottom
                    guard maxOffset > 0 else { return -CGFloat.greatestFiniteMagnitude }
                    return geo.contentOffset.y - maxOffset
                } action: { _, overscroll in
                    if overscroll > 60 && !isRefreshing {
                        triggerBottomRefresh()
                    }
                }
                .onAppear {
                    if !hasInitiallyScrolled {
                        needsScrollToBottom = true
                    }
                }
                .onChange(of: mergedFeedItems.count) { oldCount, newCount in
                    if newCount > 0 && needsScrollToBottom {
                        needsScrollToBottom = false
                        hasInitiallyScrolled = true
                        scrollToBottom(proxy: proxy)
                    } else if newCount > oldCount && hasInitiallyScrolled {
                        scrollToBottom(proxy: proxy)
                    }
                }
                .onChange(of: needsScrollToBottom) { _, shouldScroll in
                    if shouldScroll && !mergedFeedItems.isEmpty {
                        needsScrollToBottom = false
                        hasInitiallyScrolled = true
                        scrollToBottom(proxy: proxy)
                    }
                }
                .onChange(of: dataStore.currentGroup?.id) { _, _ in
                    hasInitiallyScrolled = false
                    needsScrollToBottom = true
                }
                .onChange(of: scrollToBottomTrigger) { _, _ in
                    needsScrollToBottom = true
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    chatInputFocused = false
                }
                .background(Color(.systemGroupedBackground))
                .overlay(alignment: .bottomTrailing) {
                    startStudyFloatingButton
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                }
            }

            chatInputBar
        }
    }

    private var unifiedHeader: some View {
        VStack(spacing: 2) {
            Button {
                showGroupDetail = true
            } label: {
                HStack(spacing: 4) {
                    Text(dataStore.currentGroup?.name ?? "タイムライン")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            if !dataStore.groupMembers.isEmpty {
                MembersStatusRowView(
                    members: dataStore.groupMembers,
                    studyingMemberIds: dataStore.studyingMemberIds,
                    dataStore: dataStore,
                    onSelect: { member in
                        selectedMember = member
                    }
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
            }
        }
        .padding(.horizontal)
        .padding(.top, 2)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var startStudyHeaderButton: some View {
        if canStartStudy {
            Button {
                startStudyFlow()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: .blue.opacity(0.35), radius: 6, x: 0, y: 3)
                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("勉強を始める")
        } else {
            Button {
                showPaywall = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 52, height: 52)
                        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("今日の無料枠を使い切りました")
        }
    }

    @ViewBuilder
    private var startStudyFloatingButton: some View {
        if canStartStudy {
            Button {
                startStudyFlow()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: .blue.opacity(0.35), radius: 8, x: 0, y: 4)
                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("勉強を始める")
        } else {
            Button {
                showPaywall = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("今日の無料枠を使い切りました")
        }
    }

    private func triggerBottomRefresh() {
        isRefreshing = true
        Task {
            await dataStore.refreshTimelineAsync()
            isRefreshing = false
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.1)) {
                proxy.scrollTo("timeline_bottom", anchor: .bottom)
            }
        }
    }

    private var emptyTimelineView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.1), .cyan.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("まだ投稿がありません")
                    .font(.title3.bold())

                Text("勉強を始めて記録を残しましょう！\nグループメンバーに承認してもらえます")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                startStudyFlow()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("勉強を始める")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(.top, 40)
        .padding(.bottom, 20)
    }

    private var chatInputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .bottom, spacing: 6) {
                    TextField("メッセージを入力", text: $chatInputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .lineLimit(1...5)
                        .focused($chatInputFocused)
                        .submitLabel(.send)
                        .onSubmit { trySendChat() }
                        .onChange(of: chatInputText) { _, newValue in
                            if newValue.count > Self.chatCharLimit {
                                chatInputText = String(newValue.prefix(Self.chatCharLimit))
                            }
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(.secondarySystemBackground), in: .capsule)

                if chatInputFocused || !chatInputText.isEmpty {
                    Text("\(chatInputText.count) / \(Self.chatCharLimit)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(chatInputText.count >= Self.chatCharLimit ? Color.red : (chatInputText.count >= Self.chatCharLimit - 10 ? Color.orange : Color.secondary))
                        .padding(.trailing, 8)
                }
            }

            Button {
                trySendChat()
            } label: {
                Image(systemName: "arrow.up")
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
        .background(Color(.secondarySystemGroupedBackground))
    }

    private static let chatCharLimit: Int = 100

    private var canSendChat: Bool {
        let trimmed = chatInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && chatInputText.count <= Self.chatCharLimit
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

    private var canStartStudy: Bool {
        store.canStartStudy(dailyStudyTime: dataStore.todayTotalUsedTime)
    }

    @ViewBuilder
    private var startStudyToolbarButton: some View {
        if canStartStudy {
            Button {
                startStudyFlow()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("勉強を始める")
        } else {
            Button {
                showPaywall = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("今日の無料枠を使い切りました")
        }
    }

    private var startStudyCard: some View {
        VStack(spacing: 0) {
            if canStartStudy {
                Button {
                    startStudyFlow()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)

                            Image(systemName: "play.fill")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }

                        Text("勉強を始める")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray4))
                                .frame(width: 36, height: 36)

                            Image(systemName: "lock.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Text("今日の無料枠を使い切りました")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Spacer()
                    }

                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                            Text("Proにアップグレード")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
            }
        }
    }



    private var draftCard: some View {
        let draft = dataStore.loadDraft()
        return Button {
            showDraftEdit = true
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: "doc.text.fill")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("保存済み下書き")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if let draft {
                            Text("\(draft.subject.isEmpty ? "未入力" : draft.subject) - \(draftTimeString(draft.duration))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "pencil.circle.fill")
                        .font(.body)
                        .foregroundStyle(.orange)
                }

                if let draft {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(draftExpiryText(draft.savedAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func draftExpiryText(_ savedAt: Date) -> String {
        let remaining = 86400 - Date.now.timeIntervalSince(savedAt)
        if remaining <= 0 { return "まもなく期限切れ" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "下書きは保存から24時間で自動削除されます（残り約\(hours)時間\(minutes)分）"
        }
        return "下書きは保存から24時間で自動削除されます（残り約\(minutes)分）"
    }

    private func draftTimeString(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        }
        return "\(minutes)分"
    }

    private func startStudyFlow() {
        if !canStartStudy {
            showLimitReachedAlert = true
            return
        }
        if dataStore.hasDraft {
            showDraftOverwriteWarning = true
            return
        }
        proceedStartStudyFlow()
    }

    private func proceedStartStudyFlow() {
        modeConfirmed = false
        pendingNavigation = nil
        Task {
            await cameraService.requestPermissionAndSetup()
        }
        showModeSelection = true
    }

    private func postSession(subject: String, reflection: String, photos: [Data], duration: TimeInterval) {
        var session = StudySession(mode: cameraService.selectedMode, groupId: dataStore.currentGroup?.id)
        session.endTime = session.startTime.addingTimeInterval(duration)
        session.subject = subject.isEmpty ? selectedSubject : subject
        session.reflection = reflection
        session.ownerUserId = dataStore.currentUser?.id
        dataStore.saveSession(session)
        dataStore.createPost(from: session, editedPhotos: photos, mode: cameraService.selectedMode)
    }

    private func postDraftSession(subject: String, reflection: String, photos: [Data], draft: DraftData) {
        var session = StudySession(mode: draft.mode, groupId: dataStore.currentGroup?.id)
        session.endTime = session.startTime.addingTimeInterval(draft.duration)
        session.subject = subject
        session.reflection = reflection
        session.ownerUserId = dataStore.currentUser?.id
        dataStore.saveSession(session)
        dataStore.createPost(from: session, editedPhotos: photos, mode: draft.mode)
    }
}

struct ChatMessageRow: View {
    let message: ChatMessage
    let isMe: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isMe { Spacer(minLength: 60) }

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
                    .clipShape(.rect(cornerRadius: 18, style: .continuous))

                Text(chatTimeString(message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if !isMe { Spacer(minLength: 60) }
        }
    }

    private static let todayTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let otherDayTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d HH:mm"
        return f
    }()

    private func chatTimeString(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return Self.todayTimeFormatter.string(from: date)
        } else {
            return Self.otherDayTimeFormatter.string(from: date)
        }
    }
}

struct PostCardView: View {
    let post: StudyPost
    let dataStore: DataStore

    private var isOtherUser: Bool {
        post.userId != dataStore.currentUser?.id
    }

    private var approvedCount: Int {
        post.photoApproved.filter { $0 }.count
    }

    @State private var showDeleteConfirm: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var showPhoneVerificationAlert: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ProfileAvatarView(
                    photoUrl: post.userPhotoUrl,
                    name: post.userName,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(post.userName)
                            .font(.headline)
                            .lineLimit(1)

                        if let mode = post.mode {
                            HStack(spacing: 3) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 9, weight: .semibold))
                                Text(mode.title)
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(mode.tintColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(mode.tintColor.opacity(0.12), in: .capsule)
                        }
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(post.formattedDuration)
                            .font(.caption)
                        Text("•")
                            .font(.caption)
                        Text(relativeTimeString(from: post.createdAt))
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if post.isApproved {
                    Label("全承認済", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                } else if approvedCount > 0 {
                    Text("\(approvedCount)/\(post.photoUrls.count)承認")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.blue, in: Capsule())
                } else if post.photoUrls.isEmpty {
                    Label("写真なし", systemImage: "camera.slash.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.gray, in: Capsule())
                } else {
                    Text("未承認")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.orange, in: Capsule())
                }

                if !isOtherUser {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("編集", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(.rect)
                    }
                }
            }

            if !post.photoUrls.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(Array(post.photoUrls.enumerated()), id: \.offset) { index, urlString in
                            photoCard(at: index, urlString: urlString)
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
                .scrollIndicators(.hidden)
            }

            if !post.subject.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "book.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                    Text(post.subject)
                        .font(.subheadline.bold())
                }
            }

            if !post.reflection.isEmpty {
                Text(post.reflection)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        .sheet(isPresented: $showEditSheet) {
            PostEditView(post: post, dataStore: dataStore, isPresented: $showEditSheet)
                .interactiveDismissDisabled()
        }
        .alert("電話番号認証をしてください", isPresented: $showPhoneVerificationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("※不正防止のため、承認機能のご利用には電話番号認証が必要です。設定画面から認証を行ってください。")
        }
        .confirmationDialog("この投稿を削除しますか？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("削除する", role: .destructive) {
                withAnimation {
                    dataStore.deletePost(post)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("削除すると元に戻せません。承認済みの勉強時間はそのまま維持されます。")
        }
    }

    private func relativeTimeString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval) / 60
        if minutes < 1 {
            return "たった今"
        } else if minutes < 60 {
            return "\(minutes)分前"
        } else if minutes < 1440 {
            return "\(minutes / 60)時間前"
        } else {
            return "\(minutes / 1440)日前"
        }
    }

    private var isPhoneVerified: Bool {
        dataStore.currentUser?.isPhoneVerified == true
    }

    private var postApprovalButton: some View {
        Button {
            guard isPhoneVerified else {
                showPhoneVerificationAlert = true
                return
            }
            withAnimation(.spring(duration: 0.4)) {
                dataStore.approvePost(post)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hand.thumbsup.fill")
                Text("この投稿を承認")
            }
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }

    @ViewBuilder
    private func photoCard(at index: Int, urlString: String) -> some View {
        let isPhotoApproved = index < post.photoApproved.count && post.photoApproved[index]
        let approverName = index < post.photoApprovedByNames.count ? post.photoApprovedByNames[index] : ""

        PostPhotoCardView(
            urlString: urlString,
            isPhotoApproved: isPhotoApproved,
            approverName: approverName,
            isOtherUser: isOtherUser,
            isPhoneVerified: isPhoneVerified,
            onApprove: {
                withAnimation(.spring(duration: 0.4)) {
                    dataStore.approvePhoto(in: post, at: index)
                }
            },
            onPhoneVerificationNeeded: {
                showPhoneVerificationAlert = true
            }
        )
    }
}

private struct PostPhotoCardView: View {
    let urlString: String
    let isPhotoApproved: Bool
    let approverName: String
    let isOtherUser: Bool
    let isPhoneVerified: Bool
    let onApprove: () -> Void
    let onPhoneVerificationNeeded: () -> Void

    @State private var imageAspect: CGFloat? = nil

    private let targetArea: CGFloat = 150 * 200

    private var cardWidth: CGFloat {
        guard let aspect = imageAspect, aspect > 0 else { return 150 }
        let w = sqrt(targetArea * aspect)
        return min(max(w, 120), 220)
    }

    private var cardHeight: CGFloat {
        guard let aspect = imageAspect, aspect > 0 else { return 200 }
        let h = sqrt(targetArea / aspect)
        return min(max(h, 120), 220)
    }

    var body: some View {
        VStack(spacing: 0) {
            Color(.secondarySystemBackground)
                .frame(width: cardWidth, height: cardHeight)
                .overlay {
                    CachedImageView(
                        url: URL(string: urlString),
                        contentMode: .fit,
                        onImageLoaded: { size in
                            guard size.height > 0 else { return }
                            let aspect = size.width / size.height
                            if imageAspect == nil {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    imageAspect = aspect
                                }
                            }
                        }
                    )
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if isPhotoApproved {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white, .green)
                            .shadow(radius: 2)
                            .padding(6)
                    }
                }

            if isPhotoApproved {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text(approverName.isEmpty ? "承認済" : "\(approverName)が承認")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            } else if isOtherUser {
                Button {
                    guard isPhoneVerified else {
                        onPhoneVerificationNeeded()
                        return
                    }
                    onApprove()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                        Text("承認")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.top, 6)
            } else {
                Text("未承認")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.top, 4)
            }
        }
    }
}
