import SwiftUI

struct ModeSelectionView: View {
    @State private var localSelectedMode: StudyMode?
    @AppStorage("outdoorModeEnabled") private var outdoorModeEnabled: Bool = false
    @Binding var isPresented: Bool
    var onStart: (StudyMode) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    modesSection
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .navigationTitle("モード設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { isPresented = false }
                }
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                bottomButton
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("撮影モード")
                .font(.title2.bold())
            Text("ランダム撮影の間隔を選んでください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("※勉強時間はモードごとの平均撮影間隔 × 撮影枚数で算出されます")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var modesSection: some View {
        VStack(spacing: 12) {
            ForEach(StudyMode.allCases) { mode in
                VStack(spacing: 8) {
                    ModeCardView(
                        mode: mode,
                        isSelected: localSelectedMode == mode,
                        onSelect: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                localSelectedMode = (localSelectedMode == mode) ? nil : mode
                            }
                        }
                    )

                    if localSelectedMode == mode {
                        OutdoorToggleCard(isOn: $outdoorModeEnabled)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.96, anchor: .top)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            ))
                    }
                }
            }
        }
    }

    private var bottomButton: some View {
        Button {
            guard let mode = localSelectedMode else { return }
            onStart(mode)
        } label: {
            Text("プレビューへ")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(localSelectedMode == nil)
        .padding()
        .background(.bar)
    }
}

struct OutdoorToggleCard: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.walk.circle.fill")
                .font(.title3)
                .foregroundStyle(isOn ? .white : Color.accentColor)
                .frame(width: 36, height: 36)
                .background(isOn ? Color.accentColor : Color(.tertiarySystemBackground), in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("外出時モード")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("カフェや図書館など、周囲に配慮したい場所でおすすめ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .scaleEffect(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 12)
    }
}

struct ModeCardView: View {
    let mode: StudyMode
    let isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 16) {
                iconView
                textView
                Spacer()
                checkmarkView
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(cardBorder)
        }
        .buttonStyle(.plain)
    }

    private var iconView: some View {
        Image(systemName: mode.icon)
            .font(.title2)
            .foregroundStyle(isSelected ? .white : Color.accentColor)
            .frame(width: 48, height: 48)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemBackground), in: .rect(cornerRadius: 12))
    }

    private var textView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(mode.title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(mode.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var checkmarkView: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : .clear, lineWidth: 1.5)
    }
}
