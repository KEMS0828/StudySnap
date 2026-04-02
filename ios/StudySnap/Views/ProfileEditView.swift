import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    let dataStore: DataStore
    @Binding var isPresented: Bool
    @State private var profileName: String = ""
    @State private var selectedAgeGroup: AgeGroup = .teens10
    @State private var selectedGender: Gender = .unspecified
    @State private var selectedOccupation: Occupation = .highSchool
    @State private var profilePhotoData: Data?
    @State private var bio: String = ""
    @State private var studyGoals: [String] = [""]
    @State private var showNGWordAlert: Bool = false
    @State private var isSaving: Bool = false

    private var isNameValid: Bool {
        !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ProfilePhotoPickerView(photoData: $profilePhotoData, size: 90)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    HStack {
                        Text("プロフィールネーム")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("ニックネーム", text: $profileName)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("名前")
                }

                Section {
                    Picker("年代", selection: $selectedAgeGroup) {
                        ForEach(AgeGroup.allCases, id: \.self) { age in
                            Text(age.rawValue).tag(age)
                        }
                    }
                } header: {
                    Text("年齢")
                }

                Section {
                    Picker("性別", selection: $selectedGender) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("性別")
                }

                Section {
                    Picker("職業", selection: $selectedOccupation) {
                        ForEach(Occupation.allCases, id: \.self) { occupation in
                            Text(occupation.rawValue).tag(occupation)
                        }
                    }
                } header: {
                    Text("職業")
                }

                Section {
                    ForEach(studyGoals.indices, id: \.self) { index in
                        HStack(spacing: 8) {
                            Image(systemName: "flag.fill")
                                .font(.caption)
                                .foregroundStyle(.indigo.opacity(0.6))
                            TextField("目標\(index + 1)を入力", text: $studyGoals[index], axis: .vertical)
                                .lineLimit(1...3)
                            if studyGoals.count > 1 {
                                Button {
                                    studyGoals.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button {
                        studyGoals.append("")
                    } label: {
                        Label("目標を追加", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.indigo)
                    }
                } header: {
                    Text("達成目標")
                } footer: {
                    Text("複数の目標を個別に追加できます")
                }

                Section {
                    TextField("自己紹介を入力", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("自己紹介")
                } footer: {
                    Text("グループメンバーに表示されます")
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if NGWordFilter.containsNGWord(in: profileName, bio) {
                            showNGWordAlert = true
                        } else {
                            saveProfile()
                        }
                    }
                    .disabled(!isNameValid || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentProfile()
            }
            .alert("不適切な表現が含まれています", isPresented: $showNGWordAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("内容を修正してください。")
            }
        }
    }

    private func loadCurrentProfile() {
        guard let user = dataStore.currentUser else { return }
        profileName = user.name
        if let ageStr = user.ageGroup, let age = AgeGroup(rawValue: ageStr) {
            selectedAgeGroup = age
        }
        if let genderStr = user.gender, let gender = Gender(rawValue: genderStr) {
            selectedGender = gender
        }
        if let occStr = user.occupation, let occ = Occupation(rawValue: occStr) {
            selectedOccupation = occ
        }
        bio = user.bio ?? ""
        let goals = (user.studyGoalText ?? "").split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        studyGoals = goals.isEmpty ? [""] : goals
    }

    private func saveProfile() {
        guard var user = dataStore.currentUser else { return }
        isSaving = true
        let trimmed = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.name = trimmed.isEmpty ? "あなた" : trimmed
        user.ageGroup = selectedAgeGroup.rawValue
        user.gender = selectedGender.rawValue
        user.occupation = selectedOccupation.rawValue
        user.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGoals = studyGoals.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        user.studyGoalText = trimmedGoals.isEmpty ? nil : trimmedGoals.joined(separator: "\n")

        Task {
            if let photoData = profilePhotoData {
                let url = await dataStore.uploadProfilePhoto(photoData)
                user.profilePhotoUrl = url
            }
            dataStore.saveUserProfile(user)
            isSaving = false
            isPresented = false
        }
    }
}
