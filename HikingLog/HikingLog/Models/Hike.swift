import Foundation
import CoreLocation

struct Hike: Codable, Identifiable, Hashable {
    var id: String
    var date: String
    var distanceMiles: Double
    var elevationGainFt: Double
    var durationMinutes: Int
    var startLat: Double
    var startLon: Double
    var endLat: Double
    var endLon: Double
    var minAltitudeFt: Double
    var maxAltitudeFt: Double
    var trailName: String
    var region: String
    var matchConfidence: String
    var distanceToTrailheadMiles: Double
    var trailID: String?
    var withJulie: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case date
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
        case region
        case matchConfidence = "match_confidence"
        case distanceToTrailheadMiles = "distance_to_trailhead_miles"
        case trailID = "trail_id"
        case withJulie = "with_julie"
    }

    var pace: Double {
        guard durationMinutes > 0, distanceMiles > 0 else { return 0 }
        return Double(durationMinutes) / distanceMiles
    }

    var parsedDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date) ?? Date.distantPast
    }

    var year: String { String(date.prefix(4)) }

    var yearMonth: String { String(date.prefix(7)) }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: startLat, longitude: startLon)
    }

    var formattedDuration: String {
        let hours = durationMinutes / 60
        let mins = durationMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let d = formatter.date(from: date) else { return date }
        formatter.dateStyle = .medium
        return formatter.string(from: d)
    }
}

struct TrailSummary: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let region: String
    let count: Int
    let avgMiles: Double
    let avgElevation: Int
    let lastHiked: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
