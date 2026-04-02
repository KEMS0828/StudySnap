import SwiftUI

struct GoalsView: View {
    let dataStore: DataStore
    @State private var selectedTab: GoalTab = .daily
    @State private var showingAddGoal: Bool = false

    private enum GoalTab: String, CaseIterable {
        case daily = "今日の目標"
        case weekly = "今週の目標"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    tabPicker

                    progressCard

                    goalsListSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("目標")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showingAddGoal) {
                AddGoalSheet(dataStore: dataStore, goalType: selectedTab == .daily ? .daily : .weekly)
                    .presentationDetents([.medium])
            }
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(GoalTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedTab == tab
                                ? Color(.label).clipShape(.capsule)
                                : Color.clear.clipShape(.capsule)
                        )
                        .foregroundStyle(selectedTab == tab ? Color(.systemBackground) : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(.secondarySystemGroupedBackground), in: .capsule)
    }

    private var progressCard: some View {
        let goals = selectedTab == .daily ? dataStore.todayGoals : dataStore.currentWeekGoals
        let totalCount = goals.count
        let completedCount = goals.filter { $0.isCompleted }.count
        let progress = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
        let color: Color = selectedTab == .daily ? .orange : .blue

        return VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color.gradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.6), value: progress)

                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("\(completedCount)/\(totalCount)")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)

            Text(selectedTab == .daily ? "今日の目標達成" : "今週の目標達成")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    private var goalsListSection: some View {
        let goals = selectedTab == .daily ? dataStore.todayGoals : dataStore.currentWeekGoals
        let color: Color = selectedTab == .daily ? .orange : .blue

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(
                    selectedTab == .daily ? "目標リスト" : "目標リスト",
                    systemImage: selectedTab == .daily ? "sun.max.fill" : "calendar"
                )
                .font(.headline)
                .foregroundStyle(color)

                Spacer()

                Button {
                    showingAddGoal = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                }
            }

            if goals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text(selectedTab == .daily ? "今日の目標を追加しましょう" : "今週の目標を追加しましょう")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(goals, id: \.id) { goal in
                    GoalRow(goal: goal, color: color, dataStore: dataStore)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    private var todayTargetSeconds: TimeInterval {
        let daily = dataStore.todayGoals
        let totalMinutes = daily.reduce(0) { $0 + $1.targetMinutes }
        return totalMinutes > 0 ? TimeInterval(totalMinutes * 60) : 3600
    }

    private var weeklyTargetSeconds: TimeInterval {
        let weekly = dataStore.currentWeekGoals
        let totalMinutes = weekly.reduce(0) { $0 + $1.targetMinutes }
        return totalMinutes > 0 ? TimeInterval(totalMinutes * 60) : 3600 * 7
    }

    private func formatMinutes(_ time: TimeInterval) -> String {
        let total = Int(time)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        }
        return "\(minutes)分"
    }
}

struct GoalRow: View {
    let goal: StudyGoal
    let color: Color
    let dataStore: DataStore

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    dataStore.toggleGoalCompleted(goal)
                }
            } label: {
                Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(goal.isCompleted ? .green : color.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(goal.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(goal.isCompleted, color: .secondary)
                    .foregroundStyle(goal.isCompleted ? .secondary : .primary)
                if goal.targetMinutes > 0 {
                    Text(formatGoalTime(goal.targetMinutes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(role: .destructive) {
                withAnimation {
                    dataStore.deleteGoal(goal)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.6))
            }
        }
        .padding(12)
        .background(
            goal.isCompleted ? Color.green.opacity(0.06) : color.opacity(0.04),
            in: .rect(cornerRadius: 12)
        )
        .contentShape(.rect)
        .buttonStyle(.plain)
    }

    private func formatGoalTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 {
            return "\(h)時間\(m)分"
        } else if h > 0 {
            return "\(h)時間"
        }
        return "\(m)分"
    }
}

struct AddGoalSheet: View {
    let dataStore: DataStore
    let goalType: GoalType
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var hasTargetTime: Bool = false
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 0

    private var totalMinutes: Int {
        hasTargetTime ? selectedHours * 60 + selectedMinutes : 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("目標の内容") {
                    TextField("例：数学の問題集を解く", text: $title)
                }

                Section("目標時間") {
                    Toggle("目標時間を設定する", isOn: $hasTargetTime)

                    if hasTargetTime {
                        HStack(spacing: 0) {
                            Picker("時間", selection: $selectedHours) {
                                ForEach(0...99, id: \.self) { h in
                                    Text("\(h)時間").tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            .clipped()

                            Picker("分", selection: $selectedMinutes) {
                                ForEach(0...59, id: \.self) { m in
                                    Text("\(m)分").tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            .clipped()
                        }
                        .frame(height: 150)
                    }
                }
                .listRowSeparator(hasTargetTime ? .visible : .hidden)
            }
            .navigationTitle(goalType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        dataStore.addGoal(title: title, targetMinutes: totalMinutes, type: goalType)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || (hasTargetTime && totalMinutes == 0))
                }
            }
        }
    }
}
