import SwiftUI

struct CachedImageView: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    var onImageLoaded: ((CGSize) -> Void)? = nil
    @State private var image: UIImage?
    @State private var isLoading: Bool = true
    @State private var failed: Bool = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if failed {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundStyle(.tertiary)
            } else {
                ProgressView()
            }
        }
        .task(id: url) {
            guard let url else {
                failed = true
                return
            }
            if let cached = ImageCache.shared.image(for: url) {
                image = cached
                isLoading = false
                onImageLoaded?(cached.size)
                return
            }
            isLoading = true
            if let loaded = await ImageCache.shared.loadImage(from: url) {
                image = loaded
                isLoading = false
                onImageLoaded?(loaded.size)
            } else {
                failed = true
                isLoading = false
            }
        }
    }
}
