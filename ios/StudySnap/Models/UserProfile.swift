import Foundation
import FirebaseFirestore

nonisolated enum AgeGroup: String, Codable, Sendable, CaseIterable {
    case teens10 = "10代"
    case teens20 = "20代"
    case teens30 = "30代"
    case teens40 = "40代"
    case teens50 = "50代以上"
}

nonisolated enum Gender: String, Codable, Sendable, CaseIterable {
    case male = "男性"
    case female = "女性"
    case unspecified = "選択しない"
}

nonisolated enum Occupation: String, Codable, Sendable, CaseIterable {
    case elementary = "小学生"
    case middleSchool = "中学生"
    case highSchool = "高校生"
    case university = "大学生"
    case vocational = "専門学生"
    case working = "社会人"
}

nonisolated struct UserProfile: Identifiable, Sendable {
    var id: String
    var name: String
    var ageGroup: String?
    var gender: String?
    var occupation: String?
    var isProfileCompleted: Bool
    var currentGroupId: String?
    var isAdmin: Bool
    var totalStudyTime: TimeInterval
    var profilePhotoUrl: String?
    var bio: String?
    var studyGoalText: String?
    var isPhoneVerified: Bool
    var createdAt: Date

    init(authUserId: String, name: String = "あなた") {
        self.id = authUserId
        self.name = name
        self.ageGroup = nil
        self.gender = nil
        self.occupation = nil
        self.isProfileCompleted = false
        self.currentGroupId = nil
        self.isAdmin = false
        self.totalStudyTime = 0
        self.profilePhotoUrl = nil
        self.bio = nil
        self.studyGoalText = nil
        self.isPhoneVerified = false
        self.createdAt = .now
    }

    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "name": name,
            "isProfileCompleted": isProfileCompleted,
            "isAdmin": isAdmin,
            "totalStudyTime": totalStudyTime,
            "createdAt": createdAt.timeIntervalSince1970
        ]
        if let v = ageGroup { data["ageGroup"] = v }
        if let v = gender { data["gender"] = v }
        if let v = occupation { data["occupation"] = v }
        if let v = currentGroupId { data["currentGroupId"] = v } else { data["currentGroupId"] = FieldValue.delete() }
        if let v = profilePhotoUrl { data["profilePhotoUrl"] = v }
        if let v = bio { data["bio"] = v }
        if let v = studyGoalText { data["studyGoalText"] = v }
        data["isPhoneVerified"] = isPhoneVerified
        return data
    }

    static func fromFirestore(_ data: [String: Any], id: String) -> UserProfile {
        var user = UserProfile(authUserId: id)
        user.name = data["name"] as? String ?? "あなた"
        user.ageGroup = data["ageGroup"] as? String
        user.gender = data["gender"] as? String
        user.occupation = data["occupation"] as? String
        user.isProfileCompleted = data["isProfileCompleted"] as? Bool ?? false
        user.currentGroupId = data["currentGroupId"] as? String
        user.isAdmin = data["isAdmin"] as? Bool ?? false
        user.totalStudyTime = data["totalStudyTime"] as? TimeInterval ?? 0
        user.profilePhotoUrl = data["profilePhotoUrl"] as? String
        user.bio = data["bio"] as? String
        user.studyGoalText = data["studyGoalText"] as? String
        user.isPhoneVerified = data["isPhoneVerified"] as? Bool ?? false
        if let ts = data["createdAt"] as? TimeInterval {
            user.createdAt = Date(timeIntervalSince1970: ts)
        }
        return user
    }
}
