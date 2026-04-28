import SwiftUI

struct MembersStatusRowView: View {
    let members: [UserProfile]
    let studyingMemberIds: Set<String>
    let dataStore: DataStore
    var onSelect: (UserProfile) -> Void

    var body: some View {
        GeometryReader { geo in
            let count = max(members.count, 1)
            let spacing: CGFloat = 6
            let totalSpacing = spacing * CGFloat(max(count - 1, 0))
            let cellWidth = max(34, (geo.size.width - totalSpacing) / CGFloat(count))
            let avatarSize = min(48, cellWidth - 4)

            HStack(alignment: .top, spacing: spacing) {
                ForEach(members, id: \.id) { member in
                    Button {
                        onSelect(member)
                    } label: {
                        memberCell(member: member, size: avatarSize, cellWidth: cellWidth)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 64)
    }

    @ViewBuilder
    private func memberCell(member: UserProfile, size: CGFloat, cellWidth: CGFloat) -> some View {
        let isStudying = studyingMemberIds.contains(member.id)
        VStack(spacing: 2) {
            ZStack {
                ProfileAvatarView(photoUrl: member.profilePhotoUrl, name: member.name, size: size)
                if isStudying {
                    Circle()
                        .strokeBorder(Color.red, lineWidth: 2)
                        .frame(width: size + 2, height: size + 2)
                }
            }
            .frame(width: size + 2, height: size + 2)

            if isStudying {
                Text("勉強中")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text(member.name)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: cellWidth)
    }
}
