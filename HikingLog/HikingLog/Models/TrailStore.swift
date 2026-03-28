import Foundation
import SwiftUI
import CoreLocation

@Observable
final class TrailStore {
    var trails: [Trail] = []

    static var dataFileURL: URL {
        hikingDataDir.appendingPathComponent("trails.json")
    }

    init() {
        load()
    }

    // MARK: - Persistence

    private func load() {
        let fileURL = Self.dataFileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                trails = try JSONDecoder().decode([Trail].self, from: data)
                trails.sort { $0.name < $1.name }
            } catch {
                print("Failed to load trails: \(error)")
            }
        } else {
            seedFromBundle()
        }
    }

    private func seedFromBundle() {
        guard let url = resourceBundle.url(forResource: "trail_database", withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: url)
            let legacy = try JSONDecoder().decode([LegacyTrail].self, from: data)
            trails = legacy.map { t in
                Trail(
                    id: UUID().uuidString,
                    name: t.name,
                    region: t.region,
                    url: nil,
                    trailheadLat: t.trailheadLat,
                    trailheadLon: t.trailheadLon,
                    distanceMiles: t.distanceMiles,
                    elevationGainFt: Double(t.elevationGainFt),
                    difficulty: t.difficulty,
                    dogFriendly: t.dogFriendly,
                    dogNotes: t.dogNotes,
                    source: "imported"
                )
            }
            trails.sort { $0.name < $1.name }
            save()
        } catch {
            print("Failed to seed trails: \(error)")
        }
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(trails)
            try data.write(to: Self.dataFileURL)
        } catch {
            print("Failed to save trails: \(error)")
        }
    }

    // MARK: - CRUD

    func add(_ trail: Trail) {
        trails.append(trail)
        trails.sort { $0.name < $1.name }
        save()
    }

    func update(_ trail: Trail) {
        if let idx = trails.firstIndex(where: { $0.id == trail.id }) {
            trails[idx] = trail
            save()
        }
    }

    func delete(_ trail: Trail) {
        trails.removeAll { $0.id == trail.id }
        save()
    }

    // MARK: - Lookup

    func trail(byID id: String?) -> Trail? {
        guard let id else { return nil }
        return trails.first { $0.id == id }
    }

    func findClosest(to coordinate: CLLocationCoordinate2D) -> (Trail, Double)? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var best: (Trail, Double)?
        for trail in trails {
            let dist = location.distance(from: trail.location) / 1609.344
            if best == nil || dist < best!.1 {
                best = (trail, dist)
            }
        }
        return best
    }

    // MARK: - URL Import

    func importFromURL(_ urlString: String) async throws -> Trail {
        guard let url = URL(string: urlString) else {
            throw TrailImportError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TrailImportError.fetchFailed
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw TrailImportError.parseError("Could not decode response")
        }

        let host = url.host?.lowercased() ?? ""

        if host.contains("alltrails.com") {
            return parseAllTrails(html: html, url: urlString)
        } else if host.contains("wta.org") {
            return parseWTA(html: html, url: urlString)
        } else {
            throw TrailImportError.unsupportedSite
        }
    }

    // MARK: - AllTrails Parser

    private func parseAllTrails(html: String, url: String) -> Trail {
        var name = ""
        var region = ""
        var description = ""
        var lat = 0.0
        var lon = 0.0
        var distance: Double?
        var elevation: Double?
        var difficulty: String?

        // Try og:title for trail name
        if let ogTitle = extractMeta(from: html, property: "og:title") {
            // AllTrails titles are like "Trail Name - City, State | AllTrails"
            name = ogTitle
                .components(separatedBy: "|").first?
                .trimmingCharacters(in: .whitespaces) ?? ogTitle
            if name.contains(" - ") {
                let parts = name.components(separatedBy: " - ")
                name = parts[0].trimmingCharacters(in: .whitespaces)
                if parts.count > 1 {
                    region = parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // Fallback: title tag
        if name.isEmpty, let title = extractTag(from: html, tag: "title") {
            name = title
                .components(separatedBy: "|").first?
                .components(separatedBy: " - ").first?
                .trimmingCharacters(in: .whitespaces) ?? title
        }

        // Description
        if let ogDesc = extractMeta(from: html, property: "og:description") {
            description = ogDesc
        }

        // Try JSON-LD for structured data
        if let jsonLD = extractJSONLD(from: html) {
            if let n = jsonLD["name"] as? String, name.isEmpty { name = n }
            if let geo = jsonLD["geo"] as? [String: Any] {
                lat = geo["latitude"] as? Double ?? 0
                lon = geo["longitude"] as? Double ?? 0
            }
        }

        // Try to extract coordinates from page content
        if lat == 0, lon == 0 {
            (lat, lon) = extractCoordinates(from: html)
        }

        // Extract stats from meta description or page content
        if let d = extractNumber(from: html, pattern: #"([\d.]+)\s*(?:mi|mile)"#) {
            distance = d
        }
        if let e = extractNumber(from: html, pattern: #"([\d,]+)\s*(?:ft|feet).*?(?:gain|elev)"#) {
            elevation = e
        }
        if difficulty == nil {
            if html.lowercased().contains("\"easy\"") || html.contains("Easy") {
                difficulty = "easy"
            } else if html.lowercased().contains("\"moderate\"") || html.contains("Moderate") {
                difficulty = "moderate"
            } else if html.lowercased().contains("\"hard\"") || html.contains("Hard") {
                difficulty = "hard"
            }
        }

        return Trail(
            id: UUID().uuidString,
            name: name.isEmpty ? "Unknown Trail" : name,
            region: region,
            url: url,
            trailheadLat: lat,
            trailheadLon: lon,
            distanceMiles: distance,
            elevationGainFt: elevation,
            difficulty: difficulty,
            trailDescription: description.isEmpty ? nil : description,
            source: "alltrails"
        )
    }

    // MARK: - WTA Parser

    private func parseWTA(html: String, url: String) -> Trail {
        var name = ""
        var region = ""
        var description = ""
        var lat = 0.0
        var lon = 0.0
        var distance: Double?
        var elevation: Double?
        var difficulty: String?
        var dogFriendly: Bool?

        // Title
        if let ogTitle = extractMeta(from: html, property: "og:title") {
            name = ogTitle.trimmingCharacters(in: .whitespaces)
        }
        if name.isEmpty, let title = extractTag(from: html, tag: "title") {
            name = title
                .components(separatedBy: "|").first?
                .components(separatedBy: " - ").first?
                .trimmingCharacters(in: .whitespaces) ?? title
        }

        // Description
        if let ogDesc = extractMeta(from: html, property: "og:description") {
            description = ogDesc
        }

        // Coordinates
        if lat == 0, lon == 0 {
            (lat, lon) = extractCoordinates(from: html)
        }

        // WTA stats patterns
        if let d = extractNumber(from: html, pattern: #"([\d.]+)\s*miles?\s*(?:roundtrip|round trip|one[ -]way)"#) {
            distance = d
        } else if let d = extractNumber(from: html, pattern: #"Length.*?([\d.]+)\s*mi"#) {
            distance = d
        }

        if let e = extractNumber(from: html, pattern: #"Elevation Gain.*?([\d,]+)\s*ft"#) {
            elevation = e
        } else if let e = extractNumber(from: html, pattern: #"([\d,]+)\s*ft\.?\s*gain"#) {
            elevation = e
        }

        // Region from breadcrumbs or content
        if let r = extractPattern(from: html, pattern: #"region[^>]*>([^<]+)</a>"#) {
            region = r
        }

        // Dog friendly
        if html.contains("Dogs allowed") || html.contains("dogs allowed") {
            dogFriendly = true
        } else if html.contains("Dogs not allowed") || html.contains("dogs not allowed") || html.contains("No dogs") {
            dogFriendly = false
        }

        return Trail(
            id: UUID().uuidString,
            name: name.isEmpty ? "Unknown Trail" : name,
            region: region,
            url: url,
            trailheadLat: lat,
            trailheadLon: lon,
            distanceMiles: distance,
            elevationGainFt: elevation,
            difficulty: difficulty,
            trailDescription: description.isEmpty ? nil : description,
            dogFriendly: dogFriendly,
            source: "wta"
        )
    }

    // MARK: - HTML Parsing Helpers

    private func extractMeta(from html: String, property: String) -> String? {
        // Match both property="" and name=""
        let patterns = [
            #"<meta[^>]*property="\#(property)"[^>]*content="([^"]*)"#,
            #"<meta[^>]*content="([^"]*)"[^>]*property="\#(property)""#,
            #"<meta[^>]*name="\#(property)"[^>]*content="([^"]*)"#
        ]
        for pattern in patterns {
            if let match = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                .firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range]).decodingHTMLEntities()
            }
        }
        return nil
    }

    private func extractTag(from html: String, tag: String) -> String? {
        let pattern = "<\(tag)[^>]*>([^<]*)</\(tag)>"
        if let match = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            .firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range]).decodingHTMLEntities()
        }
        return nil
    }

    private func extractJSONLD(from html: String) -> [String: Any]? {
        let pattern = #"<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        for match in matches {
            if let jsonRange = Range(match.range(at: 1), in: html) {
                let jsonString = String(html[jsonRange])
                if let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return json
                }
                // Sometimes it's an array
                if let data = jsonString.data(using: .utf8),
                   let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let first = array.first {
                    return first
                }
            }
        }
        return nil
    }

    private func extractCoordinates(from html: String) -> (Double, Double) {
        // Try various coordinate patterns
        let patterns = [
            #""latitude":\s*([\d.-]+).*?"longitude":\s*([\d.-]+)"#,
            #"lat["\s:=]+([\d.-]+).*?l(?:ng|on)["\s:=]+([\d.-]+)"#,
            #"center=([\d.-]+)(?:%2C|,)([\d.-]+)"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let latRange = Range(match.range(at: 1), in: html),
               let lonRange = Range(match.range(at: 2), in: html),
               let lat = Double(html[latRange]),
               let lon = Double(html[lonRange]),
               lat > 20 && lat < 70 && lon < -60 && lon > -180 {
                return (lat, lon)
            }
        }
        return (0, 0)
    }

    private func extractNumber(from html: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        let numStr = String(html[range]).replacingOccurrences(of: ",", with: "")
        return Double(numStr)
    }

    private func extractPattern(from html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[range]).decodingHTMLEntities()
    }
}

// MARK: - Legacy Format

private struct LegacyTrail: Codable {
    let name: String
    let region: String
    let trailheadLat: Double
    let trailheadLon: Double
    let distanceMiles: Double
    let elevationGainFt: Int
    let dogFriendly: Bool
    let dogNotes: String?
    let difficulty: String?
    let highlights: String?
    let passRequired: String?
    let distanceFromWestSeattleMiles: Double?

    enum CodingKeys: String, CodingKey {
        case name, region, difficulty, highlights
        case trailheadLat = "trailhead_lat"
        case trailheadLon = "trailhead_lon"
        case distanceMiles = "distance_miles"
        case elevationGainFt = "elevation_gain_ft"
        case dogFriendly = "dog_friendly"
        case dogNotes = "dog_notes"
        case passRequired = "pass_required"
        case distanceFromWestSeattleMiles = "distance_from_west_seattle_miles"
    }
}

// MARK: - Error

enum TrailImportError: LocalizedError {
    case invalidURL
    case fetchFailed
    case parseError(String)
    case unsupportedSite

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .fetchFailed: return "Failed to fetch the page"
        case .parseError(let msg): return "Parse error: \(msg)"
        case .unsupportedSite: return "Only AllTrails and WTA URLs are supported"
        }
    }
}

// MARK: - HTML Entity Decoding

extension String {
    func decodingHTMLEntities() -> String {
        var result = self
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&#x27;", "'"), ("&#x2F;", "/"), ("&nbsp;", " ")
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        return result
    }
}
