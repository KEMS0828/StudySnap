import SwiftUI

struct MembersStatusRowView: View {
    let members: [UserProfile]
    let studyingMemberIds: Set<String>
    let dataStore: DataStore
    var onSelect: (UserProfile) -> Void

    private let avatarSize: CGFloat = 34

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 3) {
                ForEach(members, id: \.id) { member in
                    memberButton(member: member)
                }
            }
            .padding(.vertical, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 3) {
                    ForEach(members, id: \.id) { member in
                        memberButton(member: member)
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 56)
                .frame(maxWidth: .infinity)
            }
            .contentMargins(.horizontal, 0)
        }
    }

    @ViewBuilder
    private func memberButton(member: UserProfile) -> some View {
        Button {
            onSelect(member)
        } label: {
            memberCell(member: member)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func memberCell(member: UserProfile) -> some View {
        let isStudying = studyingMemberIds.contains(member.id)
        VStack(spacing: 2) {
            ZStack {
                ProfileAvatarView(photoUrl: member.profilePhotoUrl, name: member.name, size: avatarSize)
                if isStudying {
                    Circle()
                        .strokeBorder(Color.red, lineWidth: 2)
                        .frame(width: avatarSize + 4, height: avatarSize + 4)
                }
            }
            .frame(width: avatarSize + 4, height: avatarSize + 4)
        }
    }
}
