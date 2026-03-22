import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(HikeStore.self) private var store
    @State private var selectedYear = "All"
    @State private var selectedRegion = "All"
    @State private var selectedTrailSummaryID: UUID?
    @State private var trailSummaryToView: TrailSummary?

    private var filtered: [Hike] {
        store.hikes.filter { hike in
            (selectedYear == "All" || hike.year == selectedYear) &&
            (selectedRegion == "All" || hike.region == selectedRegion)
        }
    }

    private var stats: (count: Int, miles: Double, feet: Double, avgMi: Double, avgFt: Int) {
        let list = filtered
        let n = max(list.count, 1)
        let totalMi = list.reduce(0.0) { $0 + $1.distanceMiles }
        let totalFt = list.reduce(0.0) { $0 + $1.elevationGainFt }
        return (list.count, totalMi, totalFt, totalMi / Double(n), Int(totalFt / Double(n)))
    }

    private var monthlyData: [(month: String, count: Int)] {
        var counts: [String: Int] = [:]
        for h in store.hikes {
            counts[h.yearMonth, default: 0] += 1
        }
        return counts.sorted { $0.key < $1.key }.suffix(24).map { ($0.key, $0.value) }
    }

    private var yearlyData: [(year: String, count: Int)] {
        var counts: [String: Int] = [:]
        for h in store.hikes {
            counts[h.year, default: 0] += 1
        }
        return counts.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "mountain.2.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("Hiking")
                        .font(.largeTitle.bold())
                    Text("\(store.hikes.count) hikes since 2018")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                    Spacer()
                }

                // Filters
                HStack(spacing: 12) {
                    Picker("Year", selection: $selectedYear) {
                        Text("All Years").tag("All")
                        ForEach(store.years, id: \.self) { year in
                            Text(year).tag(year)
                        }
                    }
                    .frame(width: 140)

                    Picker("Region", selection: $selectedRegion) {
                        Text("All Regions").tag("All")
                        ForEach(store.regions, id: \.self) { region in
                            Text(region).tag(region)
                        }
                    }
                    .frame(width: 220)

                    Spacer()
                }

                // Stats Cards
                HStack(spacing: 12) {
                    StatCard(title: "Hikes", value: "\(stats.count)", icon: "figure.hiking", tint: .green)
                    StatCard(title: "Total Miles", value: String(format: "%.1f", stats.miles), icon: "arrow.right", tint: .green)
                    StatCard(title: "Elevation", value: "\(Int(stats.feet).formatted()) ft", icon: "arrow.up", tint: .blue)
                    StatCard(title: "Avg Distance", value: String(format: "%.1f mi", stats.avgMi), icon: "ruler", tint: .teal)
                    StatCard(title: "Avg Elevation", value: "\(stats.avgFt.formatted()) ft", icon: "mountain.2", tint: .blue)
                }

                // Streaks, Year-over-Year, PRs
                HStack(spacing: 12) {
                    // Streaks
                    let streak = store.streakInfo
                    GroupBox("Streaks") {
                        HStack(spacing: 20) {
                            VStack(spacing: 2) {
                                Text("\(streak.currentWeeks)")
                                    .font(.title.bold())
                                    .foregroundStyle(streak.currentWeeks > 0 ? .green : .secondary)
                                Text("Current weeks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            VStack(spacing: 2) {
                                Text("\(streak.longestWeeks)")
                                    .font(.title.bold())
                                    .foregroundStyle(.orange)
                                Text("Longest streak")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            VStack(spacing: 2) {
                                Text("\(streak.daysSinceLastHike)")
                                    .font(.title.bold())
                                    .foregroundStyle(streak.daysSinceLastHike > 14 ? .red : .primary)
                                Text("Days since last")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }

                    // Year-over-Year
                    if let yoy = store.yearOverYear {
                        GroupBox("\(yoy.currentYear) vs \(Int(yoy.currentYear)! - 1) (same period)") {
                            HStack(spacing: 20) {
                                YoYStat(label: "Hikes", current: yoy.hikesThisYear, previous: yoy.hikesLastYear, pct: yoy.pctChangeHikes)
                                YoYStat(label: "Miles", current: Int(yoy.milesThisYear), previous: Int(yoy.milesLastYear), pct: yoy.pctChangeMiles)
                                YoYStat(label: "Elevation", current: Int(yoy.elevThisYear), previous: Int(yoy.elevLastYear),
                                        pct: yoy.elevLastYear == 0 ? 0 : (yoy.elevThisYear - yoy.elevLastYear) / yoy.elevLastYear * 100)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Personal Records
                let prs = store.personalRecords
                GroupBox("Personal Records") {
                    HStack(spacing: 12) {
                        if let h = prs.longestDistance {
                            PRCard(icon: "arrow.right", title: "Longest", value: String(format: "%.1f mi", h.distanceMiles), trail: h.trailName, date: h.formattedDate)
                        }
                        if let h = prs.mostElevation {
                            PRCard(icon: "arrow.up", title: "Most Elevation", value: "\(Int(h.elevationGainFt).formatted()) ft", trail: h.trailName, date: h.formattedDate)
                        }
                        if let h = prs.longestDuration {
                            PRCard(icon: "clock", title: "Longest Duration", value: h.formattedDuration, trail: h.trailName, date: h.formattedDate)
                        }
                        if let h = prs.fastestPace {
                            PRCard(icon: "speedometer", title: "Fastest Pace", value: String(format: "%.1f min/mi", h.pace), trail: h.trailName, date: h.formattedDate)
                        }
                    }
                }

                // Seasonal
                SeasonalSuggestionsBox(store: store)

                // Charts
                HStack(spacing: 12) {
                    // Monthly Activity
                    GroupBox("Monthly Activity (Last 24 months)") {
                        Chart(monthlyData, id: \.month) { item in
                            BarMark(
                                x: .value("Month", item.month),
                                y: .value("Hikes", item.count)
                            )
                            .foregroundStyle(.green)
                            .cornerRadius(3)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisValueLabel {
                                    if let s = value.as(String.self) {
                                        Text(s.suffix(5))
                                            .font(.caption2)
                                            .rotationEffect(.degrees(-45))
                                    }
                                }
                            }
                        }
                        .frame(height: 220)
                    }

                    // Yearly Summary
                    GroupBox("Yearly Summary") {
                        Chart(yearlyData, id: \.year) { item in
                            BarMark(
                                x: .value("Year", item.year),
                                y: .value("Hikes", item.count)
                            )
                            .foregroundStyle(.blue)
                            .cornerRadius(3)
                        }
                        .frame(height: 220)
                    }
                }

                // Top Trails
                GroupBox("Top 15 Most-Hiked Trails") {
                    let trails = Array(store.trailSummaries().prefix(15))
                    Table(trails, selection: $selectedTrailSummaryID) {
                        TableColumn("Trail") { t in
                            Text(t.name).fontWeight(.medium)
                        }
                        .width(min: 180, ideal: 250)

                        TableColumn("Region") { t in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(HikeStore.color(for: t.region))
                                    .frame(width: 8, height: 8)
                                Text(t.region)
                            }
                        }
                        .width(min: 120, ideal: 160)

                        TableColumn("Count") { t in
                            Text("\(t.count)")
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                        }
                        .width(60)

                        TableColumn("Avg Dist") { t in
                            Text("\(t.avgMiles, specifier: "%.1f") mi")
                        }
                        .width(80)

                        TableColumn("Avg Elev") { t in
                            Text("\(t.avgElevation.formatted()) ft")
                        }
                        .width(80)

                        TableColumn("Last Hiked") { t in
                            Text(t.lastHiked)
                                .foregroundStyle(.secondary)
                        }
                        .width(100)
                    }
                    .contextMenu(forSelectionType: UUID.self) { selection in
                        if let id = selection.first,
                           let trail = trails.first(where: { $0.id == id }) {
                            Button("View Hikes") {
                                trailSummaryToView = trail
                            }
                        }
                    } primaryAction: { selection in
                        if let id = selection.first,
                           let trail = trails.first(where: { $0.id == id }) {
                            trailSummaryToView = trail
                        }
                    }
                    .frame(height: CGFloat(trails.count) * 28 + 32)
                }
            }
            .padding()
        }
        .popover(item: $trailSummaryToView, arrowEdge: .leading) { summary in
            TrailSummaryHikesView(summary: summary, store: store)
        }
    }
}

struct TrailSummaryHikesView: View {
    let summary: TrailSummary
    let store: HikeStore

    private var hikes: [Hike] {
        store.hikes
            .filter { $0.trailName == summary.name }
            .sorted { $0.date > $1.date }
    }

    private var totalMiles: Double { hikes.reduce(0) { $0 + $1.distanceMiles } }
    private var totalElevation: Double { hikes.reduce(0) { $0 + $1.elevationGainFt } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.name)
                    .font(.title2.bold())
                HStack(spacing: 4) {
                    Circle()
                        .fill(HikeStore.color(for: summary.region))
                        .frame(width: 8, height: 8)
                    Text(summary.region)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            HStack(spacing: 0) {
                MiniStat(label: "Hikes", value: "\(hikes.count)")
                MiniStat(label: "Total Miles", value: String(format: "%.1f", totalMiles))
                MiniStat(label: "Total Elev.", value: "\(Int(totalElevation).formatted()) ft")
                MiniStat(label: "Avg Dist", value: String(format: "%.1f mi", summary.avgMiles))
                MiniStat(label: "Avg Elev", value: "\(summary.avgElevation.formatted()) ft")
            }
            .padding(.vertical, 8)
            .background(.background.secondary)

            Divider()

            if hikes.count > 1 {
                Chart(hikes) { h in
                    LineMark(
                        x: .value("Date", h.parsedDate),
                        y: .value("Distance", h.distanceMiles)
                    )
                    .foregroundStyle(.blue.opacity(0.6))
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Date", h.parsedDate),
                        y: .value("Distance", h.distanceMiles)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(20)
                }
                .chartYAxisLabel("mi")
                .frame(height: 100)
                .padding(.horizontal)
                .padding(.top, 8)

                Divider()
            }

            List(hikes) { hike in
                HStack {
                    Text(hike.formattedDate)
                        .frame(width: 100, alignment: .leading)
                    Spacer()
                    Text(String(format: "%.1f mi", hike.distanceMiles))
                        .monospacedDigit()
                        .frame(width: 60, alignment: .trailing)
                    Text("\(Int(hike.elevationGainFt).formatted()) ft")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .trailing)
                    Text(hike.formattedDuration)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
                .font(.callout)
            }
        }
        .frame(width: 480, height: 460)
    }
}

private struct MiniStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var icon: String = "chart.bar"
    var tint: Color = .green

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Text(value)
                .font(.system(.title2, design: .rounded).bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.secondary)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 30))
                        .foregroundStyle(tint.opacity(0.08))
                        .padding(8)
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct YoYStat: View {
    let label: String
    let current: Int
    let previous: Int
    let pct: Double

    var body: some View {
        VStack(spacing: 2) {
            Text("\(current)")
                .font(.title2.bold())
            HStack(spacing: 2) {
                Image(systemName: pct >= 0 ? "arrow.up" : "arrow.down")
                    .font(.system(size: 9, weight: .bold))
                Text(String(format: "%.0f%%", abs(pct)))
                    .font(.caption2)
            }
            .foregroundStyle(pct >= 0 ? .green : .orange)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct PRCard: View {
    let icon: String
    let title: String
    let value: String
    let trail: String
    let date: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(.orange)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.title3, design: .rounded).bold())
            Text(trail)
                .font(.caption)
                .lineLimit(1)
            Text(date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.background.secondary)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.orange.opacity(0.08))
                        .padding(6)
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SeasonalSuggestionsBox: View {
    let store: HikeStore
    @State private var suggestions: [(trail: String, region: String, count: Int)] = []
    @State private var monthName = ""

    var body: some View {
        if !suggestions.isEmpty {
            GroupBox("You usually hike these in \(monthName)") {
                HStack(spacing: 12) {
                    ForEach(suggestions, id: \.trail) { s in
                        HStack(spacing: 6) {
                            Circle().fill(HikeStore.color(for: s.region)).frame(width: 8, height: 8)
                            Text(s.trail).fontWeight(.medium)
                            Text("(\(s.count)x)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
            }
            .onAppear { loadSuggestions() }
        } else {
            EmptyView()
                .onAppear { loadSuggestions() }
        }
    }

    private func loadSuggestions() {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM"
        monthName = fmt.string(from: Date())
        suggestions = store.seasonalSuggestions()
    }
}
