import SwiftUI

struct GroupDetailView: View {
    let group: StudyGroup
    let dataStore: DataStore
    @State private var showJoinConfirm = false
    @State private var showCancelConfirm = false
    @State private var isPending = false
    @State private var members: [UserProfile] = []
    @State private var isMember = false
    @State private var isGroupFull = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    GroupAvatarView(photoUrl: group.groupPhotoUrl, name: group.name, size: 88)

                    VStack(spacing: 6) {
                        Text(group.name)
                            .font(.title2.bold())

                        HStack(spacing: 12) {
                            Label("\(group.memberIds.count)人", systemImage: "person.2.fill")
                            Label(group.method.title, systemImage: group.method.icon)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)

                if !group.groupDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("説明")
                            .font(.headline)

                        Text(group.groupDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("情報")
                        .font(.headline)

                    VStack(spacing: 0) {
                        detailRow(label: "参加方法", value: group.method.title, icon: group.method.icon)
                        Divider().padding(.leading, 44)
                        detailRow(label: "メンバー数", value: "\(group.memberIds.count)人", icon: "person.2.fill")
                        Divider().padding(.leading, 44)
                        detailRow(label: "作成日", value: group.createdAt.formatted(.dateTime.year().month().day()), icon: "calendar")
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("メンバー")
                        .font(.headline)

                    VStack(spacing: 0) {
                        ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                            if index > 0 {
                                Divider().padding(.leading, 60)
                            }
                            NavigationLink {
                                MemberProfileView(member: member, isAdmin: member.id == group.adminId, dataStore: dataStore)
                            } label: {
                                memberRow(member: member)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isMember {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("参加中")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                } else if isPending {
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "hourglass")
                            Text("承認待ち")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12))

                        Button {
                            showCancelConfirm = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                Text("取消")
                            }
                            .font(.subheadline.bold())
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
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
                } else if isGroupFull {
                    HStack(spacing: 8) {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(.secondary)
                        Text("このグループは満員です（\(DataStore.maxGroupMembers)人）")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                } else {
                    Button {
                        showJoinConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                            Text("参加する")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .confirmationDialog("「\(group.name)」に参加しますか？", isPresented: $showJoinConfirm, titleVisibility: .visible) {
                        Button("参加する") {
                            dataStore.joinGroup(group)
                            if group.method == .approval {
                                isPending = true
                            } else {
                                isMember = true
                                dismiss()
                            }
                        }
                        Button("キャンセル", role: .cancel) {}
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("グループ詳細")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let user = dataStore.currentUser {
                isMember = group.memberIds.contains(user.id)
                isPending = group.pendingMemberIds.contains(user.id)
            }
            isGroupFull = group.memberIds.count >= DataStore.maxGroupMembers
            members = await dataStore.fetchMembers(for: group)
        }
    }

    private func memberRow(member: UserProfile) -> some View {
        HStack(spacing: 12) {
            ProfileAvatarView(
                photoUrl: member.profilePhotoUrl,
                name: member.name,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(.subheadline.weight(.medium))
                    if member.id == group.adminId {
                        Text("管理者")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue, in: Capsule())
                    }
                }
                HStack(spacing: 8) {
                    if let occupation = member.occupation {
                        Text(occupation)
                    }
                    if let ageGroup = member.ageGroup {
                        Text(ageGroup)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func detailRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
