import SwiftUI

struct GroupSearchView: View {
    let dataStore: DataStore
    @State private var searchText = ""
    @State private var showCreateGroup = false
    @State private var randomGroupIds: [String] = []

    private var filteredGroups: [StudyGroup] {
        if searchText.isEmpty {
            return dataStore.allGroups.filter { randomGroupIds.contains($0.id) }
        }
        return dataStore.allGroups.filter { $0.name.localizedStandardContains(searchText) }
    }

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.tint)
                            .symbolRenderingMode(.hierarchical)

                        Text("グループに参加しよう")
                            .font(.title2.bold())

                        Text("グループに所属すると勉強記録を\n共有・承認し合えます")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)

                    Button {
                        showCreateGroup = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("新しいグループを作成")
                                    .font(.headline)
                                Text("自分がグループの管理者になります")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("グループを探す")
                            .font(.headline)

                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("グループ名で検索", text: $searchText)
                                .focused($isSearchFocused)
                                .submitLabel(.done)
                                .onSubmit { isSearchFocused = false }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                        )

                        if filteredGroups.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "tray")
                                    .font(.title)
                                    .foregroundStyle(.tertiary)
                                Text("グループが見つかりません")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(filteredGroups, id: \.id) { group in
                                NavigationLink(value: group.id) {
                                    GroupRowView(group: group, dataStore: dataStore)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.immediately)
        .contentShape(Rectangle())
        .onTapGesture { isSearchFocused = false }
        .navigationDestination(for: String.self) { groupId in
            if let group = filteredGroups.first(where: { $0.id == groupId }) ?? dataStore.allGroups.first(where: { $0.id == groupId }) {
                GroupDetailView(group: group, dataStore: dataStore)
            }
        }
        .refreshable {
            await dataStore.loadGroups()
            randomGroupIds = Array(dataStore.allGroups.shuffled().prefix(5).map(\.id))
        }
        .onAppear {
            Task { await dataStore.loadGroups() }
            if randomGroupIds.isEmpty {
                randomGroupIds = Array(dataStore.allGroups.shuffled().prefix(5).map(\.id))
            }
        }
        .onChange(of: dataStore.allGroups.count) { _, _ in
            randomGroupIds = Array(dataStore.allGroups.shuffled().prefix(5).map(\.id))
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupView(dataStore: dataStore, isPresented: $showCreateGroup)
        }
    }
}

struct GroupRowView: View {
    let group: StudyGroup
    let dataStore: DataStore
    @State private var showCancelConfirm = false
    @State private var isPending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                GroupAvatarView(photoUrl: group.groupPhotoUrl, name: group.name, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Label("\(group.memberIds.count)人", systemImage: "person.2.fill")
                        Label(group.method.title, systemImage: group.method.icon)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }

            if !group.groupDescription.isEmpty {
                Text(group.groupDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            if isPending {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                        Text("承認待ち")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 10))

                    Button {
                        showCancelConfirm = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("取消")
                        }
                        .font(.subheadline.bold())
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .confirmationDialog("「\(group.name)」への参加申請を取り消しますか？", isPresented: $showCancelConfirm, titleVisibility: .visible) {
                    Button("申請を取り消す", role: .destructive) {
                        dataStore.cancelJoinRequest(for: group)
                        isPending = false
                    }
                    Button("戻る", role: .cancel) {}
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .onAppear {
            if let user = dataStore.currentUser {
                isPending = group.pendingMemberIds.contains(user.id)
            }
        }
    }
}
