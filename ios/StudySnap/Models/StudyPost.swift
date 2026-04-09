import Foundation

nonisolated struct StudyPost: Identifiable, Sendable {
    var id: String
    var sessionId: String
    var userId: String
    var userName: String
    var groupId: String
    var subject: String
    var reflection: String
    var photoUrls: [String]
    var duration: TimeInterval
    var createdAt: Date
    var isApproved: Bool
    var approvedByUserId: String?
    var approvedByUserName: String?
    var approvedAt: Date?
    var photoApproved: [Bool]
    var photoApprovedByNames: [String]
    var photoApprovedAt: [Double]
    var userPhotoUrl: String?

    init(
        sessionId: String,
        userId: String,
        userName: String,
        groupId: String,
        subject: String,
        reflection: String,
        photoUrls: [String],
        duration: TimeInterval
    ) {
        self.id = UUID().uuidString
        self.sessionId = sessionId
        self.userId = userId
        self.userName = userName
        self.groupId = groupId
        self.subject = subject
        self.reflection = reflection
        self.photoUrls = photoUrls
        self.duration = duration
        self.createdAt = .now
        self.isApproved = false
        self.approvedByUserId = nil
        self.approvedByUserName = nil
        self.approvedAt = nil
        self.photoApproved = Array(repeating: false, count: photoUrls.count)
        self.photoApprovedByNames = Array(repeating: "", count: photoUrls.count)
        self.photoApprovedAt = Array(repeating: 0, count: photoUrls.count)
        self.userPhotoUrl = nil
    }

    var formattedDuration: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分\(seconds)秒"
        }
        return "\(minutes)分\(seconds)秒"
    }

    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "sessionId": sessionId,
            "userId": userId,
            "userName": userName,
            "groupId": groupId,
            "subject": subject,
            "reflection": reflection,
            "photoUrls": photoUrls,
            "duration": duration,
            "createdAt": createdAt.timeIntervalSince1970,
            "isApproved": isApproved,
            "photoApproved": photoApproved,
            "photoApprovedByNames": photoApprovedByNames,
            "photoApprovedAt": photoApprovedAt
        ]
        if let v = approvedByUserId { data["approvedByUserId"] = v }
        if let v = approvedByUserName { data["approvedByUserName"] = v }
        if let v = approvedAt { data["approvedAt"] = v.timeIntervalSince1970 }
        if let v = userPhotoUrl { data["userPhotoUrl"] = v }
        return data
    }

    static func fromFirestore(_ data: [String: Any], id: String) -> StudyPost {
        var post = StudyPost(
            sessionId: data["sessionId"] as? String ?? "",
            userId: data["userId"] as? String ?? "",
            userName: data["userName"] as? String ?? "",
            groupId: data["groupId"] as? String ?? "",
            subject: data["subject"] as? String ?? "",
            reflection: data["reflection"] as? String ?? "",
            photoUrls: data["photoUrls"] as? [String] ?? [],
            duration: data["duration"] as? TimeInterval ?? 0
        )
        post.id = id
        if let ts = data["createdAt"] as? TimeInterval {
            post.createdAt = Date(timeIntervalSince1970: ts)
        }
        post.isApproved = data["isApproved"] as? Bool ?? false
        post.approvedByUserId = data["approvedByUserId"] as? String
        post.approvedByUserName = data["approvedByUserName"] as? String
        if let ts = data["approvedAt"] as? TimeInterval {
            post.approvedAt = Date(timeIntervalSince1970: ts)
        }
        let photoCount = post.photoUrls.count
        let rawApproved = data["photoApproved"] as? [Bool] ?? Array(repeating: false, count: photoCount)
        let rawNames = data["photoApprovedByNames"] as? [String] ?? Array(repeating: "", count: photoCount)
        let rawAt = data["photoApprovedAt"] as? [Double] ?? Array(repeating: 0, count: photoCount)
        if rawApproved.count == photoCount {
            post.photoApproved = rawApproved
        } else {
            post.photoApproved = (0..<photoCount).map { $0 < rawApproved.count ? rawApproved[$0] : false }
        }
        if rawNames.count == photoCount {
            post.photoApprovedByNames = rawNames
        } else {
            post.photoApprovedByNames = (0..<photoCount).map { $0 < rawNames.count ? rawNames[$0] : "" }
        }
        if rawAt.count == photoCount {
            post.photoApprovedAt = rawAt
        } else {
            post.photoApprovedAt = (0..<photoCount).map { $0 < rawAt.count ? rawAt[$0] : 0 }
        }
        post.userPhotoUrl = data["userPhotoUrl"] as? String
        return post
    }
}
