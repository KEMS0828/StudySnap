import Foundation

nonisolated enum StudyMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case shortBreak = "shortBreak"
    case normal = "normal"
    case longSession = "longSession"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shortBreak: return "スキマ時間"
        case .normal: return "通常"
        case .longSession: return "長時間"
        }
    }

    var subtitle: String {
        switch self {
        case .shortBreak: return "平均5分"
        case .normal: return "平均15分"
        case .longSession: return "平均30分"
        }
    }

    var icon: String {
        switch self {
        case .shortBreak: return "clock.badge.fill"
        case .normal: return "book.fill"
        case .longSession: return "flame.fill"
        }
    }

    var minInterval: TimeInterval {
        switch self {
        case .shortBreak: return 180
        case .normal: return 600
        case .longSession: return 1200
        }
    }

    var maxInterval: TimeInterval {
        switch self {
        case .shortBreak: return 420
        case .normal: return 1200
        case .longSession: return 2400
        }
    }

    var averageInterval: TimeInterval {
        (minInterval + maxInterval) / 2.0
    }

    func randomInterval() -> TimeInterval {
        let avg = (minInterval + maxInterval) / 2.0
        let actualMax = avg * 2.0 - 1.0
        return TimeInterval.random(in: 1.0...actualMax)
    }
}
