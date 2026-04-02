import Foundation

struct StudyGroup: Identifiable, Sendable {
    var id: String
    var name: String
    var groupDescription: String
    var adminId: String
    var joinMethod: String
    var createdAt: Date
    var memberIds: [String]
    var pendingMemberIds: [String]
    var groupPhotoUrl: String?

    init(
        name: String,
        groupDescription: String = "",
        adminId: String,
        joinMethod: JoinMethod = .free
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.groupDescription = groupDescription
        self.adminId = adminId
        self.joinMethod = joinMethod.rawValue
        self.createdAt = .now
        self.memberIds = [adminId]
        self.pendingMemberIds = []
    }

    var method: JoinMethod {
        JoinMethod(rawValue: joinMethod) ?? .free
    }

    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "name": name,
            "groupDescription": groupDescription,
            "adminId": adminId,
            "joinMethod": joinMethod,
            "createdAt": createdAt.timeIntervalSince1970,
            "memberIds": memberIds,
            "pendingMemberIds": pendingMemberIds
        ]
        if let v = groupPhotoUrl { data["groupPhotoUrl"] = v }
        return data
    }

    static func fromFirestore(_ data: [String: Any], id: String) -> StudyGroup {
        var group = StudyGroup(name: "", adminId: "")
        group.id = id
        group.name = data["name"] as? String ?? ""
        group.groupDescription = data["groupDescription"] as? String ?? ""
        group.adminId = data["adminId"] as? String ?? ""
        group.joinMethod = data["joinMethod"] as? String ?? "free"
        group.memberIds = data["memberIds"] as? [String] ?? []
        group.pendingMemberIds = data["pendingMemberIds"] as? [String] ?? []
        group.groupPhotoUrl = data["groupPhotoUrl"] as? String
        if let ts = data["createdAt"] as? TimeInterval {
            group.createdAt = Date(timeIntervalSince1970: ts)
        }
        return group
    }
}

nonisolated enum JoinMethod: String, CaseIterable, Identifiable, Codable, Sendable {
    case free = "free"
    case approval = "approval"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: return "自由参加"
        case .approval: return "承認制"
        }
    }

    var icon: String {
        switch self {
        case .free: return "door.left.hand.open"
        case .approval: return "lock.shield.fill"
        }
    }
}
