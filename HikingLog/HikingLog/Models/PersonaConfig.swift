import Foundation

/// Configurable identities and home location. JSON field names stay fixed
/// (lovedByShaun/lovedByJulie/withJulie) for data compatibility,
/// but all UI labels and prompts use these configurable values.
struct PersonaConfig {
    static var person1: String { load().person1 }
    static var person2: String { load().person2 }
    static var homeName: String { load().homeName }
    static var homeLat: Double { load().homeLat }
    static var homeLon: Double { load().homeLon }

    private struct Config {
        let person1, person2, homeName: String
        let homeLat, homeLon: Double
    }

    private static var configURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Hiking", isDirectory: true)
        return dir.appendingPathComponent(".config")
    }

    private static func load() -> Config {
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else {
            return Config(person1: "Person 1", person2: "Person 2", homeName: "Home", homeLat: 47.553, homeLon: -122.387)
        }
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        return Config(
            person1: lines.count > 0 && !lines[0].isEmpty ? lines[0] : "Person 1",
            person2: lines.count > 1 && !lines[1].isEmpty ? lines[1] : "Person 2",
            homeName: lines.count > 2 && !lines[2].isEmpty ? lines[2] : "Home",
            homeLat: lines.count > 3 ? Double(lines[3]) ?? 47.553 : 47.553,
            homeLon: lines.count > 4 ? Double(lines[4]) ?? -122.387 : -122.387
        )
    }

    static func save(person1: String, person2: String, homeName: String, homeLat: Double, homeLon: Double) {
        let text = "\(person1)\n\(person2)\n\(homeName)\n\(homeLat)\n\(homeLon)"
        try? text.write(to: configURL, atomically: true, encoding: .utf8)
    }

    // Migrate old .persona_names file to new .config format
    static func migrateIfNeeded() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Hiking", isDirectory: true)
        let oldURL = dir.appendingPathComponent(".persona_names")
        if FileManager.default.fileExists(atPath: oldURL.path) && !FileManager.default.fileExists(atPath: configURL.path) {
            if let text = try? String(contentsOf: oldURL, encoding: .utf8) {
                let lines = text.components(separatedBy: "\n")
                let p1 = lines.first ?? "Person 1"
                let p2 = lines.count > 1 ? lines[1] : "Person 2"
                save(person1: p1, person2: p2, homeName: "West Seattle", homeLat: 47.553, homeLon: -122.387)
            }
            try? FileManager.default.removeItem(at: oldURL)
        }
    }
}
