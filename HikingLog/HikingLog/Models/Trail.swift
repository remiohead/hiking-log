import Foundation
import CoreLocation

struct Trail: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var region: String
    var url: String?
    var trailheadLat: Double
    var trailheadLon: Double
    var distanceMiles: Double?
    var elevationGainFt: Double?
    var difficulty: String?
    var trailDescription: String?
    var dogFriendly: Bool?
    var dogNotes: String?
    var source: String?  // "alltrails", "wta", "manual", "imported"
    var lovedByShaun: Bool?
    var lovedByJulie: Bool?
    var isWishlist: Bool?
    var notes: String?
    var tags: [String]?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: trailheadLat, longitude: trailheadLon)
    }

    var location: CLLocation {
        CLLocation(latitude: trailheadLat, longitude: trailheadLon)
    }

    var displayURL: String? {
        guard let url else { return nil }
        return url
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
    }

    static func blank() -> Trail {
        Trail(
            id: UUID().uuidString,
            name: "",
            region: "",
            url: nil,
            trailheadLat: 47.5,
            trailheadLon: -121.8,
            distanceMiles: nil,
            elevationGainFt: nil,
            source: "manual"
        )
    }
}
