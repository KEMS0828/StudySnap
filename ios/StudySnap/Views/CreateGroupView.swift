import SwiftUI

struct CreateGroupView: View {
    let dataStore: DataStore
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var description = ""
    @State private var joinMethod: JoinMethod = .free
    @State private var groupPhotoData: Data?
    @State private var showNGWordAlert: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        GroupPhotoPickerView(photoData: $groupPhotoData, size: 90)
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

                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("作成者が管理者になります。管理者権限は1人のみ持てます。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("グループ作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        if NGWordFilter.containsNGWord(in: name, description) {
                            showNGWordAlert = true
                        } else {
                            dataStore.createGroup(name: name, description: description, joinMethod: joinMethod, photoData: groupPhotoData)
                            isPresented = false
                        }
                    }
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
