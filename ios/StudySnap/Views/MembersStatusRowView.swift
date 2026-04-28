import SwiftUI

struct MembersStatusRowView: View {
    let members: [UserProfile]
    let studyingMemberIds: Set<String>
    let dataStore: DataStore
    var onSelect: (UserProfile) -> Void

    private let avatarSize: CGFloat = 40

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(members, id: \.id) { member in
                    Button {
                        onSelect(member)
                    } label: {
                        memberCell(member: member)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .contentMargins(.horizontal, 0)
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

            if isStudying {
                Text("勉強中")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}
