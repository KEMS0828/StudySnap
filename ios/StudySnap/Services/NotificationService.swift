import Foundation
import UserNotifications

@Observable
final class NotificationService {
    static let shared = NotificationService()

    var isReminderEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isReminderEnabled, forKey: "studyReminderEnabled")
            if isReminderEnabled {
                scheduleReminder()
            } else {
                cancelReminder()
            }
        }
    }

    var reminderTime: Date = {
        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        return Calendar.current.date(from: components) ?? .now
    }() {
        didSet {
            UserDefaults.standard.set(reminderTime.timeIntervalSince1970, forKey: "studyReminderTime")
            if isReminderEnabled {
                scheduleReminder()
            }
        }
    }

    private(set) var currentStreak: Int = 0

    func updateStreak(_ streak: Int) {
        let changed = streak != currentStreak
        currentStreak = streak
        if changed && isReminderEnabled {
            scheduleReminder()
        }
    }

    private init() {
        isReminderEnabled = UserDefaults.standard.bool(forKey: "studyReminderEnabled")
        let savedTime = UserDefaults.standard.double(forKey: "studyReminderTime")
        if savedTime > 0 {
            reminderTime = Date(timeIntervalSince1970: savedTime)
        }
    }

    func requestPermissionAndEnable() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                return true
            } else {
                return false
            }
        } catch {
            return false
        }
    }

    func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["studyReminder"])

        let content = UNMutableNotificationContent()
        content.title = "StudySnap"
        if currentStreak > 0 {
            content.body = "現在 \(currentStreak)日連続で勉強中！🔥 今日も続けましょう📚"
        } else {
            content.body = "今日から新しい連続記録を始めましょう！📚"
        }
        content.sound = .default

        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.hour = calendar.component(.hour, from: reminderTime)
        dateComponents.minute = calendar.component(.minute, from: reminderTime)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "studyReminder", content: content, trigger: trigger)

        center.add(request)
    }

    func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["studyReminder"])
    }
}
