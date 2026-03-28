import Foundation

struct Hike: Codable, Sendable {
    let id: String
    let date: String
    let distanceMiles: Double
    let elevationGainFt: Double
    let durationMinutes: Int
    let startLat: Double
    let startLon: Double
    let endLat: Double
    let endLon: Double
    let minAltitudeFt: Double
    let maxAltitudeFt: Double
    let trailName: String
    let region: String
    let matchConfidence: String
    let distanceToTrailheadMiles: Double
    let trailID: String?
    let withJulie: Bool?

    enum CodingKeys: String, CodingKey {
        case id, date, region
        case distanceMiles = "distance_miles"
        case elevationGainFt = "elevation_gain_ft"
        case durationMinutes = "duration_minutes"
        case startLat = "start_lat"
        case startLon = "start_lon"
        case endLat = "end_lat"
        case endLon = "end_lon"
        case minAltitudeFt = "min_altitude_ft"
        case maxAltitudeFt = "max_altitude_ft"
        case trailName = "trail_name"
        case matchConfidence = "match_confidence"
        case distanceToTrailheadMiles = "distance_to_trailhead_miles"
        case trailID = "trail_id"
        case withJulie = "with_julie"
    }
}

struct Trail: Codable, Sendable {
    let id: String
    let name: String
    let region: String
    let url: String?
    let trailheadLat: Double
    let trailheadLon: Double
    let distanceMiles: Double?
    let elevationGainFt: Double?
    let difficulty: String?
    let trailDescription: String?
    let dogFriendly: Bool?
    let dogNotes: String?
    let source: String?
    let lovedByShaun: Bool?
    let lovedByJulie: Bool?
    let isWishlist: Bool?
    let notes: String?
    let tags: [String]?
}

struct AppConfig: Sendable {
    let person1: String
    let person2: String
    let homeName: String
    let homeLat: Double
    let homeLon: Double
}

struct HikeRecommendation: Codable, Sendable {
    let trailName: String
    let region: String
    let explanation: String
    let url: String?
    let distanceMiles: Double?
    let elevationGainFt: Double?
    let driveMiles: Double?
    let difficulty: String?
}

struct RecommendationSet: Codable, Sendable {
    let targetDate: String
    let generatedAt: String
    let recommendations: [HikeRecommendation]

    var isExpired: Bool {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let target = fmt.date(from: targetDate) else { return true }
        return target < Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - Data Loading

enum DataLoader {
    static let dataDir: URL = {
        let iCloudDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Hiking", isDirectory: true)
        if FileManager.default.fileExists(atPath: iCloudDir.path) {
            return iCloudDir
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Hiking", isDirectory: true)
    }()

    static func loadConfig() -> AppConfig {
        let configURL = dataDir.appendingPathComponent(".config")
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else {
            return AppConfig(person1: "Person 1", person2: "Person 2", homeName: "Home", homeLat: 47.5, homeLon: -121.8)
        }
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        return AppConfig(
            person1: lines.count > 0 && !lines[0].isEmpty ? lines[0] : "Person 1",
            person2: lines.count > 1 && !lines[1].isEmpty ? lines[1] : "Person 2",
            homeName: lines.count > 2 && !lines[2].isEmpty ? lines[2] : "Home",
            homeLat: lines.count > 3 ? Double(lines[3]) ?? 47.5 : 47.5,
            homeLon: lines.count > 4 ? Double(lines[4]) ?? -121.8 : -121.8
        )
    }

    static func loadRecommendations() -> RecommendationSet? {
        let url = dataDir.appendingPathComponent("recommendations.json")
        guard let data = try? Data(contentsOf: url),
              let set = try? JSONDecoder().decode(RecommendationSet.self, from: data) else { return nil }
        return set
    }

    static func loadHikes() -> [Hike] {
        loadJSON(dataDir.appendingPathComponent("hike_history.json"))
    }

    static func loadTrails() -> [Trail] {
        loadJSON(dataDir.appendingPathComponent("trails.json"))
    }

    private static func loadJSON<T: Decodable>(_ url: URL) -> [T] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }
}

// MARK: - Haversine

func haversineDistanceMiles(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
    let R = 3958.8
    let dLat = (lat2 - lat1) * .pi / 180
    let dLon = (lon2 - lon1) * .pi / 180
    let a = pow(sin(dLat / 2), 2) +
        cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
        pow(sin(dLon / 2), 2)
    return R * 2 * atan2(sqrt(a), sqrt(1 - a))
}

// MARK: - JSON Encoding Helper

func toJSON(_ value: Any) -> String {
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
       let str = String(data: data, encoding: .utf8) {
        return str
    }
    return "{}"
}
