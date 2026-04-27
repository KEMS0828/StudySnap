import Foundation
import SwiftUI

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
        case .dev: return "開発用"
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
        let lo = minInterval
        let hi = maxInterval
        let span = hi - lo
        guard span > 0 else { return lo }
        let q = span / 4.0
        let r = Double.random(in: 0..<6)
        let bucketStart: TimeInterval
        if r < 1 {
            bucketStart = lo
        } else if r < 3 {
            bucketStart = lo + q
        } else if r < 5 {
            bucketStart = lo + 2 * q
        } else {
            bucketStart = lo + 3 * q
        }
        return TimeInterval.random(in: bucketStart...(bucketStart + q))
    }

    @MainActor
    var tintColor: Color {
        switch self {
        case .shortBreak: return .teal
        case .normal: return .blue
        case .longSession: return .orange
        case .dev: return .purple
        }
    }
}
