import UIKit
import CryptoKit

nonisolated final class ImageCache: Sendable {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let maxDiskAge: TimeInterval = 7 * 24 * 60 * 60

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        memoryCache.countLimit = 80
        memoryCache.totalCostLimit = 50 * 1024 * 1024
        cleanExpiredDiskCache()
    }

    private func cacheKey(for url: URL) -> String {
        let hash = Insecure.SHA1.hash(data: Data(url.absoluteString.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func diskPath(for key: String) -> URL {
        diskCacheURL.appendingPathComponent(key)
    }

    func image(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        let path = diskPath(for: key)
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let img = UIImage(data: data) else {
            return nil
        }
        memoryCache.setObject(img, forKey: key as NSString, cost: data.count)
        return img
    }

    func store(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url)
        let data = image.jpegData(compressionQuality: 0.9)
        let cost = data?.count ?? 0
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
        if let data {
            let path = diskPath(for: key)
            try? data.write(to: path, options: .atomic)
        }
    }

    func loadImage(from url: URL) async -> UIImage? {
        if let cached = image(for: url) {
            return cached
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard var img = UIImage(data: data) else { return nil }
            if img.imageOrientation != .up {
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1.0
                let renderer = UIGraphicsImageRenderer(size: img.size, format: format)
                let normalized = renderer.image { _ in
                    img.draw(in: CGRect(origin: .zero, size: img.size))
                }
                img = normalized
            }
            store(img, for: url)
            return img
        } catch {
            return nil
        }
    }

    private func cleanExpiredDiskCache() {
        DispatchQueue.global(qos: .utility).async { [diskCacheURL, maxDiskAge] in
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(
                at: diskCacheURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ) else { return }
            let cutoff = Date().addingTimeInterval(-maxDiskAge)
            for file in files {
                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let modified = attrs.contentModificationDate,
                      modified < cutoff else { continue }
                try? fm.removeItem(at: file)
            }
        }
    }
}
