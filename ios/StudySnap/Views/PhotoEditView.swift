import SwiftUI

nonisolated enum EditTool: String, CaseIterable {
    case pen
    case eraser
    case mosaic
    case stamp

    var icon: String {
        switch self {
        case .pen: return "pencil.tip"
        case .eraser: return "eraser.fill"
        case .mosaic: return "squareshape.split.3x3"
        case .stamp: return "face.smiling.fill"
        }
    }

    var label: String {
        switch self {
        case .pen: return "ペン"
        case .eraser: return "消しゴム"
        case .mosaic: return "モザイク"
        case .stamp: return "スタンプ"
        }
    }
}

nonisolated enum StampType: String, CaseIterable {
    case star
    case heart
    case grinning
    case smiley
    case cool
    case checkmark

    var emoji: String {
        switch self {
        case .star: return "⭐️"
        case .heart: return "❤️"
        case .grinning: return "😆"
        case .smiley: return "☺️"
        case .cool: return "😎"
        case .checkmark: return "✅"
        }
    }
}

nonisolated struct CodablePoint: Codable, Sendable {
    let x: CGFloat
    let y: CGFloat

    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

nonisolated struct DrawingStroke: Sendable {
    let points: [CGPoint]
    let color: Color
    let lineWidth: CGFloat
    let tool: EditTool
}

nonisolated struct MosaicStroke: Sendable {
    let points: [CGPoint]
    let brushSize: CGFloat
    var intensity: CGFloat = 10
}

nonisolated struct CodableMosaicStroke: Codable, Sendable {
    let points: [CodablePoint]
    let brushSize: CGFloat
    let intensity: CGFloat?

    init(from stroke: MosaicStroke) {
        self.points = stroke.points.map { CodablePoint($0) }
        self.brushSize = stroke.brushSize
        self.intensity = stroke.intensity
    }

    func toMosaicStroke() -> MosaicStroke {
        MosaicStroke(points: points.map { $0.cgPoint }, brushSize: brushSize, intensity: intensity ?? 10)
    }
}

nonisolated struct CodableStroke: Codable, Sendable {
    let points: [CodablePoint]
    let colorHex: String
    let lineWidth: CGFloat
    let toolRawValue: String

    init(from stroke: DrawingStroke) {
        self.points = stroke.points.map { CodablePoint($0) }
        self.colorHex = UIColor(stroke.color).toHex()
        self.lineWidth = stroke.lineWidth
        self.toolRawValue = stroke.tool.rawValue
    }

    func toStroke() -> DrawingStroke {
        DrawingStroke(
            points: points.map { $0.cgPoint },
            color: Color(hex: colorHex),
            lineWidth: lineWidth,
            tool: EditTool(rawValue: toolRawValue) ?? .pen
        )
    }
}

nonisolated struct StampItem: Sendable {
    var position: CGPoint
    let type: StampType
    var size: CGFloat
}

nonisolated struct CodableStamp: Codable, Sendable {
    let position: CodablePoint
    let typeRawValue: String
    let size: CGFloat

    init(from stamp: StampItem) {
        self.position = CodablePoint(stamp.position)
        self.typeRawValue = stamp.type.rawValue
        self.size = stamp.size
    }

    func toStamp() -> StampItem {
        StampItem(
            position: position.cgPoint,
            type: StampType(rawValue: typeRawValue) ?? .star,
            size: size
        )
    }
}

nonisolated struct CodableEditablePhoto: Codable, Sendable {
    let originalData: Data
    let strokes: [CodableStroke]
    let stamps: [CodableStamp]
    let mosaicStrokes: [CodableMosaicStroke]?

    init(from photo: EditablePhoto) {
        self.originalData = photo.originalData
        self.strokes = photo.strokes.map { CodableStroke(from: $0) }
        self.stamps = photo.stamps.map { CodableStamp(from: $0) }
        self.mosaicStrokes = photo.mosaicStrokes.map { CodableMosaicStroke(from: $0) }
    }

    func toEditablePhoto() -> EditablePhoto {
        var photo = EditablePhoto(originalData: originalData)
        photo.strokes = strokes.map { $0.toStroke() }
        photo.stamps = stamps.map { $0.toStamp() }
        photo.mosaicStrokes = (mosaicStrokes ?? []).map { $0.toMosaicStroke() }
        return photo
    }
}

struct EditablePhoto: Identifiable {
    let id = UUID()
    let originalData: Data
    var strokes: [DrawingStroke] = []
    var stamps: [StampItem] = []
    var mosaicStrokes: [MosaicStroke] = []
    var renderedData: Data?
}

struct PhotoEditView: View {
    let capturedPhotos: [Data]
    let duration: TimeInterval
    let dataStore: DataStore
    let studyMode: StudyMode
    var onPost: (String, String, [Data]) -> Void
    @Binding var isPresented: Bool
    var initialSubject: String = ""
    var initialReflection: String = ""
    var initialEditedPhotos: [Data] = []
    var initialEditablePhotos: [CodableEditablePhoto]? = nil

    @State private var subject: String = ""
    @State private var reflection: String = ""
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
    @State private var showDraftSavedToast: Bool = false
    @State private var showNGWordAlert: Bool = false
    @State private var photoIndexToDelete: Int? = nil

    private let penColors: [Color] = [.black, .red, .orange, .yellow, .green, .blue, .purple, .white]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !editedPhotos.isEmpty {
                        photoEditorSection
                    } else {
                        emptyPhotoSection
                    }

                    formSection

                    durationSection
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .navigationTitle("投稿を作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        saveDraft()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                            Text("下書き保存")
                        }
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
                        Image(systemName: "paperplane.fill")
                        Text("投稿する")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(subject.isEmpty)
                .padding()
                .background(.bar)
            }
            .alert("不適切な表現が含まれています", isPresented: $showNGWordAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("内容を修正してください。")
            }
            .alert("下書きを保存しました", isPresented: $showDraftExpiryAlert) {
                Button("OK") { isPresented = false }
            } message: {
                Text("下書きは保存から24時間で自動削除されます。早めに投稿してください。")
            }
            .sheet(isPresented: $showPostConfirmation) {
                PostConfirmationView(
                    photos: editedPhotos.map { $0.renderedData ?? $0.originalData },
                    onConfirm: {
                        let photoDataArray = editedPhotos.map { $0.renderedData ?? $0.originalData }
                        onPost(subject, reflection, photoDataArray)
                    }
                )
            }
            .onAppear {
                if let codablePhotos = initialEditablePhotos, !codablePhotos.isEmpty {
                    editedPhotos = codablePhotos.map { $0.toEditablePhoto() }
                } else if !initialEditedPhotos.isEmpty {
                    editedPhotos = initialEditedPhotos.map { EditablePhoto(originalData: $0) }
                } else {
                    editedPhotos = capturedPhotos.map { EditablePhoto(originalData: $0) }
                }
                if !initialSubject.isEmpty { subject = initialSubject }
                if !initialReflection.isEmpty { reflection = initialReflection }
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .alert("この写真を削除しますか？", isPresented: Binding(
                get: { photoIndexToDelete != nil },
                set: { if !$0 { photoIndexToDelete = nil } }
            )) {
                Button("削除する", role: .destructive) {
                    if let index = photoIndexToDelete {
                        deletePhoto(at: index)
                    }
                    photoIndexToDelete = nil
                }
                Button("キャンセル", role: .cancel) {
                    photoIndexToDelete = nil
                }
            } message: {
                Text("削除した写真は元に戻せません")
            }
        }
    }

    @ViewBuilder
    private var photoEditorSection: some View {
        VStack(spacing: 12) {
            if editedPhotos.count > 1 {
                HStack {
                    Text("撮影された写真")
                        .font(.headline)
                    Spacer()
                    Text("\(selectedPhotoIndex + 1)/\(editedPhotos.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(Array(editedPhotos.enumerated()), id: \.element.id) { index, photo in
                            Button {
                                selectedPhotoIndex = index
                            } label: {
                                if let uiImage = UIImage(data: photo.originalData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(.rect(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(index == selectedPhotoIndex ? Color.accentColor : .clear, lineWidth: 2.5)
                                        )
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if editedPhotos.count > 1 {
                                    Button {
                                        photoIndexToDelete = index
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .red)
                                    }
                                    .offset(x: 5, y: -5)
                                }
                            }
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
            } else {
                HStack {
                    Text("撮影された写真")
                        .font(.headline)
                    Spacer()
                }
            }

            if selectedPhotoIndex < editedPhotos.count {
                let canvasAspect = photoAspectRatio(for: editedPhotos[selectedPhotoIndex])
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
                .aspectRatio(canvasAspect, contentMode: .fit)
                .frame(maxHeight: canvasAspect < 1 ? 340 : 440)
                .clipShape(.rect(cornerRadius: 16))
                .id(editedPhotos[selectedPhotoIndex].id)
            }

            toolBar

            toolOptions

            Label("加工前の写真はクラウドにアップロードされません", systemImage: "lock.shield")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
    private var emptyPhotoSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.badge.clock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("写真がありません")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("勉強時間が短すぎたか、\nシミュレータ環境のため撮影されませんでした")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    @ViewBuilder
    private var formSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("勉強内容", systemImage: "text.book.closed.fill")
                    .font(.headline)
                TextField("例: 数学の微分積分", text: $subject)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("振り返り", systemImage: "text.bubble.fill")
                    .font(.headline)
                TextEditor(text: $reflection)
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
            Text("勉強時間: \(formattedDuration)")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private func photoAspectRatio(for photo: EditablePhoto) -> CGFloat {
        guard let uiImage = UIImage(data: photo.originalData) else { return 4.0 / 3.0 }
        let w = uiImage.size.width
        let h = uiImage.size.height
        guard h > 0 else { return 4.0 / 3.0 }
        return w / h
    }

    private var formattedDuration: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分\(seconds)秒"
        }
        return "\(minutes)分\(seconds)秒"
    }

    private func deletePhoto(at index: Int) {
        withAnimation(.spring(duration: 0.3)) {
            editedPhotos.remove(at: index)
            if selectedPhotoIndex >= editedPhotos.count {
                selectedPhotoIndex = max(editedPhotos.count - 1, 0)
            }
        }
    }

    @State private var showDraftExpiryAlert: Bool = false

    private func saveDraft() {
        let codablePhotos = editedPhotos.map { CodableEditablePhoto(from: $0) }
        let draft = DraftData(
            subject: subject,
            reflection: reflection,
            duration: duration,
            capturedPhotos: capturedPhotos,
            editedPhotos: [],
            modeRawValue: studyMode.rawValue,
            savedAt: .now,
            editablePhotos: codablePhotos
        )
        dataStore.saveDraft(draft)
        showDraftExpiryAlert = true
    }
}

struct PhotoCanvas: View {
    var photo: EditablePhoto
    let selectedTool: EditTool
    let brushSize: CGFloat
    let mosaicIntensity: CGFloat
    let penColor: Color
    let selectedStamp: StampType
    let stampSize: CGFloat
    var onUpdate: (EditablePhoto) -> Void

    @State private var currentPath: [CGPoint] = []
    @State private var pixelatedCache: [Int: UIImage] = [:]
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let uiImage = UIImage(data: photo.originalData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .allowsHitTesting(false)
                }

                Canvas { context, size in
                    drawMosaicStrokes(photo.mosaicStrokes, in: &context, size: size)
                    if !currentPath.isEmpty && selectedTool == .mosaic {
                        let currentMosaic = MosaicStroke(points: currentPath, brushSize: brushSize, intensity: mosaicIntensity)
                        drawMosaicStrokes([currentMosaic], in: &context, size: size)
                    }

                    for stroke in photo.strokes {
                        drawStroke(stroke, in: &context, size: size)
                    }
                    if !currentPath.isEmpty && selectedTool == .pen {
                        let currentStroke = DrawingStroke(
                            points: currentPath,
                            color: currentStrokeColor,
                            lineWidth: currentLineWidth,
                            tool: selectedTool
                        )
                        drawStroke(currentStroke, in: &context, size: size)
                    }

                    for stamp in photo.stamps {
                        drawStamp(stamp, in: &context, size: size)
                    }
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if selectedTool == .stamp { return }
                        if selectedTool == .eraser {
                            eraseAt(point: value.location, in: geometry.size)
                        } else {
                            currentPath.append(value.location)
                        }
                    }
                    .onEnded { value in
                        if selectedTool == .stamp {
                            var updated = photo
                            updated.stamps.append(StampItem(position: value.location, type: selectedStamp, size: stampSize))
                            updated.renderedData = renderPhoto(photo: updated, size: geometry.size)
                            onUpdate(updated)
                            return
                        }
                        if selectedTool == .eraser { return }
                        guard !currentPath.isEmpty else { return }
                        var updated = photo
                        if selectedTool == .mosaic {
                            updated.mosaicStrokes.append(MosaicStroke(points: currentPath, brushSize: brushSize, intensity: mosaicIntensity))
                        } else {
                            updated.strokes.append(DrawingStroke(
                                points: currentPath,
                                color: currentStrokeColor,
                                lineWidth: currentLineWidth,
                                tool: selectedTool
                            ))
                        }
                        updated.renderedData = renderPhoto(photo: updated, size: geometry.size)
                        currentPath = []
                        onUpdate(updated)
                    }
            )
            .onAppear {
                canvasSize = geometry.size
                preparePixelatedImage(intensity: mosaicIntensity, size: geometry.size)
                for stroke in photo.mosaicStrokes {
                    preparePixelatedImage(intensity: stroke.intensity, size: geometry.size)
                }
            }
            .onChange(of: geometry.size) { _, newSize in
                canvasSize = newSize
                pixelatedCache.removeAll()
                preparePixelatedImage(intensity: mosaicIntensity, size: newSize)
                for stroke in photo.mosaicStrokes {
                    preparePixelatedImage(intensity: stroke.intensity, size: newSize)
                }
            }
            .onChange(of: mosaicIntensity) { _, newValue in
                preparePixelatedImage(intensity: newValue, size: canvasSize)
            }
        }
    }

    private func intensityKey(_ intensity: CGFloat) -> Int {
        Int(intensity.rounded())
    }

    private func preparePixelatedImage(intensity: CGFloat, size: CGSize) {
        let key = intensityKey(intensity)
        if pixelatedCache[key] != nil { return }
        guard size.width > 0 else { return }
        guard let uiImage = UIImage(data: photo.originalData),
              let ciImage = CIImage(image: uiImage) else { return }
        let scale = uiImage.size.width / max(size.width, 1)
        let pixelSize = max(CGFloat(key) * scale, CGFloat(key) * 0.8)
        guard let filter = CIFilter(name: "CIPixellate") else { return }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(pixelSize, forKey: kCIInputScaleKey)
        filter.setValue(CIVector(x: 0, y: 0), forKey: kCIInputCenterKey)
        guard let output = filter.outputImage else { return }
        let ctx = CIContext()
        guard let cgImage = ctx.createCGImage(output, from: ciImage.extent) else { return }
        pixelatedCache[key] = UIImage(cgImage: cgImage)
    }

    private var currentStrokeColor: Color {
        switch selectedTool {
        case .pen: return penColor
        case .eraser, .stamp, .mosaic: return .clear
        }
    }

    private var currentLineWidth: CGFloat {
        switch selectedTool {
        case .pen: return brushSize
        case .eraser: return brushSize
        case .mosaic: return brushSize
        case .stamp: return 0
        }
    }

    private func eraseAt(point: CGPoint, in size: CGSize) {
        let eraseRadius = brushSize / 2
        var updated = photo
        updated.strokes = updated.strokes.compactMap { stroke in
            let remaining = stroke.points.filter { p in
                let dx = p.x - point.x
                let dy = p.y - point.y
                return sqrt(dx * dx + dy * dy) > eraseRadius + stroke.lineWidth / 2
            }
            if remaining.isEmpty { return nil }
            return DrawingStroke(points: remaining, color: stroke.color, lineWidth: stroke.lineWidth, tool: stroke.tool)
        }
        updated.stamps = updated.stamps.filter { stamp in
            let dx = stamp.position.x - point.x
            let dy = stamp.position.y - point.y
            return sqrt(dx * dx + dy * dy) > eraseRadius + stamp.size / 2
        }
        updated.mosaicStrokes = updated.mosaicStrokes.compactMap { stroke in
            let remaining = stroke.points.filter { p in
                let dx = p.x - point.x
                let dy = p.y - point.y
                return sqrt(dx * dx + dy * dy) > eraseRadius + stroke.brushSize / 2
            }
            if remaining.isEmpty { return nil }
            return MosaicStroke(points: remaining, brushSize: stroke.brushSize)
        }
        updated.renderedData = renderPhoto(photo: updated, size: size)
        onUpdate(updated)
    }

    private func drawMosaicStrokes(_ strokes: [MosaicStroke], in context: inout GraphicsContext, size: CGSize) {
        guard !strokes.isEmpty else { return }
        for stroke in strokes {
            guard stroke.points.count > 0 else { continue }
            let key = intensityKey(stroke.intensity)
            guard let pixImage = pixelatedCache[key] else { continue }
            var linePath = Path()
            linePath.move(to: stroke.points[0])
            for i in 1..<stroke.points.count {
                linePath.addLine(to: stroke.points[i])
            }
            let strokedPath = linePath.strokedPath(StrokeStyle(lineWidth: stroke.brushSize, lineCap: .round, lineJoin: .round))
            context.drawLayer { layerCtx in
                layerCtx.clip(to: strokedPath)
                layerCtx.draw(Image(uiImage: pixImage).resizable(), in: CGRect(origin: .zero, size: size))
            }
        }
    }

    private func drawStroke(_ stroke: DrawingStroke, in context: inout GraphicsContext, size: CGSize) {
        if stroke.tool == .pen {
            guard stroke.points.count > 1 else {
                if let p = stroke.points.first {
                    let rect = CGRect(
                        x: p.x - stroke.lineWidth / 2,
                        y: p.y - stroke.lineWidth / 2,
                        width: stroke.lineWidth,
                        height: stroke.lineWidth
                    )
                    context.fill(Ellipse().path(in: rect), with: .color(stroke.color))
                }
                return
            }
            var path = Path()
            path.move(to: stroke.points[0])
            for i in 1..<stroke.points.count {
                let mid = CGPoint(
                    x: (stroke.points[i - 1].x + stroke.points[i].x) / 2,
                    y: (stroke.points[i - 1].y + stroke.points[i].y) / 2
                )
                path.addQuadCurve(to: mid, control: stroke.points[i - 1])
            }
            if let last = stroke.points.last {
                path.addLine(to: last)
            }
            context.stroke(path, with: .color(stroke.color), style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    private func drawStamp(_ stamp: StampItem, in context: inout GraphicsContext, size: CGSize) {
        let text = Text(stamp.type.emoji).font(.system(size: stamp.size))
        context.draw(text, at: stamp.position)
    }

    private func renderPhoto(photo: EditablePhoto, size: CGSize) -> Data? {
        guard let uiImage = UIImage(data: photo.originalData) else { return nil }

        var pixelatedByKey: [Int: UIImage] = [:]
        if !photo.mosaicStrokes.isEmpty, let ciImage = CIImage(image: uiImage) {
            let scale = uiImage.size.width / max(size.width, 1)
            let ctx = CIContext()
            let keys = Set(photo.mosaicStrokes.map { Int($0.intensity.rounded()) })
            for key in keys {
                let pixelSize = max(CGFloat(key) * scale, CGFloat(key) * 0.8)
                guard let filter = CIFilter(name: "CIPixellate") else { continue }
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(pixelSize, forKey: kCIInputScaleKey)
                filter.setValue(CIVector(x: 0, y: 0), forKey: kCIInputCenterKey)
                if let output = filter.outputImage,
                   let cgImg = ctx.createCGImage(output, from: ciImage.extent) {
                    pixelatedByKey[key] = UIImage(cgImage: cgImg)
                }
            }
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { ctx in
            let cgCtx = ctx.cgContext
            uiImage.draw(in: CGRect(origin: .zero, size: size))

            if !photo.mosaicStrokes.isEmpty {
                for stroke in photo.mosaicStrokes {
                    guard !stroke.points.isEmpty else { continue }
                    let key = Int(stroke.intensity.rounded())
                    guard let pixelated = pixelatedByKey[key] else { continue }
                    cgCtx.saveGState()
                    let mutablePath = CGMutablePath()
                    mutablePath.move(to: stroke.points[0])
                    for i in 1..<stroke.points.count {
                        mutablePath.addLine(to: stroke.points[i])
                    }
                    let strokedPath = mutablePath.copy(strokingWithWidth: stroke.brushSize, lineCap: .round, lineJoin: .round, miterLimit: 10)
                    cgCtx.addPath(strokedPath)
                    cgCtx.clip()
                    pixelated.draw(in: CGRect(origin: .zero, size: size))
                    cgCtx.restoreGState()
                }
            }

            for stroke in photo.strokes {
                if stroke.tool == .pen {
                    let uiColor = UIColor(stroke.color)
                    cgCtx.setStrokeColor(uiColor.cgColor)
                    cgCtx.setLineWidth(stroke.lineWidth)
                    cgCtx.setLineCap(.round)
                    cgCtx.setLineJoin(.round)
                    if stroke.points.count > 1 {
                        cgCtx.beginPath()
                        cgCtx.move(to: stroke.points[0])
                        for i in 1..<stroke.points.count {
                            let mid = CGPoint(
                                x: (stroke.points[i - 1].x + stroke.points[i].x) / 2,
                                y: (stroke.points[i - 1].y + stroke.points[i].y) / 2
                            )
                            cgCtx.addQuadCurve(to: mid, control: stroke.points[i - 1])
                        }
                        if let last = stroke.points.last {
                            cgCtx.addLine(to: last)
                        }
                        cgCtx.strokePath()
                    } else if let p = stroke.points.first {
                        cgCtx.setFillColor(uiColor.cgColor)
                        let rect = CGRect(x: p.x - stroke.lineWidth / 2, y: p.y - stroke.lineWidth / 2, width: stroke.lineWidth, height: stroke.lineWidth)
                        cgCtx.fillEllipse(in: rect)
                    }
                }
            }

            for stamp in photo.stamps {
                let emoji = stamp.type.emoji as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: stamp.size)
                ]
                let textSize = emoji.size(withAttributes: attrs)
                let drawPoint = CGPoint(
                    x: stamp.position.x - textSize.width / 2,
                    y: stamp.position.y - textSize.height / 2
                )
                emoji.draw(at: drawPoint, withAttributes: attrs)
            }
        }
        return rendered.jpegData(compressionQuality: 0.5)
    }
}
