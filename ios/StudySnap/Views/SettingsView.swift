import SwiftUI
import StoreKit

struct SettingsView: View {
    let dataStore: DataStore
    let authService: AuthenticationService
    var store: StoreViewModel
    @AppStorage("appTheme") private var appTheme: AppTheme = .light
    @State private var showLeaveConfirm = false
    @State private var showSignOutConfirm = false
    @State private var showTransferAdmin = false
    @State private var showEditProfile = false
    @State private var showCancelRequest = false
    @State private var showLastMemberLeave = false
    @State private var showDeleteAccount = false
    @State private var showDeleteAccountFinal = false
    @State private var showPasswordPrompt = false
    @State private var deletePassword: String = ""
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
    @State private var showPaywall = false
    @State private var showCustomerCenter = false
    @State private var showPhoneVerification = false
    @State private var notificationService = NotificationService.shared
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        ProfileAvatarView(
                            photoUrl: dataStore.currentUser?.profilePhotoUrl,
                            name: dataStore.currentUser?.name ?? "?",
                            size: 56
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(dataStore.currentUser?.name ?? "ユーザー")
                                .font(.headline)

                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 2) {
                            if let ageGroup = dataStore.currentUser?.ageGroup {
                                Text(ageGroup)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let occupation = dataStore.currentUser?.occupation {
                                Text(occupation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            showEditProfile = true
                        } label: {
                            Text("編集")
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("プロフィール")
                }

                if let group = dataStore.currentGroup {
                    Section {
                        LabeledContent("グループ名", value: group.name)
                        LabeledContent("メンバー数", value: "\(group.memberIds.count)人")
                        LabeledContent("参加方法", value: group.method.title)

                        if dataStore.currentUser?.isAdmin == true {
                            NavigationLink {
                                GroupAdminView(dataStore: dataStore, group: group)
                            } label: {
                                HStack {
                                    Label("グループ管理", systemImage: "gearshape.fill")
                                    Spacer()
                                    if dataStore.pendingMemberCount > 0 {
                                        Text("\(dataStore.pendingMemberCount)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(.red, in: Capsule())
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("所属グループ")
                    }

                    Section {
                        Button(role: .destructive) {
                            if group.memberIds.count == 1 {
                                showLastMemberLeave = true
                            } else if dataStore.currentUser?.isAdmin == true {
                                showTransferAdmin = true
                            } else {
                                showLeaveConfirm = true
                            }
                        } label: {
                            Label("グループを脱退", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } footer: {
                        if group.memberIds.count == 1 {
                            Text("あなたが唯一のメンバーです。脱退するとグループは削除されます")
                        } else if dataStore.currentUser?.isAdmin == true {
                            Text("管理者はグループを脱退する前に権限を他のメンバーに譲渡する必要があります")
                        }
                    }
                } else if dataStore.isPendingApproval, let user = dataStore.currentUser, let pendingGroup = dataStore.pendingGroupFor(user: user) {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "hourglass.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                                .symbolEffect(.pulse, options: .repeating)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("「\(pendingGroup.name)」に申請中")
                                    .font(.subheadline.bold())
                                Text("管理者の承認をお待ちください")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)

                        Button(role: .destructive) {
                            showCancelRequest = true
                        } label: {
                            Label("申請を取り消す", systemImage: "xmark.circle")
                        }
                    } header: {
                        Text("参加申請")
                    }
                }

                Section {
                    if store.isPremium {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .yellow],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pro会員")
                                    .font(.subheadline.bold())
                                Text("勉強時間は無制限です")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                        .padding(.vertical, 4)

                        Button {
                            showCustomerCenter = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.text.rectangle")
                                    .font(.body)
                                    .foregroundStyle(.blue)

                                Text("サブスクリプションを管理")
                                    .font(.subheadline)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "crown.fill")
                                    .font(.title2)
                                    .foregroundStyle(.orange)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Proにアップグレード")
                                        .font(.subheadline.bold())
                                    Text("月額¥380で勉強時間が無制限に")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("プラン")
                }

                Section {
                    if dataStore.currentUser?.isPhoneVerified == true {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.title2)
                                .foregroundStyle(.green)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("電話番号認証済み")
                                    .font(.subheadline.bold())
                                Text("本人確認が完了しています")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            showPhoneVerification = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "phone.badge.checkmark")
                                    .font(.title2)
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("電話番号を認証する")
                                        .font(.subheadline.bold())
                                    Text("承認機能の利用に必要です")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("本人確認")
                }

                Section {
                    Picker(selection: $appTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Label(theme.label, systemImage: theme.icon)
                                .tag(theme)
                        }
                    } label: {
                        Label("外観", systemImage: "circle.lefthalf.filled")
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("外観")
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { notificationService.isReminderEnabled },
                        set: { newValue in
                            if newValue {
                                Task {
                                    let granted = await notificationService.requestPermissionAndEnable()
                                    if granted {
                                        notificationService.isReminderEnabled = true
                                    } else {
                                        notificationService.isReminderEnabled = false
                                    }
                                }
                            } else {
                                notificationService.isReminderEnabled = false
                            }
                        }
                    )) {
                        Label("勉強リマインダー", systemImage: "bell.badge")
                    }

                    if notificationService.isReminderEnabled {
                        DatePicker(
                            selection: Binding(
                                get: { notificationService.reminderTime },
                                set: { notificationService.reminderTime = $0 }
                            ),
                            displayedComponents: .hourAndMinute
                        ) {
                            Label("通知時刻", systemImage: "clock")
                        }
                    }
                } header: {
                    Text("通知")
                } footer: {
                    if notificationService.isReminderEnabled {
                        Text("毎日設定した時刻にリマインダーが届きます")
                    }
                }

                Section {
                    NavigationLink {
                        BlockedUsersView(dataStore: dataStore)
                    } label: {
                        Label("ブロック中のユーザー", systemImage: "hand.raised")
                    }
                } header: {
                    Text("プライバシー")
                }

                Section {
                    Button {
                        requestReview()
                    } label: {
                        Label("アプリを評価する", systemImage: "star.fill")
                    }

                    NavigationLink {
                        ContactFormView()
                    } label: {
                        Label("お問い合わせ", systemImage: "envelope.fill")
                    }
                } header: {
                    Text("サポート")
                }

                Section {
                    NavigationLink {
                        TermsOfServiceView()
                    } label: {
                        Label("利用規約", systemImage: "doc.text")
                    }
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("プライバシーポリシー", systemImage: "hand.raised")
                    }
                } header: {
                    Text("法的情報")
                }

                Section {
                    LabeledContent("累計勉強時間") {
                        Text(formatDuration(dataStore.allTimeTotalStudyTime))
                            .fontWeight(.semibold)
                    }
                    LabeledContent("セッション数", value: "\(dataStore.sessions.count)")
                } header: {
                    Text("統計")
                }

                Section {
                    LabeledContent("アプリバージョン") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let credentials = authService.currentCredentials {
                        LabeledContent("ログイン方法") {
                            HStack(spacing: 6) {
                                Image(systemName: providerIcon(credentials.provider))
                                Text(providerLabel(credentials.provider))
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        if let email = credentials.email {
                            LabeledContent("メール", value: email)
                        }
                    }

                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Label("サインアウト", systemImage: "rectangle.portrait.and.arrow.forward")
                    }
                } header: {
                    Text("アカウント")
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteAccount = true
                    } label: {
                        if isDeletingAccount {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("削除中...")
                            }
                        } else {
                            Label("アカウントを削除", systemImage: "trash")
                        }
                    }
                    .disabled(isDeletingAccount)
                } footer: {
                    Text("アカウントを削除すると、すべてのデータが完全に消去されます。削除後も同じアカウントで再登録できます。")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .alert("グループを脱退しますか？", isPresented: $showLeaveConfirm) {
                Button("脱退する", role: .destructive) {
                    dataStore.leaveGroup()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("グループを脱退すると投稿や承認ができなくなります")
            }
            .alert("グループが消滅します", isPresented: $showLastMemberLeave) {
                Button("脱退してグループを削除", role: .destructive) {
                    dataStore.leaveAndDeleteGroup()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("あなたはこのグループの唯一のメンバーです。脱退するとグループは完全に削除されます。")
            }
            .alert("参加申請を取り消しますか？", isPresented: $showCancelRequest) {
                Button("取り消す", role: .destructive) {
                    dataStore.cancelPendingRequest()
                }
                Button("戻る", role: .cancel) {}
            } message: {
                Text("申請を取り消すとグループへの参加待ちが解除されます")
            }
            .sheet(isPresented: $showTransferAdmin) {
                TransferAdminView(dataStore: dataStore, isPresented: $showTransferAdmin)
            }
            .sheet(isPresented: $showEditProfile) {
                ProfileEditView(dataStore: dataStore, isPresented: $showEditProfile)
            }
            .alert("サインアウトしますか？", isPresented: $showSignOutConfirm) {
                Button("サインアウト", role: .destructive) {
                    authService.signOut()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("サインアウトするとログイン画面に戻ります")
            }
            .alert("アカウントを削除しますか？", isPresented: $showDeleteAccount) {
                Button("削除する", role: .destructive) {
                    showDeleteAccountFinal = true
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。投稿・勉強記録・プロフィールなど、すべてのデータが完全に削除されます。")
            }
            .alert("本当に削除しますか？", isPresented: $showDeleteAccountFinal) {
                Button("完全に削除する", role: .destructive) {
                    if authService.currentCredentials?.provider == .email {
                        deletePassword = ""
                        showPasswordPrompt = true
                    } else {
                        performDeleteAccount(password: nil)
                    }
                }
                Button("やめる", role: .cancel) {}
            } message: {
                Text("この操作は元に戻せません。")
            }
            .alert("パスワードを入力してください", isPresented: $showPasswordPrompt) {
                SecureField("パスワード", text: $deletePassword)
                Button("削除する", role: .destructive) {
                    performDeleteAccount(password: deletePassword)
                }
                Button("キャンセル", role: .cancel) {
                    deletePassword = ""
                }
            } message: {
                Text("アカウントを削除するには、現在のパスワードを入力してください。")
            }
            .alert("削除に失敗しました", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
            .sheet(isPresented: $showPaywall) {
                StudySnapPaywallView(store: store, dailyUsedTime: dataStore.todayTotalUsedTime)
            }
            .sheet(isPresented: $showCustomerCenter) {
                SubscriptionManagementView(store: store)
            }
            .sheet(isPresented: $showPhoneVerification) {
                PhoneVerificationView(dataStore: dataStore, isPresented: $showPhoneVerification)
            }
        }
    }

    private func performDeleteAccount(password: String?) {
        isDeletingAccount = true
        deleteError = nil
        Task {
            do {
                try? await dataStore.deleteAllAccountData()
                try await authService.deleteAccount(password: password)
            } catch {
                isDeletingAccount = false
                deleteError = "アカウントの削除に失敗しました。パスワードを確認してください。"
            }
        }
    }

    private func providerIcon(_ provider: AuthProvider) -> String {
        switch provider {
        case .google: return "g.circle.fill"
        case .email: return "envelope.fill"
        case .apple: return "apple.logo"
        }
    }

    private func providerLabel(_ provider: AuthProvider) -> String {
        switch provider {
        case .google: return "Google"
        case .email: return "メール"
        case .apple: return "Apple"
        }
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let total = Int(time)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        }
        return "\(minutes)分"
    }
}

struct GroupAdminView: View {
    let dataStore: DataStore
    let group: StudyGroup
    @State private var showRemoveConfirm = false
    @State private var memberToRemove: String?
    @State private var members: [String: UserProfile] = [:]

    var body: some View {
        List {
            if !group.pendingMemberIds.isEmpty {
                Section {
                    ForEach(group.pendingMemberIds, id: \.self) { memberId in
                        let member = members[memberId]
                        PendingMemberRow(
                            memberName: member?.name ?? "申請ユーザー",
                            memberPhotoUrl: member?.profilePhotoUrl,
                            onApprove: { dataStore.approveMember(memberId) },
                            onReject: { dataStore.rejectMember(memberId) }
                        )
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text("承認待ち")
                        Text("\(group.pendingMemberIds.count)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.orange, in: Capsule())
                    }
                }
            }

            Section {
                ForEach(group.memberIds, id: \.self) { memberId in
                    let member = members[memberId]
                    HStack(spacing: 12) {
                        ProfileAvatarView(
                            photoUrl: member?.profilePhotoUrl,
                            name: member?.name ?? "?",
                            size: 36
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(member?.name ?? "メンバー")
                                    .font(.subheadline.bold())
                                if memberId == dataStore.currentUser?.id {
                                    Text("あなた")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if memberId == group.adminId {
                                Text("管理者")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }

                        Spacer()

                        if memberId != group.adminId && memberId != dataStore.currentUser?.id {
                            Button(role: .destructive) {
                                memberToRemove = memberId
                                showRemoveConfirm = true
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("メンバー (\(group.memberIds.count))")
            }
        }
        .navigationTitle("グループ管理")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadMembers() }
        .confirmationDialog("このメンバーをグループから除外しますか？", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button("除外する", role: .destructive) {
                if let id = memberToRemove {
                    dataStore.removeMember(id)
                    Task { await loadMembers() }
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func loadMembers() async {
        let allIds = group.memberIds + group.pendingMemberIds
        guard !allIds.isEmpty else { return }
        let fetched = await dataStore.fetchMembers(for: group)
        let pendingFetched: [UserProfile]
        if !group.pendingMemberIds.isEmpty {
            pendingFetched = (try? await dataStore.fetchUsers(ids: group.pendingMemberIds)) ?? []
        } else {
            pendingFetched = []
        }
        var dict: [String: UserProfile] = [:]
        for user in fetched + pendingFetched {
            dict[user.id] = user
        }
        members = dict
    }
}

struct PendingMemberRow: View {
    let memberName: String
    let memberPhotoUrl: String?
    var onApprove: () -> Void
    var onReject: () -> Void
    @State private var showRejectConfirm = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ProfileAvatarView(
                    photoUrl: memberPhotoUrl,
                    name: memberName,
                    size: 36
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(memberName)
                        .font(.subheadline.bold())
                    Text("参加リクエスト")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    showRejectConfirm = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("拒否")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    withAnimation {
                        onApprove()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("承認")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog("このリクエストを拒否しますか？", isPresented: $showRejectConfirm, titleVisibility: .visible) {
            Button("拒否する", role: .destructive) {
                withAnimation {
                    onReject()
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }
}

struct TransferAdminView: View {
    let dataStore: DataStore
    @Binding var isPresented: Bool
    @State private var members: [String: UserProfile] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("管理者権限を譲渡するメンバーを選んでください。譲渡後にグループを脱退できます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    let otherMembers = dataStore.currentGroup?.memberIds.filter { $0 != dataStore.currentUser?.id } ?? []
                    ForEach(otherMembers, id: \.self) { memberId in
                        let member = members[memberId]
                        Button {
                            dataStore.transferAdmin(to: memberId)
                            dataStore.leaveGroup()
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                ProfileAvatarView(
                                    photoUrl: member?.profilePhotoUrl,
                                    name: member?.name ?? "?",
                                    size: 32
                                )
                                Text(member?.name ?? "メンバー")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                } header: {
                    Text("メンバー")
                }
            }
            .navigationTitle("管理者権限の譲渡")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                let otherIds = dataStore.currentGroup?.memberIds.filter { $0 != dataStore.currentUser?.id } ?? []
                let fetched = (try? await CloudService().getUsers(authUserIds: otherIds)) ?? []
                var dict: [String: UserProfile] = [:]
                for user in fetched {
                    dict[user.id] = user
                }
                members = dict
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { isPresented = false }
                }
            }
        }
    }
}
