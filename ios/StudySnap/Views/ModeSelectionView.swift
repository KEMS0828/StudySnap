import SwiftUI

struct ModeSelectionView: View {
    @State private var localSelectedMode: StudyMode?
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
        ForEach(StudyMode.allCases) { mode in
            ModeCardView(
                mode: mode,
                isSelected: localSelectedMode == mode,
                onSelect: { localSelectedMode = mode }
            )
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
