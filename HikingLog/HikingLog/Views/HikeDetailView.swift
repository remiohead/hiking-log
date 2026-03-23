import SwiftUI
import MapKit
import Charts

struct HikeDetailView: View {
    let hike: Hike
    let store: HikeStore
    let trailStore: TrailStore
    @Environment(\.dismiss) private var dismiss

    private var linkedTrail: Trail? {
        trailStore.trail(byID: hike.trailID)
    }

    private var trailHistory: [Hike] {
        store.hikes
            .filter { $0.trailName == hike.trailName }
            .sorted { $0.date > $1.date }
    }

    private var avgDistance: Double {
        let h = trailHistory
        guard !h.isEmpty else { return 0 }
        return h.reduce(0.0) { $0 + $1.distanceMiles } / Double(h.count)
    }

    private var avgElevation: Double {
        let h = trailHistory
        guard !h.isEmpty else { return 0 }
        return h.reduce(0.0) { $0 + $1.elevationGainFt } / Double(h.count)
    }

    private var avgDuration: Int {
        let h = trailHistory
        guard !h.isEmpty else { return 0 }
        return h.reduce(0) { $0 + $1.durationMinutes } / h.count
    }

    private var pace: Double {
        guard hike.durationMinutes > 0, hike.distanceMiles > 0 else { return 0 }
        return Double(hike.durationMinutes) / hike.distanceMiles
    }

    private var altitudeRange: Double {
        hike.maxAltitudeFt - hike.minAltitudeFt
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with map
                ZStack(alignment: .bottomLeading) {
                    Map {
                        Marker(hike.trailName, coordinate: hike.coordinate)
                            .tint(HikeStore.color(for: hike.region))
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .frame(height: 200)
                    .allowsHitTesting(false)

                    // Gradient overlay
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(hike.trailName)
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(HikeStore.color(for: hike.region))
                                    .frame(width: 8, height: 8)
                                Text(hike.region)
                            }
                            Text(hike.formattedDate)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding()
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10))

                VStack(alignment: .leading, spacing: 20) {
                    // Key stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
                    ], spacing: 12) {
                        StatTile(icon: "figure.hiking", label: "Distance", value: String(format: "%.2f mi", hike.distanceMiles))
                        StatTile(icon: "arrow.up.right", label: "Elevation Gain", value: "\(Int(hike.elevationGainFt).formatted()) ft")
                        StatTile(icon: "clock", label: "Duration", value: hike.formattedDuration)
                        StatTile(icon: "speedometer", label: "Pace", value: pace > 0 ? String(format: "%.1f min/mi", pace) : "—")
                        StatTile(icon: "mountain.2", label: "Altitude Range", value: altitudeRange > 0 ? "\(Int(hike.minAltitudeFt).formatted())–\(Int(hike.maxAltitudeFt).formatted()) ft" : "—")
                        StatTile(icon: "arrow.up.and.down", label: "Alt. Gain", value: altitudeRange > 0 ? "\(Int(altitudeRange).formatted()) ft" : "—")
                    }

                    // Photos from this day
                    Divider()
                    HikePhotosStrip(date: hike.date, lat: hike.startLat, lon: hike.startLon)

                    // Trail link
                    if let trail = linkedTrail, let urlStr = trail.url, let url = URL(string: urlStr) {
                        Divider()
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Trail Page")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(trail.displayURL ?? urlStr)
                                    .font(.callout)
                                    .foregroundStyle(.blue)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button("Open") {
                                openURL(url)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    // Comparison to average (if multiple visits)
                    if trailHistory.count > 1 {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This Hike vs. Average")
                                .font(.headline)

                            HStack(spacing: 16) {
                                ComparisonBar(
                                    label: "Distance",
                                    thisValue: hike.distanceMiles,
                                    avgValue: avgDistance,
                                    unit: "mi",
                                    format: "%.1f"
                                )
                                ComparisonBar(
                                    label: "Elevation",
                                    thisValue: hike.elevationGainFt,
                                    avgValue: avgElevation,
                                    unit: "ft",
                                    format: "%.0f"
                                )
                                ComparisonBar(
                                    label: "Duration",
                                    thisValue: Double(hike.durationMinutes),
                                    avgValue: Double(avgDuration),
                                    unit: "min",
                                    format: "%.0f"
                                )
                            }
                        }
                    }

                    // Visit history
                    if trailHistory.count > 1 {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Visit History")
                                .font(.headline)
                            Text("\(trailHistory.count) visits total")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            // Distance over time chart
                            Chart(trailHistory) { h in
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
                                .foregroundStyle(h.id == hike.id ? .orange : .blue)
                                .symbolSize(h.id == hike.id ? 60 : 30)
                            }
                            .chartYAxisLabel("Distance (mi)")
                            .frame(height: 120)

                            // History list
                            ForEach(trailHistory) { h in
                                HStack {
                                    if h.id == hike.id {
                                        Image(systemName: "arrow.right")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                    Text(h.formattedDate)
                                        .font(.callout)
                                        .fontWeight(h.id == hike.id ? .bold : .regular)
                                        .foregroundStyle(h.id == hike.id ? .primary : .secondary)
                                    Spacer()
                                    Text(String(format: "%.1f mi", h.distanceMiles))
                                        .font(.callout)
                                        .monospacedDigit()
                                    Text("\(Int(h.elevationGainFt).formatted()) ft")
                                        .font(.callout)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                        .frame(width: 70, alignment: .trailing)
                                    Text(h.formattedDuration)
                                        .font(.callout)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60, alignment: .trailing)
                                }
                            }
                        }
                    }

                    // Trail info from linked trail
                    if let trail = linkedTrail {
                        if trail.difficulty != nil || trail.dogFriendly != nil || trail.trailDescription != nil {
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Trail Info")
                                    .font(.headline)

                                if let diff = trail.difficulty {
                                    HStack {
                                        Text("Difficulty")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(diff.capitalized)
                                            .fontWeight(.medium)
                                    }
                                    .font(.callout)
                                }
                                if let dog = trail.dogFriendly {
                                    HStack {
                                        Text("Dogs")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(dog ? "Allowed" : "Not allowed")
                                            .fontWeight(.medium)
                                    }
                                    .font(.callout)
                                }
                                if let desc = trail.trailDescription, !desc.isEmpty {
                                    Text(desc)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(4)
                                }
                            }
                        }
                    }

                    // Coordinates
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Coordinates")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.4f, %.4f", hike.startLat, hike.startLon))
                                .font(.callout.monospaced())
                        }
                        Spacer()
                        Button("Open in Maps") {
                            let urlStr = "https://maps.apple.com/?ll=\(hike.startLat),\(hike.startLon)&q=\(hike.trailName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                            if let url = URL(string: urlStr) {
                                openURL(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding()
            }
        }
        .frame(width: 520, height: 680)
        .background(.background)
    }
}

// MARK: - Stat Tile

struct StatTile: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Comparison Bar

struct ComparisonBar: View {
    let label: String
    let thisValue: Double
    let avgValue: Double
    let unit: String
    let format: String

    private var diff: Double { thisValue - avgValue }
    private var pctDiff: Double {
        guard avgValue != 0 else { return 0 }
        return (diff / avgValue) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: format, thisValue))
                    .font(.callout.bold())
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 2) {
                Image(systemName: diff >= 0 ? "arrow.up" : "arrow.down")
                    .font(.system(size: 9, weight: .bold))
                Text(String(format: "%.0f%%", abs(pctDiff)))
                    .font(.caption2)
            }
            .foregroundStyle(diff >= 0 ? .orange : .blue)

            Text(String(format: "avg " + format + " " + unit, avgValue))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
