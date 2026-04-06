import Foundation

nonisolated enum QuickMessage: String, CaseIterable, Sendable {
    case greeting = "よろしくお願いします！"
    case nice = "ナイス👍"
    case goodWork = "お疲れ！"
    case fight = "ファイト🔥"
    case together = "一緒に頑張ろう"
    case cheer = "応援してる💪"
}

nonisolated struct ChatMessage: Identifiable, Sendable {
    var id: String
    var groupId: String
    var userId: String
    var userName: String
    var userPhotoUrl: String?
    var message: String
    var createdAt: Date

    init(groupId: String, userId: String, userName: String, userPhotoUrl: String?, message: String) {
        self.id = UUID().uuidString
        self.groupId = groupId
        self.userId = userId
        self.userName = userName
        self.userPhotoUrl = userPhotoUrl
        self.message = message
        self.createdAt = .now
    }

    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "groupId": groupId,
            "userId": userId,
            "userName": userName,
            "message": message,
            "createdAt": createdAt.timeIntervalSince1970
        ]
        if let v = userPhotoUrl { data["userPhotoUrl"] = v }
        return data
    }

    static func fromFirestore(_ data: [String: Any], id: String) -> ChatMessage {
        var msg = ChatMessage(
            groupId: data["groupId"] as? String ?? "",
            userId: data["userId"] as? String ?? "",
            userName: data["userName"] as? String ?? "",
            userPhotoUrl: data["userPhotoUrl"] as? String,
            message: data["message"] as? String ?? ""
        )
        msg.id = id
        if let ts = data["createdAt"] as? TimeInterval {
            msg.createdAt = Date(timeIntervalSince1970: ts)
        }
        return msg
    }
}
