import Foundation
import CoreLocation

/// Imports hike data from Health Auto Export zip files.
/// Expected zip structure: Hiking-{Type}-{YYYYMMDD_HHMMSS}.{csv|gpx}
/// Types: Route, Walking + Running Distance, Flights Climbed, Heart Rate, Active Energy, etc.
struct HealthAutoExportImporter {
    struct ImportResult {
        let hikes: [Hike]
        let skipped: Int
        let errors: [String]
    }

    /// Import hikes from a Health Auto Export zip file
    static func importFromZip(at url: URL, existingIDs: Set<String>, trailStore: TrailStore) throws -> ImportResult {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Unzip
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", url.path, "-d", tempDir.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ImportError.unzipFailed
        }

        // Find all unique session IDs and their workout type prefix from filenames
        // Files are named like: "{Workout Type}-{Data Type}-{YYYYMMDD_HHMMSS}.csv"
        // e.g. "Hiking-Route-20260321_072757.csv" or "Outdoor Walk-Route-20181120_185612.csv"
        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        var sessionPrefixes: [String: String] = [:] // sessionID -> workout prefix
        for file in files {
            if let (sessionID, prefix) = extractSessionAndPrefix(from: file.lastPathComponent) {
                sessionPrefixes[sessionID] = prefix
            }
        }

        var hikes: [Hike] = []
        var skipped = 0
        var errors: [String] = []

        for sessionID in sessionPrefixes.keys.sorted() {
            if existingIDs.contains(sessionID) {
                skipped += 1
                continue
            }

            let prefix = sessionPrefixes[sessionID]!
            do {
                let hike = try parseSession(sessionID: sessionID, prefix: prefix, directory: tempDir, trailStore: trailStore)
                hikes.append(hike)
            } catch {
                errors.append("Session \(sessionID): \(error.localizedDescription)")
            }
        }

        return ImportResult(hikes: hikes, skipped: skipped, errors: errors)
    }

    /// Extract session ID and workout type prefix from filename
    /// Supports: "Hiking-Route-20260321_072757.csv", "Outdoor Walk-Route-20181120_185612.csv", etc.
    private static func extractSessionAndPrefix(from filename: String) -> (sessionID: String, prefix: String)? {
        let withoutExt = filename.components(separatedBy: ".").first ?? filename
        // Session ID is the last 15 chars: YYYYMMDD_HHMMSS
        guard withoutExt.count > 15 else { return nil }
        let sessionID = String(withoutExt.suffix(15))
        guard sessionID.count == 15,
              sessionID.contains("_"),
              sessionID.first?.isNumber == true else { return nil }

        // Prefix is everything before the data type, e.g. "Hiking" or "Outdoor Walk"
        // Full pattern: "{Prefix}-{DataType}-{SessionID}"
        // Find the prefix by removing "-{SessionID}" from the end, then taking everything before the last "-"
        let beforeSession = String(withoutExt.dropLast(16)) // drop "-YYYYMMDD_HHMMSS"
        let lastDash = beforeSession.lastIndex(of: "-")
        guard let dashIdx = lastDash else { return nil }
        let prefix = String(beforeSession[beforeSession.startIndex..<dashIdx])
        return (sessionID, prefix)
    }

    /// Parse a single hiking session from its CSV files
    private static func parseSession(sessionID: String, prefix: String, directory: URL, trailStore: TrailStore) throws -> Hike {
        // Parse the date from session ID
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        guard let sessionDate = dateFormatter.date(from: sessionID) else {
            throw ImportError.invalidSessionID(sessionID)
        }
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let dateString = dateFmt.string(from: sessionDate)

        // Try to find the route file for coordinates
        let routeCSV = findFile(prefix: prefix, sessionID: sessionID, type: "Route", ext: "csv", in: directory)
        let distanceCSV = findFile(prefix: prefix, sessionID: sessionID, type: "Walking + Running Distance", ext: "csv", in: directory)
        let flightsCSV = findFile(prefix: prefix, sessionID: sessionID, type: "Flights Climbed", ext: "csv", in: directory)

        var startLat = 0.0, startLon = 0.0, endLat = 0.0, endLon = 0.0
        var minAlt = Double.infinity, maxAlt = -Double.infinity
        var totalDistanceMiles = 0.0
        var durationMinutes = 0
        var totalFlights = 0.0

        // Parse route CSV for coordinates and altitude
        if let routeURL = routeCSV {
            let routeData = try parseRouteCSV(at: routeURL)
            if let first = routeData.first {
                startLat = first.lat
                startLon = first.lon
            }
            if let last = routeData.last {
                endLat = last.lat
                endLon = last.lon
            }
            for point in routeData {
                minAlt = min(minAlt, point.altFt)
                maxAlt = max(maxAlt, point.altFt)
            }
            if let firstTime = routeData.first?.timestamp, let lastTime = routeData.last?.timestamp {
                durationMinutes = Int(lastTime.timeIntervalSince(firstTime) / 60)
            }
        }

        if minAlt == .infinity { minAlt = 0 }
        if maxAlt == -.infinity { maxAlt = 0 }

        // Parse distance CSV
        if let distURL = distanceCSV {
            totalDistanceMiles = try parseSumCSV(at: distURL)
        }

        // Parse flights climbed for elevation estimate
        if let flightsURL = flightsCSV {
            totalFlights = try parseSumCSV(at: flightsURL)
        }
        // Approximate: 1 flight ≈ 10 ft, but use altitude difference if available
        let elevationGain: Double
        if maxAlt > minAlt && maxAlt > 0 {
            elevationGain = maxAlt - minAlt
        } else {
            elevationGain = totalFlights * 10.0
        }

        // Match to trail store
        var trailName = "Unknown Trail"
        var region = "Unknown"
        var matchConfidence = "none"
        var distanceToTrailhead = 0.0
        var trailID: String?

        let startCoord = CLLocationCoordinate2D(latitude: startLat, longitude: startLon)
        if startLat != 0 && startLon != 0 {
            if let (trail, dist) = trailStore.findClosest(to: startCoord) {
                trailName = trail.name
                region = trail.region
                trailID = trail.id
                distanceToTrailhead = dist
                if dist <= 0.1 {
                    matchConfidence = "high"
                } else if dist <= 0.5 {
                    matchConfidence = "medium"
                } else {
                    matchConfidence = "low"
                }
            }
        }

        return Hike(
            id: sessionID,
            date: dateString,
            distanceMiles: (totalDistanceMiles * 100).rounded() / 100,
            elevationGainFt: elevationGain.rounded(),
            durationMinutes: durationMinutes,
            startLat: startLat,
            startLon: startLon,
            endLat: endLat,
            endLon: endLon,
            minAltitudeFt: minAlt,
            maxAltitudeFt: maxAlt,
            trailName: trailName,
            region: region,
            matchConfidence: matchConfidence,
            distanceToTrailheadMiles: (distanceToTrailhead * 1000).rounded() / 1000,
            trailID: trailID
        )
    }

    // MARK: - CSV Parsing

    struct RoutePoint {
        let timestamp: Date
        let lat: Double
        let lon: Double
        let altFt: Double
    }

    private static func parseRouteCSV(at url: URL) throws -> [RoutePoint] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [] }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        var points: [RoutePoint] = []
        // Sample every Nth point to keep memory reasonable
        let stride = max(1, (lines.count - 1) / 2000)

        for i in Swift.stride(from: 1, to: lines.count, by: stride) {
            let line = lines[i]
            let cols = line.components(separatedBy: ",")
            guard cols.count >= 4 else { continue }

            guard let timestamp = isoFormatter.date(from: cols[0].trimmingCharacters(in: .whitespaces)),
                  let lat = Double(cols[1].trimmingCharacters(in: .whitespaces)),
                  let lon = Double(cols[2].trimmingCharacters(in: .whitespaces)),
                  let altMeters = Double(cols[3].trimmingCharacters(in: .whitespaces)) else { continue }

            points.append(RoutePoint(
                timestamp: timestamp,
                lat: lat,
                lon: lon,
                altFt: altMeters * 3.28084
            ))
        }

        // Always include the last point for accurate end coordinates and duration
        if let lastLine = lines.last(where: { !$0.isEmpty }), stride > 1 {
            let cols = lastLine.components(separatedBy: ",")
            if cols.count >= 4,
               let timestamp = isoFormatter.date(from: cols[0].trimmingCharacters(in: .whitespaces)),
               let lat = Double(cols[1].trimmingCharacters(in: .whitespaces)),
               let lon = Double(cols[2].trimmingCharacters(in: .whitespaces)),
               let altMeters = Double(cols[3].trimmingCharacters(in: .whitespaces)) {
                if points.last?.timestamp != timestamp {
                    points.append(RoutePoint(timestamp: timestamp, lat: lat, lon: lon, altFt: altMeters * 3.28084))
                }
            }
        }

        return points
    }

    /// Parse a CSV with a numeric value column and return the sum
    private static func parseSumCSV(at url: URL) throws -> Double {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else { return 0 }

        var total = 0.0
        for i in 1..<lines.count {
            let cols = lines[i].components(separatedBy: ",")
            guard cols.count >= 2 else { continue }
            if let val = Double(cols[1].trimmingCharacters(in: .whitespaces)) {
                total += val
            }
        }
        return total
    }

    // MARK: - File Lookup

    private static func findFile(prefix: String, sessionID: String, type: String, ext: String, in directory: URL) -> URL? {
        let filename = "\(prefix)-\(type)-\(sessionID).\(ext)"
        let url = directory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    enum ImportError: LocalizedError {
        case unzipFailed
        case invalidSessionID(String)
        case noRouteData

        var errorDescription: String? {
            switch self {
            case .unzipFailed: return "Failed to unzip the file"
            case .invalidSessionID(let id): return "Invalid session ID: \(id)"
            case .noRouteData: return "No route data found"
            }
        }
    }
}
