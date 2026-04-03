import SwiftUI

struct MemberProfileView: View {
    let member: UserProfile
    let isAdmin: Bool
    let dataStore: DataStore
    @State private var blockService = BlockService.shared
    @State private var showBlockConfirm: Bool = false
    @State private var showUnblockConfirm: Bool = false
    @State private var memberTotalStudyTime: TimeInterval = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ProfileAvatarView(photoUrl: member.profilePhotoUrl, name: member.name, size: 96)

                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text(member.name)
                                .font(.title2.bold())
                            if isAdmin {
                                Text("管理者")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.blue, in: Capsule())
                            }
                        }

                        HStack(spacing: 10) {
                            if let occupation = member.occupation {
                                Text(occupation)
                            }
                            if let ageGroup = member.ageGroup {
                                Text(ageGroup)
                            }
                            if let gender = member.gender, gender != Gender.unspecified.rawValue {
                                Text(gender)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 12)

                if let goalText = member.studyGoalText, !goalText.isEmpty {
                    let goals = goalText.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
                    VStack(alignment: .leading, spacing: 10) {
                        Label("達成目標", systemImage: "flag.fill")
                            .font(.headline)
                            .foregroundStyle(.indigo)

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(goals.enumerated()), id: \.offset) { index, goal in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.indigo.opacity(0.7))
                                        .frame(width: 20, alignment: .trailing)
                                    Text(goal)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                }

                if let bio = member.bio, !bio.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("自己紹介", systemImage: "person.text.rectangle")
                            .font(.headline)

                        Text(bio)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("情報")
                        .font(.headline)

                    VStack(spacing: 0) {
                        infoRow(icon: "clock.fill", label: "累計勉強時間", value: formatDuration(memberTotalStudyTime))
                        Divider().padding(.leading, 44)
                        infoRow(icon: "calendar", label: "参加日", value: member.createdAt.formatted(.dateTime.year().month().day()))
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                NavigationLink {
                    MemberReportView(member: member, dataStore: dataStore)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .frame(width: 36, height: 36)
                            .background(.blue.opacity(0.12), in: .rect(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("レポートを見る")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("勉強時間・教科別の詳細")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                if member.id != dataStore.currentUser?.id {
                    if blockService.isBlocked(member.id) {
                        Button {
                            showUnblockConfirm = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.raised.slash")
                                Text("ブロックを解除")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            showBlockConfirm = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.raised")
                                Text("このユーザーをブロック")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let sessions = await dataStore.fetchSessionsForMember(member.id)
            let appTime = sessions
                .filter { !$0.isExternal && $0.approvedPhotoCount > 0 }
                .reduce(0) { $0 + $1.studyMode.averageInterval * Double(max(1, $1.approvedPhotoCount)) }
            let externalTime = sessions
                .filter { $0.isExternal }
                .reduce(0) { $0 + Double($1.externalMinutes) * 60 }
            memberTotalStudyTime = appTime + externalTime
        }
        .confirmationDialog("このユーザーをブロックしますか？", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("ブロックする", role: .destructive) {
                withAnimation {
                    blockService.block(member.id)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ブロックすると、このユーザーの投稿やメッセージが非表示になります。ブロックした相手には通知されません。")
        }
        .confirmationDialog("ブロックを解除しますか？", isPresented: $showUnblockConfirm, titleVisibility: .visible) {
            Button("解除する") {
                withAnimation {
                    blockService.unblock(member.id)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("解除すると、このユーザーの投稿やメッセージが再び表示されます。")
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
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
