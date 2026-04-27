import SwiftUI

struct PostEditView: View {
    let post: StudyPost
    let dataStore: DataStore
    @Binding var isPresented: Bool

    @State private var subject: String
    @State private var reflection: String
    @State private var editedPhotos: [EditablePhoto] = []
    @State private var selectedPhotoIndex: Int = 0
    @State private var selectedTool: EditTool = .pen
    @State private var brushSize: CGFloat = 30
    @State private var mosaicIntensity: CGFloat = 10
    @State private var penColor: Color = .black
    @State private var selectedStamp: StampType = .star
    @State private var stampSize: CGFloat = 36
    @State private var showStampPicker: Bool = false
    @State private var showPostConfirmation: Bool = false
    @State private var showNGWordAlert: Bool = false
    @State private var isLoadingPhotos: Bool = true
    @FocusState private var isTextFieldFocused: Bool

    private let penColors: [Color] = [.black, .red, .orange, .yellow, .green, .blue, .purple, .white]

    init(post: StudyPost, dataStore: DataStore, isPresented: Binding<Bool>) {
        self.post = post
        self.dataStore = dataStore
        self._isPresented = isPresented
        self._subject = State(initialValue: post.subject)
        self._reflection = State(initialValue: post.reflection)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoadingPhotos {
                        ProgressView("写真を読み込み中...")
                            .padding(.vertical, 40)
                    } else if !editedPhotos.isEmpty {
                        photoEditorSection
                    }

                    formSection

                    durationSection
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .contentShape(.rect)
            .onTapGesture {
                isTextFieldFocused = false
            }
            .navigationTitle("投稿を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    if NGWordFilter.containsNGWord(in: subject, reflection) {
                        showNGWordAlert = true
                    } else {
                        showPostConfirmation = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("保存する")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(subject.isEmpty || isLoadingPhotos)
                .padding()
                .background(.bar)
            }
            .sheet(isPresented: $showPostConfirmation) {
                PostConfirmationView(
                    photos: editedPhotos.map { $0.renderedData ?? $0.originalData },
                    onConfirm: {
                        saveChanges()
                    }
                )
            }
            .task {
                await loadPhotosFromUrls()
            }
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("完了") {
                            isTextFieldFocused = false
                        }
                        .fontWeight(.semibold)
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

    private func loadPhotosFromUrls() async {
        var photos: [EditablePhoto] = []
        for urlString in post.photoUrls {
            guard let url = URL(string: urlString) else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let normalized = CameraService.normalizeImageOrientation(data)
                photos.append(EditablePhoto(originalData: normalized))
            } catch {}
        }
        editedPhotos = photos
        isLoadingPhotos = false
    }

    @ViewBuilder
    private var photoEditorSection: some View {
        VStack(spacing: 12) {
            if editedPhotos.count > 1 {
                HStack {
                    Text("写真")
                        .font(.headline)
                    Spacer()
                    Text("\(selectedPhotoIndex + 1)/\(editedPhotos.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(editedPhotos.enumerated()), id: \.element.id) { index, photo in
                            Button {
                                selectedPhotoIndex = index
                            } label: {
                                if let uiImage = UIImage(data: photo.originalData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 56, height: 56)
                                        .clipShape(.rect(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(index == selectedPhotoIndex ? Color.accentColor : .clear, lineWidth: 3)
                                        )
                                }
                            }
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
            } else {
                HStack {
                    Text("写真")
                        .font(.headline)
                    Spacer()
                }
            }

            if selectedPhotoIndex < editedPhotos.count {
                let canvasAspect = photoAspectRatio(for: editedPhotos[selectedPhotoIndex])
                let maxCanvasHeight: CGFloat = 380
                GeometryReader { proxy in
                    let availableW = proxy.size.width
                    let heightFromWidth = availableW / canvasAspect
                    let finalH = min(maxCanvasHeight, heightFromWidth)
                    let finalW = finalH * canvasAspect
                    HStack {
                        Spacer(minLength: 0)
                        PhotoCanvas(
                            photo: editedPhotos[selectedPhotoIndex],
                            selectedTool: selectedTool,
                            brushSize: brushSize,
                            mosaicIntensity: mosaicIntensity,
                            penColor: penColor,
                            selectedStamp: selectedStamp,
                            stampSize: stampSize,
                            onUpdate: { updatedPhoto in
                                editedPhotos[selectedPhotoIndex] = updatedPhoto
                            }
                        )
                        .frame(width: finalW, height: finalH)
                        .clipShape(.rect(cornerRadius: 16))
                        .id(editedPhotos[selectedPhotoIndex].id)
                        Spacer(minLength: 0)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .frame(height: {
                    let screenW = UIScreen.main.bounds.width - 32
                    return min(maxCanvasHeight, screenW / canvasAspect)
                }())
            }

            toolBar

            toolOptions
        }
    }

    @ViewBuilder
    private var toolBar: some View {
        HStack(spacing: 0) {
            ForEach(EditTool.allCases, id: \.rawValue) { tool in
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        selectedTool = tool
                        if tool == .stamp {
                            showStampPicker = true
                        } else {
                            showStampPicker = false
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 36)
                        Text(tool.label)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(selectedTool == tool ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedTool == tool
                            ? Color.accentColor.clipShape(.rect(cornerRadius: 12))
                            : Color.clear.clipShape(.rect(cornerRadius: 12))
                    )
                }
            }
        }
        .padding(4)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    @ViewBuilder
    private var toolOptions: some View {
        VStack(spacing: 10) {
            switch selectedTool {
            case .pen:
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.secondary)
                        Slider(value: $brushSize, in: 2...20)
                        Image(systemName: "circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        ForEach(penColors, id: \.description) { color in
                            Button {
                                penColor = color
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                    )
                                    .overlay {
                                        if penColor.description == color.description {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(color == .white || color == .yellow ? .black : .white)
                                        }
                                    }
                            }
                        }
                    }
                }

            case .eraser:
                HStack {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Slider(value: $brushSize, in: 15...60)
                    Image(systemName: "circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }

            case .mosaic:
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Slider(value: $brushSize, in: 20...40)
                        Image(systemName: "circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Image(systemName: "squareshape.split.3x3")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Slider(value: $mosaicIntensity, in: 5...15)
                        Image(systemName: "squareshape.split.2x2")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                }

            case .stamp:
                VStack(spacing: 10) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(StampType.allCases, id: \.rawValue) { stamp in
                                Button {
                                    selectedStamp = stamp
                                } label: {
                                    Text(stamp.emoji)
                                        .font(.system(size: 32))
                                        .padding(6)
                                        .background(
                                            selectedStamp == stamp
                                                ? Color.accentColor.opacity(0.2)
                                                : Color.clear,
                                            in: .rect(cornerRadius: 10)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedStamp == stamp ? Color.accentColor : .clear, lineWidth: 2)
                                        )
                                }
                            }
                        }
                    }
                    .contentMargins(.horizontal, 0)

                    HStack {
                        Text(selectedStamp.emoji)
                            .font(.system(size: 14))
                        Slider(value: $stampSize, in: 20...140)
                        Text(selectedStamp.emoji)
                            .font(.system(size: 28))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var formSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("勉強内容", systemImage: "text.book.closed.fill")
                    .font(.headline)
                TextField("例: 数学の微分積分", text: $subject)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("振り返り", systemImage: "text.bubble.fill")
                    .font(.headline)
                TextEditor(text: $reflection)
                    .focused($isTextFieldFocused)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 8))
                    .overlay(alignment: .topLeading) {
                        if reflection.isEmpty {
                            Text("今日の勉強はどうでしたか？")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var durationSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .foregroundStyle(.tint)
            Text("勉強時間: \(post.formattedDuration)")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private func photoAspectRatio(for photo: EditablePhoto) -> CGFloat {
        guard let uiImage = UIImage(data: photo.originalData) else { return 4.0 / 3.0 }
        let rawW: CGFloat
        let rawH: CGFloat
        if let cg = uiImage.cgImage {
            rawW = CGFloat(cg.width)
            rawH = CGFloat(cg.height)
        } else {
            rawW = uiImage.size.width
            rawH = uiImage.size.height
        }
        let isRotated: Bool = {
            switch uiImage.imageOrientation {
            case .left, .leftMirrored, .right, .rightMirrored: return true
            default: return false
            }
        }()
        let w = isRotated ? rawH : rawW
        let h = isRotated ? rawW : rawH
        guard h > 0 else { return 4.0 / 3.0 }
        return w / h
    }

    private func saveChanges() {
        let photoDataArray = editedPhotos.map { $0.renderedData ?? $0.originalData }
        dataStore.updatePost(post, subject: subject, reflection: reflection, photoData: photoDataArray)
        isPresented = false
    }
}
