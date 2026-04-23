import SwiftUI

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

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if photoData != nil {
                GroupPhotoPickerView(photoData: $photoData, size: size)
            } else if let urlString = existingPhotoUrl, let url = URL(string: urlString) {
                ZStack(alignment: .bottomTrailing) {
                    CachedImageView(url: url)
                        .frame(width: size, height: size)
                        .clipShape(.rect(cornerRadius: size * 0.2))
                    GroupPhotoPickerView(photoData: $photoData, size: size)
                        .opacity(0.01)
                        .frame(width: size, height: size)
                }
            } else {
                GroupPhotoPickerView(photoData: $photoData, size: size)
            }
        }
    }
}
