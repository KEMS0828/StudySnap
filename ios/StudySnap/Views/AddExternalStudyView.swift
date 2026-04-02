import SwiftUI

struct AddExternalStudyView: View {
    let dataStore: DataStore
    @Binding var isPresented: Bool

    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var selectedSubject: String = ""
    @State private var showSubjectPicker: Bool = false

    private var totalMinutes: Int {
        hours * 60 + minutes
    }

    private var isValid: Bool {
        totalMinutes > 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("勉強時間")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Picker("", selection: $hours) {
                            ForEach(0..<24, id: \.self) { h in
                                Text("\(h)").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60, height: 120)
                        .clipped()

                        Text("時間")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("", selection: $minutes) {
                            ForEach(0..<60, id: \.self) { m in
                                Text("\(m)").tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60, height: 120)
                        .clipped()

                        Text("分")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("教科")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Button {
                        showSubjectPicker = true
                    } label: {
                        HStack {
                            if selectedSubject.isEmpty {
                                Text("教科を選択")
                                    .foregroundStyle(.secondary)
                            } else {
                                HStack(spacing: 8) {
                                    if let color = SubjectColorStore.color(for: selectedSubject) {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 10, height: 10)
                                    }
                                    Text(selectedSubject)
                                        .foregroundStyle(.primary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .navigationTitle("アプリ外の記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showSubjectPicker) {
                ExternalSubjectSelectionView(isPresented: $showSubjectPicker) { subject in
                    selectedSubject = subject
                    showSubjectPicker = false
                }
            }
        }
    }

    private func save() {
        guard totalMinutes > 0 else { return }
        dataStore.saveExternalSession(
            minutes: totalMinutes,
            subject: selectedSubject,
            date: .now
        )
        isPresented = false
    }
}
