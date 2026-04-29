import SwiftUI
import PhotosUI

struct EditGroupView: View {
    let dataStore: DataStore
    let group: StudyGroup
    @Binding var isPresented: Bool

    @State private var name: String
    @State private var description: String
    @State private var joinMethod: JoinMethod
    @State private var groupPhotoData: Data?
    @State private var existingPhotoUrl: String?
    @State private var showNGWordAlert = false
    @State private var isSaving = false

    init(dataStore: DataStore, group: StudyGroup, isPresented: Binding<Bool>) {
        self.dataStore = dataStore
        self.group = group
        self._isPresented = isPresented
        self._name = State(initialValue: group.name)
        self._description = State(initialValue: group.groupDescription)
        self._joinMethod = State(initialValue: group.method)
        self._existingPhotoUrl = State(initialValue: group.groupPhotoUrl)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        GroupPhotoEditPicker(
                            photoData: $groupPhotoData,
                            existingPhotoUrl: existingPhotoUrl,
                            size: 90
                        )
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("グループ名", text: $name)
                    TextField("説明（任意）", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("基本情報")
                }

                Section {
                    Picker("参加方法", selection: $joinMethod) {
                        ForEach(JoinMethod.allCases) { method in
                            Label(method.title, systemImage: method.icon)
                                .tag(method)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("参加方法")
                } footer: {
                    Text(joinMethod == .free
                         ? "誰でも自由に参加できます"
                         : "管理者が参加リクエストを承認する必要があります")
                }
            }
            .navigationTitle("グループ情報を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("保存") { save() }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .alert("不適切な表現が含まれています", isPresented: $showNGWordAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("内容を修正してください。")
            }
        }
    }

    private func save() {
        if NGWordFilter.containsNGWord(in: name, description) {
            showNGWordAlert = true
            return
        }
        isSaving = true
        Task {
            await dataStore.updateGroupInfo(
                groupId: group.id,
                name: name,
                description: description,
                joinMethod: joinMethod,
                newPhotoData: groupPhotoData
            )
            isSaving = false
            isPresented = false
        }
    }
}

struct GroupPhotoEditPicker: View {
    @Binding var photoData: Data?
    let existingPhotoUrl: String?
    var size: CGFloat = 80

    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        if photoData == nil, let urlString = existingPhotoUrl, let url = URL(string: urlString) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    CachedImageView(url: url)
                        .frame(width: size, height: size)
                        .clipShape(.rect(cornerRadius: size * 0.2))
                        .allowsHitTesting(false)

                    Circle()
                        .fill(.indigo)
                        .frame(width: size * 0.3, height: size * 0.3)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: size * 0.13))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        .allowsHitTesting(false)
                }
            }
            .buttonStyle(.plain)
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        photoData = compressImage(uiImage)
                    }
                }
            }
        } else {
            GroupPhotoPickerView(photoData: $photoData, size: size)
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
