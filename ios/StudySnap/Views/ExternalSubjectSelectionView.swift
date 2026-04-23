import SwiftUI

struct ExternalSubjectSelectionView: View {
    @Binding var isPresented: Bool
    var onSelect: (String) -> Void

    @State private var subjects: [String] = []
    @State private var selectedSubject: String?
    @State private var showAddSheet = false
    @State private var newSubjectName = ""
    @State private var newSubjectColorHex = "blue"

    private let storageKey = "savedExternalStudySubjects"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection

                    if !subjects.isEmpty {
                        subjectsList
                    }

                    skipSubjectButton

                    addSubjectButton
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .navigationTitle("教科を選択")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { isPresented = false }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomButton
            }
            .onAppear { loadSubjects() }
            .sheet(isPresented: $showAddSheet) {
                ExternalAddSubjectSheet(
                    name: $newSubjectName,
                    colorHex: $newSubjectColorHex,
                    onAdd: { addSubject() }
                )
                .presentationDetents([.medium])
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("教科")
                .font(.title2.bold())
            Text("アプリ外で勉強した教科を選んでください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var subjectsList: some View {
        VStack(spacing: 10) {
            ForEach(subjects, id: \.self) { subject in
                let colorHex = SubjectColorStore.colorHex(for: subject) ?? "blue"
                let color = SubjectColorStore.availableColors.first { $0.hex == colorHex }?.color ?? .blue
                ExternalSubjectCardView(
                    name: subject,
                    color: color,
                    isSelected: selectedSubject == subject,
                    onSelect: { selectedSubject = subject },
                    onDelete: { deleteSubject(subject) }
                )
            }
        }
    }

    private var addSubjectButton: some View {
        Button {
            newSubjectName = ""
            newSubjectColorHex = nextAvailableColor()
            showAddSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.cyan.opacity(0.7))
                    .frame(width: 48, height: 48)
                    .background(Color(.tertiarySystemBackground), in: .rect(cornerRadius: 12))

                Text("教科を追加する")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.cyan.opacity(0.15), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var skipSubjectButton: some View {
        Button {
            selectedSubject = "なし"
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(selectedSubject == "なし" ? .white : .secondary)
                    .frame(width: 48, height: 48)
                    .background(selectedSubject == "なし" ? Color.cyan.opacity(0.6) : Color(.tertiarySystemBackground), in: .rect(cornerRadius: 12))

                Text("教科を選択しない")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if selectedSubject == "なし" {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.cyan)
                }
            }
            .padding(16)
            .background(selectedSubject == "なし" ? Color.cyan.opacity(0.06) : Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selectedSubject == "なし" ? Color.cyan.opacity(0.2) : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var bottomButton: some View {
        Button {
            guard let subject = selectedSubject else { return }
            onSelect(subject)
        } label: {
            Text("この教科を選択する")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(.cyan)
        .controlSize(.large)
        .disabled(selectedSubject == nil)
        .padding()
        .background(.bar)
    }

    private func loadSubjects() {
        subjects = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
    }

    private func addSubject() {
        let trimmed = newSubjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !subjects.contains(trimmed) else {
            newSubjectName = ""
            return
        }
        subjects.append(trimmed)
        UserDefaults.standard.set(subjects, forKey: storageKey)
        SubjectColorStore.save(subject: trimmed, colorHex: newSubjectColorHex)
        selectedSubject = trimmed
        newSubjectName = ""
        showAddSheet = false
    }

    private func deleteSubject(_ subject: String) {
        subjects.removeAll { $0 == subject }
        UserDefaults.standard.set(subjects, forKey: storageKey)
        SubjectColorStore.remove(subject: subject)
        if selectedSubject == subject {
            selectedSubject = nil
        }
    }

    private func nextAvailableColor() -> String {
        let usedColors = Set(SubjectColorStore.loadAll().values)
        let available = SubjectColorStore.availableColors.first { !usedColors.contains($0.hex) }
        return available?.hex ?? SubjectColorStore.availableColors[subjects.count % SubjectColorStore.availableColors.count].hex
    }
}

struct ExternalSubjectCardView: View {
    let name: String
    let color: Color
    let isSelected: Bool
    var onSelect: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 16) {
                Circle()
                    .fill(color.opacity(0.45).gradient)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "book.closed.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color.opacity(0.6))
                }
            }
            .padding(16)
            .background(isSelected ? color.opacity(0.06) : Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? color.opacity(0.2) : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }
}

struct ExternalAddSubjectSheet: View {
    @Binding var name: String
    @Binding var colorHex: String
    var onAdd: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                previewCircle

                TextField("教科名", text: $name)
                    .font(.headline)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))

                colorGrid

                Spacer()
            }
            .padding()
            .navigationTitle("教科を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") { onAdd() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var previewCircle: some View {
        let color = SubjectColorStore.availableColors.first { $0.hex == colorHex }?.color ?? .blue
        return Circle()
            .fill(color.opacity(0.45).gradient)
            .frame(width: 80, height: 80)
            .overlay {
                Image(systemName: "book.closed.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.9))
            }
    }

    private var colorGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("カラー")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(SubjectColorStore.availableColors, id: \.hex) { item in
                    Button {
                        colorHex = item.hex
                    } label: {
                        Circle()
                            .fill(item.color.opacity(0.45).gradient)
                            .frame(width: 44, height: 44)
                            .overlay {
                                if colorHex == item.hex {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .overlay {
                                Circle()
                                    .strokeBorder(colorHex == item.hex ? item.color.opacity(0.5) : .clear, lineWidth: 3)
                                    .frame(width: 52, height: 52)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ExternalEditSubjectColorSheet: View {
    let subjectName: String
    @Binding var colorHex: String
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                previewCircle

                Text(subjectName)
                    .font(.title3.bold())

                colorGrid

                Spacer()
            }
            .padding()
            .navigationTitle("色を変更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave() }
                }
            }
        }
    }

    private var previewCircle: some View {
        let color = SubjectColorStore.availableColors.first { $0.hex == colorHex }?.color ?? .blue
        return Circle()
            .fill(color.opacity(0.45).gradient)
            .frame(width: 80, height: 80)
            .overlay {
                Image(systemName: "book.closed.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.9))
            }
    }

    private var colorGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("カラー")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(SubjectColorStore.availableColors, id: \.hex) { item in
                    Button {
                        colorHex = item.hex
                    } label: {
                        Circle()
                            .fill(item.color.opacity(0.45).gradient)
                            .frame(width: 44, height: 44)
                            .overlay {
                                if colorHex == item.hex {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .overlay {
                                Circle()
                                    .strokeBorder(colorHex == item.hex ? item.color.opacity(0.5) : .clear, lineWidth: 3)
                                    .frame(width: 52, height: 52)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
