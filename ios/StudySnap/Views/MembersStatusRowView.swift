import SwiftUI

struct MembersStatusRowView: View {
    let members: [UserProfile]
    let studyingMemberIds: Set<String>
    let dataStore: DataStore
    var onSelect: (UserProfile) -> Void

    private let avatarSize: CGFloat = 34
    private let trailingReserved: CGFloat = 72

    @State private var isAtTrailingEdge: Bool = false
    @State private var hasOverflow: Bool = false

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
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(sortedMembers.enumerated()), id: \.element.id) { _, member in
                    memberButton(member: member)
                }
            }
            .padding(.vertical, 1)
            .padding(.trailing, trailingReserved)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ContentWidthKey.self, value: proxy.size.width)
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .onPreferenceChange(ContentWidthKey.self) { _ in }
        .onScrollGeometryChange(for: ScrollEdgeState.self) { geo in
            let maxX = max(0, geo.contentSize.width - geo.containerSize.width)
            let atEnd = geo.contentOffset.x >= maxX - 1
            let overflow = geo.contentSize.width > geo.containerSize.width + 1
            return ScrollEdgeState(atEnd: atEnd, hasOverflow: overflow)
        } action: { _, newValue in
            isAtTrailingEdge = newValue.atEnd
            hasOverflow = newValue.hasOverflow
        }
        .overlay(alignment: .trailing) {
            if hasOverflow && !isAtTrailingEdge {
                scrollHint
                    .padding(.trailing, trailingReserved - 6)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isAtTrailingEdge)
        .animation(.easeInOut(duration: 0.2), value: hasOverflow)
    }

    private var scrollHint: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.55))
                    .frame(width: 3, height: 3)
                    .opacity(1.0 - Double(i) * 0.25)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
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
        .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }

    @ViewBuilder
    private func memberCell(member: UserProfile) -> some View {
        let isStudying = studyingMemberIds.contains(member.id)
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
        .frame(width: avatarSize + 8, height: avatarSize + 8)
    }
}

private struct ContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollEdgeState: Equatable {
    var atEnd: Bool
    var hasOverflow: Bool
}
