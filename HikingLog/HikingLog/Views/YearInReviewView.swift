import SwiftUI
import Charts
import MapKit

struct YearInReviewView: View {
    @Environment(HikeStore.self) private var store
    @State private var selectedYear: String = ""

    private var yearHikes: [Hike] {
        store.hikes.filter { $0.year == selectedYear }
    }

    private var totalMiles: Double { yearHikes.reduce(0) { $0 + $1.distanceMiles } }
    private var totalElev: Double { yearHikes.reduce(0) { $0 + $1.elevationGainFt } }
    private var totalHours: Double { Double(yearHikes.reduce(0) { $0 + $1.durationMinutes }) / 60.0 }
    private var uniqueTrails: Int { Set(yearHikes.map(\.trailName)).count }
    private var withJulieCount: Int { yearHikes.filter { $0.withJulie == true }.count }

    private var topTrails: [(name: String, count: Int, region: String)] {
        let grouped = Dictionary(grouping: yearHikes, by: \.trailName)
        return grouped.map { ($0.key, $0.value.count, $0.value[0].region) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0 }
    }

    private var monthlyMiles: [(month: String, miles: Double)] {
        var data: [String: Double] = [:]
        for h in yearHikes {
            let m = String(h.date.prefix(7))
            data[m, default: 0] += h.distanceMiles
        }
        return (1...12).map { m in
            let key = "\(selectedYear)-\(String(format: "%02d", m))"
            let monthName = DateFormatter().shortMonthSymbols[m - 1]
            return (monthName, data[key] ?? 0)
        }
    }

    private var regionBreakdown: [(region: String, count: Int)] {
        let grouped = Dictionary(grouping: yearHikes, by: \.region)
        return grouped.map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Year in Review")
                        .font(.largeTitle.bold())
                    Picker("", selection: $selectedYear) {
                        ForEach(store.years, id: \.self) { year in
                            Text(year).tag(year)
                        }
                    }
                    .frame(width: 100)
                    Spacer()
                }

                if yearHikes.isEmpty {
                    Text("No hikes recorded for \(selectedYear)")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Big stats
                    HStack(spacing: 12) {
                        BigStat(value: "\(yearHikes.count)", label: "Hikes", icon: "figure.hiking", tint: .green)
                        BigStat(value: String(format: "%.0f", totalMiles), label: "Miles", icon: "arrow.right", tint: .green)
                        BigStat(value: "\(Int(totalElev).formatted())", label: "Feet Climbed", icon: "arrow.up", tint: .blue)
                        BigStat(value: String(format: "%.0f", totalHours), label: "Hours", icon: "clock", tint: .orange)
                        BigStat(value: "\(uniqueTrails)", label: "Unique Trails", icon: "mappin", tint: .teal)
                        if withJulieCount > 0 {
                            BigStat(value: "\(withJulieCount)", label: "With \(PersonaConfig.person2)", icon: "person.2.fill", tint: .pink)
                        }
                    }

                    // Monthly miles chart
                    GroupBox("Miles by Month") {
                        Chart(monthlyMiles, id: \.month) { item in
                            BarMark(
                                x: .value("Month", item.month),
                                y: .value("Miles", item.miles)
                            )
                            .foregroundStyle(.green.gradient)
                            .cornerRadius(3)
                        }
                        .frame(height: 200)
                    }

                    HStack(spacing: 12) {
                        // Top trails
                        GroupBox("Top Trails") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(topTrails, id: \.name) { trail in
                                    HStack {
                                        Circle()
                                            .fill(HikeStore.color(for: trail.region))
                                            .frame(width: 8, height: 8)
                                        Text(trail.name)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(trail.count)x")
                                            .fontWeight(.bold)
                                            .foregroundStyle(.green)
                                    }
                                    .font(.callout)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        // Region breakdown
                        GroupBox("Regions") {
                            Chart(regionBreakdown, id: \.region) { item in
                                SectorMark(
                                    angle: .value("Hikes", item.count),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 1
                                )
                                .foregroundStyle(HikeStore.color(for: item.region))
                            }
                            .frame(height: 140)

                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(regionBreakdown.prefix(6), id: \.region) { item in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(HikeStore.color(for: item.region))
                                            .frame(width: 6, height: 6)
                                        Text(item.region)
                                            .font(.caption)
                                        Spacer()
                                        Text("\(item.count)")
                                            .font(.caption.bold())
                                    }
                                }
                            }
                        }
                    }

                    // Map of all hikes this year
                    GroupBox("Where You Hiked") {
                        Map {
                            ForEach(yearHikes) { hike in
                                Marker(hike.trailName, coordinate: hike.coordinate)
                                    .tint(HikeStore.color(for: hike.region))
                            }
                        }
                        .mapStyle(.standard(elevation: .realistic))
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // All hikes list
                    GroupBox("All \(yearHikes.count) Hikes") {
                        ForEach(yearHikes) { hike in
                            HStack {
                                Text(hike.formattedDate)
                                    .frame(width: 100, alignment: .leading)
                                Text(hike.trailName)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Spacer()
                                if hike.withJulie == true {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                }
                                Text(String(format: "%.1f mi", hike.distanceMiles))
                                    .monospacedDigit()
                                    .frame(width: 55, alignment: .trailing)
                                Text("\(Int(hike.elevationGainFt).formatted()) ft")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 65, alignment: .trailing)
                            }
                            .font(.callout)
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            if selectedYear.isEmpty {
                selectedYear = store.years.first ?? ""
            }
        }
    }
}

private struct BigStat: View {
    let value: String
    let label: String
    let icon: String
    var tint: Color = .green

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.title, design: .rounded).bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.secondary)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundStyle(tint.opacity(0.07))
                        .padding(6)
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
