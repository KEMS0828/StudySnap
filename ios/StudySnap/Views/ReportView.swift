import SwiftUI
import Charts

struct ReportView: View {
    let dataStore: DataStore

    @State private var selectedTab: ReportTab = .app
    @State private var selectedPeriod: ReportPeriod = .today
    @State private var showAddExternal: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    reportTabPicker
                    todayCard
                    subjectBreakdownCard
                    weeklyChart
                    recentSessionsList
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("レポート")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddExternal = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddExternal) {
                AddExternalStudyView(dataStore: dataStore, isPresented: $showAddExternal)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Tab Picker

    private var reportTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(ReportTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.label)
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

    // MARK: - Today Card

    private var todayCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todayCardTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatDuration(todayTime))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                }
                Spacer()
                if selectedTab != .external {
                    VStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                dataStore.currentStreak > 0
                                    ? LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                            )
                            .symbolEffect(.bounce, value: dataStore.currentStreak)
                        Text("\(dataStore.currentStreak)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(dataStore.currentStreak > 0 ? .primary : .secondary)
                        Text("日連続")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                }
            }

            if selectedTab == .app {
                HStack(spacing: 16) {
                    StatBadge(
                        icon: "checkmark.seal.fill",
                        label: "承認済",
                        value: "\(approvedCount)",
                        color: .green
                    )
                    StatBadge(
                        icon: "camera.fill",
                        label: "セッション",
                        value: "\(todayAppSessionCount)",
                        color: .blue
                    )
                    StatBadge(
                        icon: "percent",
                        label: "承認率",
                        value: todayApprovalRate,
                        color: .purple
                    )
                }
            } else if selectedTab == .external {
                HStack(spacing: 16) {
                    StatBadge(
                        icon: "pencil.line",
                        label: "手入力",
                        value: "\(todayExternalSessionCount)",
                        color: .cyan
                    )
                    StatBadge(
                        icon: "book.closed.fill",
                        label: "教科数",
                        value: "\(todayExternalSubjectCount)",
                        color: .teal
                    )
                }
            } else {
                HStack(spacing: 16) {
                    StatBadge(
                        icon: "iphone",
                        label: "アプリ内",
                        value: formatShortDuration(dataStore.todayStudyTime),
                        color: .blue
                    )
                    StatBadge(
                        icon: "pencil.line",
                        label: "アプリ外",
                        value: formatShortDuration(dataStore.todayExternalStudyTime),
                        color: .cyan
                    )
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    // MARK: - Subject Breakdown

    private var subjectBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("教科別")
                    .font(.headline)
                Spacer()
                Picker("期間", selection: $selectedPeriod) {
                    ForEach(ReportPeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            if selectedTab == .total {
                let splitData = subjectDataSplit
                let periodTotal = splitData.reduce(0) { $0 + $1.1 }

                if periodTotal > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text("\(selectedPeriod.label)の合計")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatDuration(periodTotal))
                            .font(.subheadline.bold())
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 4)
                }

                if splitData.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.pie")
                            .font(.title)
                            .foregroundStyle(.tertiary)
                        Text("データがありません")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    HStack(spacing: 16) {
                        subjectDonutChartSplit(data: splitData)
                            .frame(width: 120, height: 120)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(splitData.prefix(5).enumerated()), id: \.offset) { index, item in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(subjectColor(for: index, subjectName: item.0).opacity(item.2 ? 0.45 : 1.0))
                                        .frame(width: 10, height: 10)
                                    Text(item.0)
                                        .font(.caption)
                                        .lineLimit(1)
                                    if item.2 {
                                        Text("外")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(.cyan)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(.cyan.opacity(0.12), in: .capsule)
                                    }
                                    Spacer()
                                    Text(formatDuration(item.1))
                                        .font(.caption.bold())
                                        .monospacedDigit()
                                }
                            }
                        }
                    }

                    if splitData.count > 1 {
                        Divider()
                        subjectBarListSplit(data: splitData)
                    }
                }
            } else {
                let data = subjectData
                let periodTotal = data.reduce(0) { $0 + $1.1 }

                if periodTotal > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundStyle(selectedTab == .external ? .cyan : .blue)
                        Text("\(selectedPeriod.label)の合計")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatDuration(periodTotal))
                            .font(.subheadline.bold())
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 4)
                }

                if data.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.pie")
                            .font(.title)
                            .foregroundStyle(.tertiary)
                        Text("データがありません")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    HStack(spacing: 16) {
                        subjectDonutChart(data: data)
                            .frame(width: 120, height: 120)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(data.prefix(5).enumerated()), id: \.offset) { index, item in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(subjectColor(for: index, subjectName: item.0).opacity(selectedTab == .external ? 0.45 : 1.0))
                                        .frame(width: 10, height: 10)
                                    Text(item.0)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(formatDuration(item.1))
                                        .font(.caption.bold())
                                        .monospacedDigit()
                                }
                            }
                        }
                    }

                    if data.count > 1 {
                        Divider()
                        subjectBarList(data: data)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    private func subjectDonutChart(data: [(String, TimeInterval)]) -> some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                SectorMark(
                    angle: .value("時間", item.1),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(subjectColor(for: index, subjectName: item.0).opacity(selectedTab == .external ? 0.45 : 1.0))
                .cornerRadius(4)
            }
        }
        .chartLegend(.hidden)
        .overlay {
            VStack(spacing: 0) {
                Text("\(data.count)")
                    .font(.title3.bold())
                Text("教科")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func subjectBarList(data: [(String, TimeInterval)]) -> some View {
        let maxVal = data.map(\.1).max() ?? 1
        return VStack(spacing: 10) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.0)
                            .font(.caption.bold())
                        Spacer()
                        Text(formatDuration(item.1))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(subjectColor(for: index, subjectName: item.0).opacity(selectedTab == .external ? 0.45 : 1.0).gradient)
                            .frame(width: max(4, geo.size.width * (item.1 / maxVal)))
                    }
                    .frame(height: 8)
                }
            }
        }
    }

    private func subjectDonutChartSplit(data: [(String, TimeInterval, Bool)]) -> some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                SectorMark(
                    angle: .value("時間", item.1),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(subjectColor(for: index, subjectName: item.0).opacity(item.2 ? 0.45 : 1.0))
                .cornerRadius(4)
            }
        }
        .chartLegend(.hidden)
        .overlay {
            VStack(spacing: 0) {
                Text("\(data.count)")
                    .font(.title3.bold())
                Text("教科")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func subjectBarListSplit(data: [(String, TimeInterval, Bool)]) -> some View {
        let maxVal = data.map(\.1).max() ?? 1
        return VStack(spacing: 10) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.0)
                            .font(.caption.bold())
                        if item.2 {
                            Text("外")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.cyan)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.cyan.opacity(0.12), in: .capsule)
                        }
                        Spacer()
                        Text(formatDuration(item.1))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(subjectColor(for: index, subjectName: item.0).opacity(item.2 ? 0.45 : 1.0).gradient)
                            .frame(width: max(4, geo.size.width * (item.1 / maxVal)))
                    }
                    .frame(height: 8)
                }
            }
        }
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("今週の勉強時間")
                .font(.headline)

            Group {
                switch selectedTab {
                case .app:
                    appWeeklyChart
                case .external:
                    externalWeeklyChart
                case .total:
                    combinedWeeklyChart
                }
            }
            .frame(height: 200)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    private var appWeeklyChart: some View {
        let data = dataStore.weeklyStudyTimes
        return Chart {
            ForEach(data, id: \.0) { item in
                BarMark(
                    x: .value("曜日", item.0),
                    y: .value("時間", item.1 / 60)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .clipShape(.rect(cornerRadius: 6))
            }
        }
        .chartYAxisLabel("分")
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }

    private var externalWeeklyChart: some View {
        let data = dataStore.weeklyExternalStudyTimes
        return Chart {
            ForEach(data, id: \.0) { item in
                BarMark(
                    x: .value("曜日", item.0),
                    y: .value("時間", item.1 / 60)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan.opacity(0.5), .cyan.opacity(0.3)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .clipShape(.rect(cornerRadius: 6))
            }
        }
        .chartYAxisLabel("分")
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }

    private var combinedWeeklyChart: some View {
        let data = dataStore.weeklyCombinedStudyTimes
        return Chart {
            ForEach(data, id: \.0) { item in
                BarMark(
                    x: .value("曜日", item.0),
                    y: .value("時間", item.1 / 60)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .clipShape(.rect(cornerRadius: 6))

                BarMark(
                    x: .value("曜日", item.0),
                    y: .value("時間", item.2 / 60)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan.opacity(0.5), .cyan.opacity(0.3)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .clipShape(.rect(cornerRadius: 6))
            }
        }
        .chartYAxisLabel("分")
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }

    // MARK: - Recent Sessions

    private var recentSessionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近のセッション")
                .font(.headline)

            let recentSessions = filteredSessions

            if recentSessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("まだセッションがありません")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(recentSessions, id: \.id) { session in
                    if session.isExternal {
                        externalSessionRow(session)
                            .contextMenu {
                                Button(role: .destructive) {
                                    dataStore.deleteExternalSession(session)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                    } else {
                        sessionRow(session)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    private func sessionRow(_ session: StudySession) -> some View {
        let subjectLabel = session.subject.isEmpty ? "未設定" : session.subject
        let resolvedColor = subjectColorForName(subjectLabel)

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(session.isApproved ? resolvedColor.opacity(0.15) : Color.orange.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: session.isApproved ? "checkmark.circle.fill" : "clock.badge.questionmark")
                        .foregroundStyle(session.isApproved ? resolvedColor : .orange)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(subjectLabel)
                    .font(.subheadline.bold())
                HStack(spacing: 6) {
                    Text(session.startTime, style: .date)
                    Text("·")
                    Text(session.studyMode.title)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(session.formattedDuration)
                    .font(.subheadline.bold())
                    .monospacedDigit()
                if session.isApproved {
                    Text("承認済")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    private func externalSessionRow(_ session: StudySession) -> some View {
        let subjectLabel = session.subject.isEmpty ? "未設定" : session.subject
        let resolvedColor = subjectColorForName(subjectLabel)

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.cyan.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "pencil.line")
                        .foregroundStyle(.cyan)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(subjectLabel)
                    .font(.subheadline.bold())
                HStack(spacing: 6) {
                    Text(session.startTime, style: .date)
                    Text("·")
                    Text("手入力")
                        .foregroundStyle(.cyan)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.externalMinutes)分")
                    .font(.subheadline.bold())
                    .monospacedDigit()
                Text("アプリ外")
                    .font(.caption2)
                    .foregroundStyle(.cyan)
            }
        }
        .padding(12)
        .background(Color.cyan.opacity(0.04), in: .rect(cornerRadius: 12))
    }

    // MARK: - Data Helpers

    private var todayCardTitle: String {
        switch selectedTab {
        case .app: return "今日の勉強時間"
        case .external: return "今日のアプリ外"
        case .total: return "今日の合計"
        }
    }

    private var todayTime: TimeInterval {
        switch selectedTab {
        case .app: return dataStore.todayStudyTime
        case .external: return dataStore.todayExternalStudyTime
        case .total: return dataStore.todayTotalStudyTime
        }
    }

    private var subjectData: [(String, TimeInterval)] {
        switch (selectedTab, selectedPeriod) {
        case (.app, .today): return dataStore.todaySubjectBreakdown
        case (.app, .week): return dataStore.weeklySubjectBreakdown
        case (.app, .month): return dataStore.monthlySubjectBreakdown
        case (.external, .today): return dataStore.todayExternalSubjectBreakdown
        case (.external, .week): return dataStore.weeklyExternalSubjectBreakdown
        case (.external, .month): return dataStore.monthlyExternalSubjectBreakdown
        case (.total, .today): return dataStore.todayCombinedSubjectBreakdown
        case (.total, .week): return dataStore.weeklyCombinedSubjectBreakdown
        case (.total, .month): return dataStore.monthlyCombinedSubjectBreakdown
        }
    }

    private var subjectDataSplit: [(String, TimeInterval, Bool)] {
        switch selectedPeriod {
        case .today: return dataStore.todayCombinedSubjectBreakdownSplit
        case .week: return dataStore.weeklyCombinedSubjectBreakdownSplit
        case .month: return dataStore.monthlyCombinedSubjectBreakdownSplit
        }
    }

    private var filteredSessions: [StudySession] {
        let all = dataStore.sessions
        switch selectedTab {
        case .app:
            return Array(all.filter { !$0.isExternal }.prefix(10))
        case .external:
            return Array(all.filter { $0.isExternal }.prefix(10))
        case .total:
            return Array(all.prefix(10))
        }
    }

    private var approvedCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return dataStore.sessions.filter {
            !$0.isExternal && $0.isApproved && calendar.startOfDay(for: $0.startTime) == today
        }.count
    }

    private var todayApprovalRate: String {
        let total = todayAppSessionCount
        guard total > 0 else { return "--" }
        let rate = Int(round(Double(approvedCount) / Double(total) * 100))
        return "\(rate)%"
    }

    private var todayAppSessionCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return dataStore.sessions.filter {
            !$0.isExternal && calendar.startOfDay(for: $0.startTime) == today
        }.count
    }

    private var todayExternalSessionCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return dataStore.sessions.filter {
            $0.isExternal && calendar.startOfDay(for: $0.startTime) == today
        }.count
    }

    private var todayExternalSubjectCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let subjects = Set(
            dataStore.sessions
                .filter { $0.isExternal && calendar.startOfDay(for: $0.startTime) == today }
                .map { $0.subject.isEmpty ? "未設定" : $0.subject }
        )
        return subjects.count
    }

    private func subjectColor(for index: Int, subjectName: String? = nil) -> Color {
        if let name = subjectName, let stored = SubjectColorStore.color(for: name) {
            return stored
        }
        let colors: [Color] = [.blue, .orange, .green, .purple, .pink, .cyan, .mint, .indigo, .teal, .yellow]
        return colors[index % colors.count]
    }

    private func subjectColorForName(_ subject: String) -> Color {
        if let stored = SubjectColorStore.color(for: subject) {
            return stored
        }
        let allSubjects = dataStore.allTimeSubjectBreakdown.map(\.0)
        let index = allSubjects.firstIndex(of: subject) ?? 0
        let colors: [Color] = [.blue, .orange, .green, .purple, .pink, .cyan, .mint, .indigo, .teal, .yellow]
        return colors[index % colors.count]
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let total = Int(time)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        }
        return "\(minutes)分"
    }

    private func formatShortDuration(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        if hours > 0 {
            let mins = (Int(time) % 3600) / 60
            return "\(hours)h\(mins)m"
        }
        return "\(Int(time) / 60)m"
    }
}

nonisolated enum ReportTab: String, CaseIterable {
    case app
    case external
    case total

    var label: String {
        switch self {
        case .app: return "アプリ内"
        case .external: return "アプリ外"
        case .total: return "合計"
        }
    }
}

nonisolated enum ReportPeriod: String, CaseIterable, Identifiable {
    case today
    case week
    case month

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "今日"
        case .week: return "今週"
        case .month: return "今月"
        }
    }
}

struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08), in: .rect(cornerRadius: 12))
    }
}
