import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    let dataStore: DataStore
    @State private var profileName: String = ""
    @State private var selectedAgeGroup: AgeGroup?
    @State private var selectedGender: Gender?
    @State private var selectedOccupation: Occupation?
    @State private var profilePhotoData: Data?
    @State private var currentStep: Int = 0
    @State private var showNGWordAlert: Bool = false
    @FocusState private var isNameFieldFocused: Bool

    private var isNameValid: Bool {
        !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color.indigo.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentStep ? Color.indigo : Color(.systemGray4))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                TabView(selection: $currentStep) {
                    photoStep.tag(0)
                    nameStep.tag(1)
                    ageStep.tag(2)
                    genderStep.tag(3)
                    occupationStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(duration: 0.4), value: currentStep)

                VStack(spacing: 12) {
                    Button {
                        if currentStep == 1 {
                            isNameFieldFocused = false
                        }
                        if currentStep == 1 && NGWordFilter.containsNGWord(in: profileName) {
                            showNGWordAlert = true
                        } else if currentStep < 4 {
                            withAnimation { currentStep += 1 }
                        } else {
                            if NGWordFilter.containsNGWord(in: profileName) {
                                showNGWordAlert = true
                            } else {
                                saveProfile()
                            }
                        }
                    } label: {
                        Text(currentStep < 4 ? "次へ" : "はじめる")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .disabled(currentStep == 1 && !isNameValid)

                    if currentStep > 0 {
                        Button {
                            withAnimation { currentStep -= 1 }
                        } label: {
                            Text("戻る")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .alert("不適切な表現が含まれています", isPresented: $showNGWordAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("内容を修正してください。")
        }
    }

    private var photoStep: some View {
        VStack(spacing: 24) {
            Spacer()

            ProfilePhotoPickerView(photoData: $profilePhotoData, size: 120)

            VStack(spacing: 8) {
                Text("プロフィール写真")
                    .font(.title2.bold())
                Text("あなたの写真を設定しましょう")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("あとからでも変更できます")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var nameStep: some View {
        VStack(spacing: 24) {
            Spacer()

            ProfileAvatarView(photoUrl: nil, name: profileName.isEmpty ? "?" : profileName, size: 64)

            VStack(spacing: 8) {
                Text("プロフィールネーム")
                    .font(.title2.bold())
                Text("みんなに表示される名前です")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("ニックネームを入力", text: $profileName)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 14))
                .padding(.horizontal, 24)
                .focused($isNameFieldFocused)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var ageStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo.opacity(0.7))

            VStack(spacing: 8) {
                Text("年齢")
                    .font(.title2.bold())
                Text("年代を選んでください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(AgeGroup.allCases, id: \.self) { age in
                    Button {
                        selectedAgeGroup = age
                    } label: {
                        HStack {
                            Text(age.rawValue)
                                .fontWeight(.medium)
                            Spacer()
                            if selectedAgeGroup == age {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .padding(14)
                        .background(selectedAgeGroup == age ? Color.indigo.opacity(0.1) : Color(.tertiarySystemBackground))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var genderStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo.opacity(0.7))

            VStack(spacing: 8) {
                Text("性別")
                    .font(.title2.bold())
                Text("性別を選んでください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    Button {
                        selectedGender = gender
                    } label: {
                        HStack {
                            Text(gender.rawValue)
                                .fontWeight(.medium)
                            Spacer()
                            if selectedGender == gender {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .padding(14)
                        .background(selectedGender == gender ? Color.indigo.opacity(0.1) : Color(.tertiarySystemBackground))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var occupationStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "briefcase.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo.opacity(0.7))

            VStack(spacing: 8) {
                Text("職業")
                    .font(.title2.bold())
                Text("あなたの職業を選んでください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(Occupation.allCases, id: \.self) { occupation in
                    Button {
                        selectedOccupation = occupation
                    } label: {
                        HStack {
                            Text(occupation.rawValue)
                                .fontWeight(.medium)
                            Spacer()
                            if selectedOccupation == occupation {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .padding(14)
                        .background(selectedOccupation == occupation ? Color.indigo.opacity(0.1) : Color(.tertiarySystemBackground))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func saveProfile() {
        guard var user = dataStore.currentUser else { return }
        let trimmed = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.name = trimmed.isEmpty ? "あなた" : trimmed
        user.ageGroup = selectedAgeGroup?.rawValue
        user.gender = selectedGender?.rawValue
        user.occupation = selectedOccupation?.rawValue
        user.isProfileCompleted = true

        Task {
            if let photoData = profilePhotoData {
                let url = await dataStore.uploadProfilePhoto(photoData)
                user.profilePhotoUrl = url
            }
            dataStore.saveUserProfile(user)
        }
    }
}
