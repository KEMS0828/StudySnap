import SwiftUI

struct PostConfirmationView: View {
    let photos: [Data]
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.tint)
                        Text("これで投稿します。\nよろしいですか？")
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                        Text("顔やプライバシーに関わる部分が\nしっかり隠せているか確認してください")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 12) {
                        Text("加工後の写真一覧")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(Array(photos.enumerated()), id: \.offset) { index, photoData in
                            if let uiImage = UIImage(data: photoData) {
                                let aspect = uiImage.size.width / max(uiImage.size.height, 1)
                                VStack(spacing: 4) {
                                    Color(.secondarySystemGroupedBackground)
                                        .aspectRatio(aspect, contentMode: .fit)
                                        .overlay {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .allowsHitTesting(false)
                                        }
                                        .clipShape(.rect(cornerRadius: 12))

                                    Text("\(index + 1) / \(photos.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 120)
            }
            .navigationTitle("投稿の確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("戻る") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onConfirm()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                        Text("投稿する")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .background(.bar)
            }
        }
    }
}
