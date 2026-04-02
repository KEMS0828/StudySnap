import Foundation

struct StudySession: Identifiable, Sendable {
    var id: String
    var startTime: Date
    var endTime: Date?
    var mode: String
    var subject: String
    var reflection: String
    var isApproved: Bool
    var approvedBy: String?
    var groupId: String?
    var ownerUserId: String?
    var approvedPhotoCount: Int
    var isExternal: Bool
    var externalMinutes: Int

    init(
        mode: StudyMode,
        groupId: String? = nil
    ) {
        self.id = UUID().uuidString
        self.startTime = .now
        self.endTime = nil
        self.mode = mode.rawValue
        self.subject = ""
        self.reflection = ""
        self.isApproved = false
        self.approvedBy = nil
        self.groupId = groupId
        self.ownerUserId = nil
        self.approvedPhotoCount = 0
        self.isExternal = false
        self.externalMinutes = 0
    }

    init(
        externalMinutes: Int,
        subject: String,
        date: Date,
        ownerUserId: String?
    ) {
        self.id = UUID().uuidString
        self.startTime = date
        self.endTime = date.addingTimeInterval(Double(externalMinutes) * 60)
        self.mode = StudyMode.normal.rawValue
        self.subject = subject
        self.reflection = ""
        self.isApproved = true
        self.approvedBy = nil
        self.groupId = nil
        self.ownerUserId = ownerUserId
        self.approvedPhotoCount = 0
        self.isExternal = true
        self.externalMinutes = externalMinutes
    }

    var duration: TimeInterval {
        let end = endTime ?? .now
        return end.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var studyMode: StudyMode {
        StudyMode(rawValue: mode) ?? .normal
    }

    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "startTime": startTime.timeIntervalSince1970,
            "mode": mode,
            "subject": subject,
            "reflection": reflection,
            "isApproved": isApproved
        ]
        if let v = endTime { data["endTime"] = v.timeIntervalSince1970 }
        if let v = approvedBy { data["approvedBy"] = v }
        if let v = groupId { data["groupId"] = v }
        if let v = ownerUserId { data["ownerUserId"] = v }
        data["approvedPhotoCount"] = approvedPhotoCount
        data["isExternal"] = isExternal
        data["externalMinutes"] = externalMinutes
        return data
    }

    static func fromFirestore(_ data: [String: Any], id: String) -> StudySession {
        var session = StudySession(mode: .normal)
        session.id = id
        if let ts = data["startTime"] as? TimeInterval {
            session.startTime = Date(timeIntervalSince1970: ts)
        }
        if let ts = data["endTime"] as? TimeInterval {
            session.endTime = Date(timeIntervalSince1970: ts)
        }
        session.mode = data["mode"] as? String ?? "normal"
        session.subject = data["subject"] as? String ?? ""
        session.reflection = data["reflection"] as? String ?? ""
        session.isApproved = data["isApproved"] as? Bool ?? false
        session.approvedBy = data["approvedBy"] as? String
        session.groupId = data["groupId"] as? String
        session.ownerUserId = data["ownerUserId"] as? String
        session.approvedPhotoCount = data["approvedPhotoCount"] as? Int ?? (session.isApproved ? 1 : 0)
        session.isExternal = data["isExternal"] as? Bool ?? false
        session.externalMinutes = data["externalMinutes"] as? Int ?? 0
        return session
    }
}
