import SwiftUI

struct MembersStatusRowView: View {
    let members: [UserProfile]
    let studyingMemberIds: Set<String>
    let dataStore: DataStore
    var onSelect: (UserProfile) -> Void

    private let avatarSize: CGFloat = 38

    private var sortedMembers: [UserProfile] {
        members.sorted { a, b in
            let aStudying = studyingMemberIds.contains(a.id)
            let bStudying = studyingMemberIds.contains(b.id)
            if aStudying != bStudying { return aStudying }
            return a.name < b.name
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(sortedMembers.enumerated()), id: \.element.id) { index, member in
                    memberButton(member: member, index: index)
                }
            }
            .padding(.vertical, 4)
            .padding(.trailing, 64)
        }
        .contentMargins(.horizontal, 0)
    }

    @ViewBuilder
    private func memberButton(member: UserProfile, index: Int) -> some View {
        Button {
            onSelect(member)
        } label: {
            memberCell(member: member)
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }

    @ViewBuilder
    private func memberCell(member: UserProfile) -> some View {
        let isStudying = studyingMemberIds.contains(member.id)
        VStack(spacing: 3) {
            ZStack {
                if isStudying {
                    Circle()
                        .fill(Color.red.opacity(0.25))
                        .frame(width: avatarSize + 12, height: avatarSize + 12)
                        .blur(radius: 4)
                }

                ProfileAvatarView(photoUrl: member.profilePhotoUrl, name: member.name, size: avatarSize)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isStudying ? Color.red : Color.white.opacity(0.001),
                                lineWidth: isStudying ? 2.5 : 0
                            )
                    )

                if isStudying {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle().strokeBorder(Color(.systemBackground), lineWidth: 2)
                        )
                        .offset(x: avatarSize / 2 - 4, y: avatarSize / 2 - 4)
                }
            }
            .frame(width: avatarSize + 14, height: avatarSize + 14)

            Text(member.name)
                .font(.system(size: 10, weight: isStudying ? .semibold : .regular))
                .foregroundStyle(isStudying ? Color.red : Color.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: avatarSize + 14)
        }
    }
}
