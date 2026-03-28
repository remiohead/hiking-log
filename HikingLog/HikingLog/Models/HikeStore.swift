import Foundation
import SwiftUI
import CoreLocation

@Observable
final class HikeStore {
    var hikes: [Hike] = []
    var importStatus: String?

    static var dataFileURL: URL {
        hikingDataDir.appendingPathComponent("hike_history.json")
    }

    static let regionColors: [String: Color] = [
        "Alpine Lakes": .blue,
        "Snoqualmie Pass": .red,
        "I-90 Corridor": .orange,
        "Seattle Urban": Color(red: 0.06, green: 0.72, blue: 0.51),
        "West Seattle": .green,
        "San Juan Islands": .purple,
        "North Cascades": .cyan,
        "Olympic Peninsula": .pink,
        "Issaquah/Tiger Mountain": Color(red: 0.66, green: 0.33, blue: 0.96),
        "Mount Rainier": .yellow,
        "Index/Stevens Pass": .teal,
        "Unknown": .gray,
        "Cascade Foothills": Color(red: 0.52, green: 0.80, blue: 0.09),
        "Teanaway/Cle Elum": Color(red: 0.85, green: 0.27, blue: 0.94),
        "Oregon Coast": Color(red: 0.47, green: 0.44, blue: 0.40),
        "Westport": Color(red: 0.47, green: 0.44, blue: 0.40),
        "Whidbey Island": Color(red: 0.05, green: 0.65, blue: 0.91),
        "Port Angeles/Townsend": Color(red: 0.96, green: 0.25, blue: 0.37),
        "Cascade Loop": Color(red: 0.03, green: 0.57, blue: 0.70),
        "Snoqualmie Valley": Color(red: 0.40, green: 0.64, blue: 0.05)
    ]

    init() {
        load()
    }

    // MARK: - Data Loading & Persistence

    private func load() {
        let fileURL = Self.dataFileURL

        // Migrate from old "HikingLog" directory if needed
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let oldDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("HikingLog")
                .appendingPathComponent("hike_history.json")
            if FileManager.default.fileExists(atPath: oldDir.path) {
                try? FileManager.default.copyItem(at: oldDir, to: fileURL)
            }
        }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            loadFromURL(fileURL)
        } else {
            if let bundleURL = resourceBundle.url(forResource: "hike_history", withExtension: "json") {
                loadFromURL(bundleURL)
                save()
            }
        }
    }

    private func loadFromURL(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            hikes = try JSONDecoder().decode([Hike].self, from: data)
            hikes.sort { $0.date > $1.date }
        } catch {
            print("Failed to load hikes: \(error)")
        }
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(hikes)
            try data.write(to: Self.dataFileURL)
        } catch {
            print("Failed to save hikes: \(error)")
        }
    }

    // MARK: - Import

    func previewFromJSON(_ url: URL) throws -> [Hike] {
        let data = try Data(contentsOf: url)
        let newHikes = try JSONDecoder().decode([Hike].self, from: data)
        let existingIDs = Set(hikes.map(\.id))
        return newHikes.filter { !existingIDs.contains($0.id) }.sorted { $0.date > $1.date }
    }

    #if os(macOS)
    func previewFromHealthExportZip(_ url: URL, trailStore: TrailStore) throws -> (hikes: [Hike], skipped: Int, errors: [String]) {
        let existingIDs = Set(hikes.map(\.id))
        let result = try HealthAutoExportImporter.importFromZip(
            at: url,
            existingIDs: existingIDs,
            trailStore: trailStore
        )
        return (result.hikes.sorted { $0.date > $1.date }, result.skipped, result.errors)
    }
    #endif

    func importSelected(_ newHikes: [Hike]) {
        hikes.append(contentsOf: newHikes)
        hikes.sort { $0.date > $1.date }
        save()
        importStatus = "Imported \(newHikes.count) hikes"
    }

    func exportToFile(_ url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(hikes)
        try data.write(to: url)
    }

    // MARK: - CRUD

    func add(_ hike: Hike) {
        hikes.append(hike)
        hikes.sort { $0.date > $1.date }
        save()
    }

    func update(_ hike: Hike) {
        guard let idx = hikes.firstIndex(where: { $0.id == hike.id }) else { return }
        hikes[idx] = hike
        save()
    }

    /// Find other hikes that share the old trail name (excluding the edited hike),
    /// with their distance from the edited hike's start coordinates.
    func siblingHikes(for hike: Hike, oldTrailName: String) -> [(hike: Hike, distanceMiles: Double)] {
        let thisLocation = CLLocation(latitude: hike.startLat, longitude: hike.startLon)
        return hikes
            .filter { $0.id != hike.id && $0.trailName == oldTrailName }
            .map { other in
                let otherLocation = CLLocation(latitude: other.startLat, longitude: other.startLon)
                let distMiles = thisLocation.distance(from: otherLocation) / 1609.344
                return (other, distMiles)
            }
            .sorted { $0.distanceMiles < $1.distanceMiles }
    }

    /// Bulk update selected hikes to match a trail
    func bulkUpdateTrail(hikeIDs: Set<String>, trailName: String, region: String, trailID: String?) {
        for i in hikes.indices {
            if hikeIDs.contains(hikes[i].id) {
                hikes[i].trailName = trailName
                hikes[i].region = region
                hikes[i].trailID = trailID
            }
        }
        save()
    }

    func delete(_ hike: Hike) {
        hikes.removeAll { $0.id == hike.id }
        save()
    }

    // MARK: - Trail Linking

    /// Link a hike to a trail, updating the hike's name and region
    func linkHike(_ hikeID: String, toTrail trail: Trail) {
        guard let idx = hikes.firstIndex(where: { $0.id == hikeID }) else { return }
        hikes[idx].trailID = trail.id
        hikes[idx].trailName = trail.name
        hikes[idx].region = trail.region
        save()
    }

    /// Unlink a hike from its trail
    func unlinkHike(_ hikeID: String) {
        guard let idx = hikes.firstIndex(where: { $0.id == hikeID }) else { return }
        hikes[idx].trailID = nil
        save()
    }

    // MARK: - Computed Properties

    var years: [String] {
        Array(Set(hikes.map(\.year))).sorted().reversed()
    }

    var regions: [String] {
        Array(Set(hikes.map(\.region))).sorted()
    }

    func trailSummaries(from hikeList: [Hike]? = nil) -> [TrailSummary] {
        let source = hikeList ?? hikes
        let grouped = Dictionary(grouping: source, by: \.trailName)
        return grouped.map { name, entries in
            let avgMi = entries.reduce(0.0) { $0 + $1.distanceMiles } / Double(entries.count)
            let avgFt = entries.reduce(0.0) { $0 + $1.elevationGainFt } / Double(entries.count)
            let avgLat = entries.reduce(0.0) { $0 + $1.startLat } / Double(entries.count)
            let avgLon = entries.reduce(0.0) { $0 + $1.startLon } / Double(entries.count)
            let last = entries.max(by: { $0.date < $1.date })?.date ?? ""
            return TrailSummary(
                name: name,
                region: entries[0].region,
                count: entries.count,
                avgMiles: (avgMi * 10).rounded() / 10,
                avgElevation: Int(avgFt),
                lastHiked: last,
                latitude: avgLat,
                longitude: avgLon
            )
        }.sorted { $0.count > $1.count }
    }

    static func color(for region: String) -> Color {
        regionColors[region] ?? .gray
    }

    // MARK: - Streaks

    struct StreakInfo {
        let currentWeeks: Int
        let longestWeeks: Int
        let currentStart: String?
        let daysSinceLastHike: Int
    }

    var streakInfo: StreakInfo {
        guard !hikes.isEmpty else {
            return StreakInfo(currentWeeks: 0, longestWeeks: 0, currentStart: nil, daysSinceLastHike: 0)
        }
        let cal = Calendar.current
        let today = Date()
        let sortedDates = hikes.compactMap { h -> Date? in
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.date(from: h.date)
        }.sorted()

        let daysSinceLast = sortedDates.last.map { cal.dateComponents([.day], from: $0, to: today).day ?? 0 } ?? 0

        // Group by ISO week
        var weekSet = Set<String>()
        let weekFmt = DateFormatter()
        weekFmt.dateFormat = "yyyy-'W'ww"
        for d in sortedDates { weekSet.insert(weekFmt.string(from: d)) }

        // Count consecutive weeks ending at current/most recent
        var current = 0
        var longest = 0
        var streak = 0
        var checkDate = today
        while true {
            let weekStr = weekFmt.string(from: checkDate)
            if weekSet.contains(weekStr) {
                streak += 1
                checkDate = cal.date(byAdding: .weekOfYear, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        current = streak

        // Find longest streak across all weeks
        let allWeeks = weekSet.sorted()
        streak = 1
        longest = 1
        for i in 1..<allWeeks.count {
            let prev = allWeeks[i - 1]
            let curr = allWeeks[i]
            if let pd = weekFmt.date(from: prev), let cd = weekFmt.date(from: curr),
               cal.dateComponents([.weekOfYear], from: pd, to: cd).weekOfYear == 1 {
                streak += 1
                longest = max(longest, streak)
            } else {
                streak = 1
            }
        }

        let startDate: String? = {
            if current > 0 {
                let start = cal.date(byAdding: .weekOfYear, value: -(current - 1), to: today)!
                let fmt = DateFormatter()
                fmt.dateStyle = .medium
                return fmt.string(from: start)
            }
            return nil
        }()

        return StreakInfo(currentWeeks: current, longestWeeks: longest, currentStart: startDate, daysSinceLastHike: daysSinceLast)
    }

    // MARK: - Personal Records

    struct PersonalRecords {
        let longestDistance: Hike?
        let mostElevation: Hike?
        let longestDuration: Hike?
        let fastestPace: Hike?  // min/mi, lower is faster
    }

    var personalRecords: PersonalRecords {
        let valid = hikes.filter { $0.distanceMiles > 0 }
        return PersonalRecords(
            longestDistance: valid.max(by: { $0.distanceMiles < $1.distanceMiles }),
            mostElevation: valid.max(by: { $0.elevationGainFt < $1.elevationGainFt }),
            longestDuration: valid.max(by: { $0.durationMinutes < $1.durationMinutes }),
            fastestPace: valid.filter { $0.distanceMiles >= 3 }.min(by: { $0.pace < $1.pace })
        )
    }

    // MARK: - Year-over-Year

    struct YearComparison {
        let currentYear: String
        let hikesThisYear: Int
        let hikesLastYear: Int
        let milesThisYear: Double
        let milesLastYear: Double
        let elevThisYear: Double
        let elevLastYear: Double
        let pctChangeHikes: Double
        let pctChangeMiles: Double
    }

    var yearOverYear: YearComparison? {
        let cal = Calendar.current
        let now = Date()
        let currentYear = cal.component(.year, from: now)
        let dayOfYear = cal.ordinateDay(in: now)

        let thisYearHikes = hikes.filter { $0.year == "\(currentYear)" }
        // Last year, same period
        let lastYearStr = "\(currentYear - 1)"
        let cutoff = "\(lastYearStr)-\(String(format: "%02d", cal.component(.month, from: now)))-\(String(format: "%02d", cal.component(.day, from: now)))"
        let lastYearHikes = hikes.filter { $0.year == lastYearStr && $0.date <= cutoff }

        let thisM = thisYearHikes.reduce(0.0) { $0 + $1.distanceMiles }
        let lastM = lastYearHikes.reduce(0.0) { $0 + $1.distanceMiles }
        let thisE = thisYearHikes.reduce(0.0) { $0 + $1.elevationGainFt }
        let lastE = lastYearHikes.reduce(0.0) { $0 + $1.elevationGainFt }

        let pctH = lastYearHikes.isEmpty ? 0 : Double(thisYearHikes.count - lastYearHikes.count) / Double(lastYearHikes.count) * 100
        let pctM = lastM == 0 ? 0 : (thisM - lastM) / lastM * 100

        return YearComparison(
            currentYear: "\(currentYear)",
            hikesThisYear: thisYearHikes.count,
            hikesLastYear: lastYearHikes.count,
            milesThisYear: thisM,
            milesLastYear: lastM,
            elevThisYear: thisE,
            elevLastYear: lastE,
            pctChangeHikes: pctH,
            pctChangeMiles: pctM
        )
    }

    // MARK: - Seasonal Suggestions

    func seasonalSuggestions() -> [(trail: String, region: String, count: Int)] {
        let cal = Calendar.current
        let currentMonth = cal.component(.month, from: Date())
        let monthHikes = hikes.filter {
            let m = Int($0.date.dropFirst(5).prefix(2)) ?? 0
            return m == currentMonth
        }
        let grouped = Dictionary(grouping: monthHikes, by: \.trailName)
        return grouped.map { (trail: $0.key, region: $0.value[0].region, count: $0.value.count) }
            .sorted { $0.2 > $1.2 }
            .prefix(5)
            .map { $0 }
    }
}

extension Calendar {
    func ordinateDay(in date: Date) -> Int {
        ordinality(of: .day, in: .year, for: date) ?? 0
    }
}
