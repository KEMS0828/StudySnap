import Foundation

nonisolated struct StudyGoal: Identifiable, Sendable {
    var id: String
    var ownerUserId: String
    var title: String
    var targetMinutes: Int
    var goalType: String
    var createdAt: Date
    var weekStartDate: Date?
    var isCompleted: Bool

    init(ownerUserId: String, title: String, targetMinutes: Int, goalType: GoalType, weekStartDate: Date? = nil) {
        self.id = UUID().uuidString
        self.ownerUserId = ownerUserId
        self.title = title
        self.targetMinutes = targetMinutes
        self.goalType = goalType.rawValue
        self.createdAt = .now
        self.weekStartDate = weekStartDate
        self.isCompleted = false
    }

    var type: GoalType {
        GoalType(rawValue: goalType) ?? .daily
    }

    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "ownerUserId": ownerUserId,
            "title": title,
            "targetMinutes": targetMinutes,
            "goalType": goalType,
            "createdAt": createdAt.timeIntervalSince1970,
            "isCompleted": isCompleted
        ]
        if let v = weekStartDate { data["weekStartDate"] = v.timeIntervalSince1970 }
        return data
    }

    static func fromFirestore(_ data: [String: Any], id: String) -> StudyGoal {
        var goal = StudyGoal(ownerUserId: "", title: "", targetMinutes: 0, goalType: .daily)
        goal.id = id
        goal.ownerUserId = data["ownerUserId"] as? String ?? ""
        goal.title = data["title"] as? String ?? ""
        goal.targetMinutes = data["targetMinutes"] as? Int ?? 0
        goal.goalType = data["goalType"] as? String ?? "daily"
        if let ts = data["createdAt"] as? TimeInterval {
            goal.createdAt = Date(timeIntervalSince1970: ts)
        }
        if let ts = data["weekStartDate"] as? TimeInterval {
            goal.weekStartDate = Date(timeIntervalSince1970: ts)
        }
        goal.isCompleted = data["isCompleted"] as? Bool ?? false
        return goal
    }
}

nonisolated enum GoalType: String, CaseIterable, Identifiable, Codable, Sendable {
    case daily = "daily"
    case weekly = "weekly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "今日の目標"
        case .weekly: return "今週の目標"
        }
    }

    var icon: String {
        switch self {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar"
        }
    }
}
