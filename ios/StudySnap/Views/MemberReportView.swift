import SwiftUI
import Charts

struct MemberReportView: View {
    let member: UserProfile
    let dataStore: DataStore

    @State private var sessions: [StudySession] = []
    @State private var isLoading: Bool = true
    @State private var selectedTab: ReportTab = .app
    @State private var selectedPeriod: ReportPeriod = .today

    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("読み込み中...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else {
                VStack(spacing: 24) {
                    reportTabPicker
                    summaryCard
                    subjectBreakdownCard
                    weeklyChartCard
                    recentSessionsCard
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(member.name)のレポート")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            sessions = await dataStore.fetchSessionsForMember(member.id)
            isLoading = false
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

    // MARK: - Summary

    private var summaryCard: some View {
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
                                memberStreak > 0
                                    ? LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                            )
                        Text("\(memberStreak)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(memberStreak > 0 ? .primary : .secondary)
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
                        value: "\(totalApprovedCount)",
                        color: .green
                    )
                    StatBadge(
                        icon: "camera.fill",
                        label: "セッション",
                        value: "\(appSessionCount)",
                        color: .blue
                    )
                    StatBadge(
                        icon: "percent",
                        label: "承認率",
                        value: approvalRate,
                        color: .purple
                    )
                }
            } else if selectedTab == .external {
                HStack(spacing: 16) {
                    StatBadge(
                        icon: "pencil.line",
                        label: "手入力",
                        value: "\(externalSessionCount)",
                        color: .cyan
                    )
                    StatBadge(
                        icon: "book.closed.fill",
                        label: "教科数",
                        value: "\(externalSubjectCount)",
                        color: .teal
                    )
                }
            } else {
                HStack(spacing: 16) {
                    StatBadge(
                        icon: "iphone",
                        label: "アプリ内",
                        value: formatShortDuration(memberAppTotalTime),
                        color: .blue
                    )
                    StatBadge(
                        icon: "pencil.line",
                        label: "アプリ外",
                        value: formatShortDuration(memberExternalTotalTime),
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
                    emptyDataView
                } else {
                    HStack(spacing: 16) {
                        donutChartSplit(data: splitData)
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
                        barListSplit(data: splitData)
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
                    emptyDataView
                } else {
                    HStack(spacing: 16) {
                        donutChart(data: data)
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
                        barList(data: data)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    private var emptyDataView: some View {
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
    }

    private func donutChart(data: [(String, TimeInterval)]) -> some View {
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

    private func barList(data: [(String, TimeInterval)]) -> some View {
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

    private func donutChartSplit(data: [(String, TimeInterval, Bool)]) -> some View {
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

    private func barListSplit(data: [(String, TimeInterval, Bool)]) -> some View {
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

    private var weeklyChartCard: some View {
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
        let data = memberWeeklyData(filter: .app)
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
        let data = memberWeeklyData(filter: .external)
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
        let data = memberWeeklyCombinedData
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

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近のセッション")
                .font(.headline)

            let recent = filteredSessions

            if recent.isEmpty {
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
                ForEach(recent, id: \.id) { session in
                    if session.isExternal {
                        externalSessionRow(session)
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
        case .app: return "累計勉強時間"
        case .external: return "累計アプリ外"
        case .total: return "累計合計"
        }
    }

    private var todayTime: TimeInterval {
        switch selectedTab {
        case .app: return memberAppTotalTime
        case .external: return memberExternalTotalTime
        case .total: return memberAppTotalTime + memberExternalTotalTime
        }
    }

    private var memberAppTotalTime: TimeInterval {
        sessions.filter { !$0.isExternal && $0.approvedPhotoCount > 0 }
            .reduce(0.0) { $0 + $1.studyMode.averageInterval * Double(max(1, $1.approvedPhotoCount)) }
    }

    private var memberExternalTotalTime: TimeInterval {
        sessions.filter { $0.isExternal }
            .reduce(0.0) { $0 + Double($1.externalMinutes) * 60 }
    }

    private var memberStreak: Int {
        let calendar = Calendar.current
        let studyDates = Set(sessions.filter { $0.isApproved }.map { calendar.startOfDay(for: $0.startTime) })
        guard !studyDates.isEmpty else { return 0 }
        var streak = 0
        var checkDate = calendar.startOfDay(for: .now)
        if !studyDates.contains(checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }
        while studyDates.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    private var totalApprovedCount: Int {
        sessions.filter { !$0.isExternal && $0.isApproved }.count
    }

    private var appSessionCount: Int {
        sessions.filter { !$0.isExternal }.count
    }

    private var externalSessionCount: Int {
        sessions.filter { $0.isExternal }.count
    }

    private var externalSubjectCount: Int {
        Set(sessions.filter { $0.isExternal }.map { $0.subject.isEmpty ? "未設定" : $0.subject }).count
    }

    private var approvalRate: String {
        guard appSessionCount > 0 else { return "--" }
        let rate = Int(round(Double(totalApprovedCount) / Double(appSessionCount) * 100))
        return "\(rate)%"
    }

    private var filteredSessions: [StudySession] {
        switch selectedTab {
        case .app:
            return Array(sessions.filter { !$0.isExternal }.prefix(10))
        case .external:
            return Array(sessions.filter { $0.isExternal }.prefix(10))
        case .total:
            return Array(sessions.prefix(10))
        }
    }

    private var subjectData: [(String, TimeInterval)] {
        let calendar = Calendar.current
        let filtered: [StudySession]

        let isApp = selectedTab == .app

        switch selectedPeriod {
        case .today:
            let today = calendar.startOfDay(for: .now)
            filtered = sessions.filter {
                let matchType = isApp ? (!$0.isExternal && $0.approvedPhotoCount > 0) : $0.isExternal
                return matchType && calendar.startOfDay(for: $0.startTime) == today
            }
        case .week:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
            filtered = sessions.filter {
                let matchType = isApp ? (!$0.isExternal && $0.approvedPhotoCount > 0) : $0.isExternal
                return matchType && $0.startTime >= weekInterval.start && $0.startTime < weekInterval.end
            }
        case .month:
            guard let monthInterval = calendar.dateInterval(of: .month, for: .now) else { return [] }
            filtered = sessions.filter {
                let matchType = isApp ? (!$0.isExternal && $0.approvedPhotoCount > 0) : $0.isExternal
                return matchType && $0.startTime >= monthInterval.start && $0.startTime < monthInterval.end
            }
        }

        var dict: [String: TimeInterval] = [:]
        for session in filtered {
            let key = session.subject.isEmpty ? "未設定" : (session.subject == "なし" ? "教科なし" : session.subject)
            if session.isExternal {
                dict[key, default: 0] += Double(session.externalMinutes) * 60
            } else {
                dict[key, default: 0] += session.studyMode.averageInterval * Double(max(1, session.approvedPhotoCount))
            }
        }
        return dict.sorted { $0.value > $1.value }
    }

    private var subjectDataSplit: [(String, TimeInterval, Bool)] {
        let calendar = Calendar.current
        let filtered: [StudySession]

        switch selectedPeriod {
        case .today:
            let today = calendar.startOfDay(for: .now)
            filtered = sessions.filter {
                ((!$0.isExternal && $0.approvedPhotoCount > 0) || $0.isExternal) && calendar.startOfDay(for: $0.startTime) == today
            }
        case .week:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
            filtered = sessions.filter {
                ((!$0.isExternal && $0.approvedPhotoCount > 0) || $0.isExternal) && $0.startTime >= weekInterval.start && $0.startTime < weekInterval.end
            }
        case .month:
            guard let monthInterval = calendar.dateInterval(of: .month, for: .now) else { return [] }
            filtered = sessions.filter {
                ((!$0.isExternal && $0.approvedPhotoCount > 0) || $0.isExternal) && $0.startTime >= monthInterval.start && $0.startTime < monthInterval.end
            }
        }

        var appDict: [String: TimeInterval] = [:]
        var extDict: [String: TimeInterval] = [:]
        for session in filtered {
            let key = session.subject.isEmpty ? "未設定" : (session.subject == "なし" ? "教科なし" : session.subject)
            if session.isExternal {
                extDict[key, default: 0] += Double(session.externalMinutes) * 60
            } else {
                appDict[key, default: 0] += session.studyMode.averageInterval * Double(max(1, session.approvedPhotoCount))
            }
        }

        var result: [(String, TimeInterval, Bool)] = []
        for (key, value) in appDict {
            result.append((key, value, false))
        }
        for (key, value) in extDict {
            result.append((key, value, true))
        }
        return result.sorted { $0.1 > $1.1 }
    }

    private func memberWeeklyData(filter: ReportTab) -> [(String, TimeInterval)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var result: [(String, TimeInterval)] = []

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let dayTotal = sessions
                .filter { $0.startTime >= dayStart && $0.startTime < dayEnd }
                .reduce(0.0) { total, session in
                    if filter == .app {
                        if !session.isExternal && session.approvedPhotoCount > 0 {
                            return total + session.studyMode.averageInterval * Double(max(1, session.approvedPhotoCount))
                        }
                    } else {
                        if session.isExternal {
                            return total + Double(session.externalMinutes) * 60
                        }
                    }
                    return total
                }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "E"
            result.append((formatter.string(from: date), dayTotal))
        }
        return result
    }

    private var memberWeeklyCombinedData: [(String, TimeInterval, TimeInterval)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var result: [(String, TimeInterval, TimeInterval)] = []

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let daySessions = sessions.filter { $0.startTime >= dayStart && $0.startTime < dayEnd }

            let appTotal = daySessions.reduce(0.0) { total, session in
                if !session.isExternal && session.approvedPhotoCount > 0 {
                    return total + session.studyMode.averageInterval * Double(max(1, session.approvedPhotoCount))
                }
                return total
            }

            let extTotal = daySessions.reduce(0.0) { total, session in
                if session.isExternal {
                    return total + Double(session.externalMinutes) * 60
                }
                return total
            }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "E"
            result.append((formatter.string(from: date), appTotal, extTotal))
        }
        return result
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
        let allSubjects = subjectData.map(\.0)
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
