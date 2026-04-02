import SwiftUI
import PhotosUI

struct ProfilePhotoPickerView: View {
    @Binding var photoData: Data?
    @State private var selectedItem: PhotosPickerItem?
    var size: CGFloat = 80

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            profileImage
        }
        .buttonStyle(.plain)
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    let compressed = compressImage(uiImage)
                    photoData = compressed
                }
            }
        }
    }

    private var profileImage: some View {
        ZStack(alignment: .bottomTrailing) {
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.indigo.opacity(0.4), .purple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(.white.opacity(0.8))
                    }
            }

            Circle()
                .fill(.indigo)
                .frame(width: size * 0.3, height: size * 0.3)
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.system(size: size * 0.13))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
        }
    }

    private func compressImage(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 400
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}

struct ProfileAvatarView: View {
    let photoUrl: String?
    let name: String
    var size: CGFloat = 40

    var body: some View {
        if let photoUrl, let url = URL(string: photoUrl) {
            CachedImageView(url: url)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            placeholderCircle
        }
    }

    private var placeholderCircle: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.indigo, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Text(String(name.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white)
            }
    }
}
