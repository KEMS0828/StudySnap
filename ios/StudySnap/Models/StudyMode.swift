import Foundation

nonisolated enum StudyMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case shortBreak = "shortBreak"
    case normal = "normal"
    case longSession = "longSession"
    case dev = "dev"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shortBreak: return "スキマ時間"
        case .normal: return "通常"
        case .longSession: return "長時間"
        case .dev: return "開発"
        }
    }

    var subtitle: String {
        switch self {
        case .shortBreak: return "平均5分"
        case .normal: return "平均15分"
        case .longSession: return "平均30分"
        case .dev: return "平均10秒"
        }
    }

    var icon: String {
        switch self {
        case .shortBreak: return "clock.badge.fill"
        case .normal: return "book.fill"
        case .longSession: return "flame.fill"
        case .dev: return "hammer.fill"
        }
    }

    var minInterval: TimeInterval {
        switch self {
        case .shortBreak: return 1
        case .normal: return 1
        case .longSession: return 1
        case .dev: return 1
        }
    }

    var maxInterval: TimeInterval {
        switch self {
        case .shortBreak: return 599
        case .normal: return 1799
        case .longSession: return 3599
        case .dev: return 19
        }
    }

    var averageInterval: TimeInterval {
        (minInterval + maxInterval) / 2.0
    }

    func randomInterval() -> TimeInterval {
        TimeInterval.random(in: minInterval...maxInterval)
    }
}
