import SwiftUI

struct BlockedUsersView: View {
    let dataStore: DataStore
    @State private var blockService = BlockService.shared
    @State private var blockedProfiles: [UserProfile] = []
    @State private var isLoading: Bool = true
    @State private var userToUnblock: UserProfile?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if blockedProfiles.isEmpty {
                emptyView
            } else {
                List {
                    ForEach(blockedProfiles) { user in
                        HStack(spacing: 12) {
                            ProfileAvatarView(
                                photoUrl: user.profilePhotoUrl,
                                name: user.name,
                                size: 40
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.subheadline.weight(.medium))
                                if let occupation = user.occupation {
                                    Text(occupation)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                userToUnblock = user
                            } label: {
                                Text("解除")
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("ブロック中のユーザー")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBlockedProfiles()
        }
        .confirmationDialog("ブロックを解除しますか？", isPresented: Binding(
            get: { userToUnblock != nil },
            set: { if !$0 { userToUnblock = nil } }
        ), titleVisibility: .visible) {
            Button("解除する") {
                if let user = userToUnblock {
                    withAnimation {
                        blockService.unblock(user.id)
                        blockedProfiles.removeAll { $0.id == user.id }
                    }
                    userToUnblock = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                userToUnblock = nil
            }
        } message: {
            if let user = userToUnblock {
                Text("\(user.name)のブロックを解除すると、投稿やメッセージが再び表示されます。")
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("ブロック中のユーザーはいません")
                .font(.headline)

            Text("ユーザーのプロフィール画面からブロックできます")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadBlockedProfiles() async {
        let ids = Array(blockService.blockedUserIds)
        guard !ids.isEmpty else {
            isLoading = false
            return
        }
        let profiles = (try? await dataStore.fetchUsers(ids: ids)) ?? []
        blockedProfiles = profiles
        isLoading = false
    }
}
