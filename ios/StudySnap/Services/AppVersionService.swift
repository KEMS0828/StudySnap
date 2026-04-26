import Foundation

@Observable
final class AppVersionService {
    enum UpdateStatus {
        case unknown
        case upToDate
        case updateRequired(latest: String, current: String)
    }

    static let appStoreURL = URL(string: "https://apps.apple.com/jp/app/studysnap/id6761254323")!
    private static let appID = "6761254323"

    var status: UpdateStatus = .unknown

    func check() async {
        #if DEBUG
        self.status = .upToDate
        return
        #else
        guard let current = Self.currentVersion() else { return }
        guard let latest = await Self.fetchLatestVersion() else { return }

        if Self.compare(latest, current) == .orderedDescending {
            self.status = .updateRequired(latest: latest, current: current)
        } else {
            self.status = .upToDate
        }
        #endif
    }

    static func currentVersion() -> String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    private static func fetchLatestVersion() async -> String? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: appID),
            URLQueryItem(name: "country", value: "jp"),
            URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let version = first["version"] as? String else {
                return nil
            }
            return version
        } catch {
            return nil
        }
    }

    private static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let aParts = a.split(separator: ".").map { Int($0) ?? 0 }
        let bParts = b.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(aParts.count, bParts.count)
        for i in 0..<count {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av > bv { return .orderedDescending }
            if av < bv { return .orderedAscending }
        }
        return .orderedSame
    }
}
