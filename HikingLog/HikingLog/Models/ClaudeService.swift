import Foundation

struct HikeRecommendation: Codable, Identifiable {
    var id: UUID = UUID()
    let trailName: String
    let region: String
    let explanation: String
    let url: String?
    let distanceMiles: Double?
    let elevationGainFt: Double?
    let driveMiles: Double?
    let difficulty: String?
}

struct RecommendationSet: Codable {
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

actor ClaudeService {
    static let shared = ClaudeService()

    private static var apiKeyURL: URL {
        hikingLocalDir.appendingPathComponent(".api_key")
    }

    private static var recommendationsURL: URL {
        hikingDataDir.appendingPathComponent("recommendations.json")
    }

    static func loadAPIKey() -> String {
        (try? String(contentsOf: apiKeyURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
    }

    static func saveAPIKey(_ key: String) {
        try? key.trimmingCharacters(in: .whitespacesAndNewlines).write(to: apiKeyURL, atomically: true, encoding: .utf8)
    }

    private static var emailRecipientsURL: URL {
        hikingLocalDir.appendingPathComponent(".email_recipients")
    }

    static func loadEmailRecipients() -> String {
        (try? String(contentsOf: emailRecipientsURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
    }

    static func saveEmailRecipients(_ recipients: String) {
        try? recipients.trimmingCharacters(in: .whitespacesAndNewlines).write(to: emailRecipientsURL, atomically: true, encoding: .utf8)
    }

    static func loadRecommendations() -> RecommendationSet? {
        guard let data = try? Data(contentsOf: recommendationsURL),
              let set = try? JSONDecoder().decode(RecommendationSet.self, from: data) else { return nil }
        return set.isExpired ? nil : set
    }

    static func saveRecommendations(_ set: RecommendationSet) {
        if let data = try? JSONEncoder().encode(set) {
            try? data.write(to: recommendationsURL)
        }
    }

    func generateRecommendations(
        hikes: [Hike],
        trails: [Trail],
        weather: [DayForecast],
        targetDate: String
    ) async throws -> RecommendationSet {
        let apiKey = Self.loadAPIKey()
        guard !apiKey.isEmpty else { throw ClaudeError.noAPIKey }

        let prompt = buildPrompt(hikes: hikes, trails: trails, weather: weather, targetDate: targetDate)

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 16000,
            "thinking": [
                "type": "enabled",
                "budget_tokens": 10000
            ],
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 180
        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.requestFailed("No response")
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.requestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let textBlock = content.first(where: { $0["type"] as? String == "text" }),
              let text = textBlock["text"] as? String else {
            throw ClaudeError.parseError
        }

        let recommendations = parseRecommendations(text)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        let set = RecommendationSet(
            targetDate: targetDate,
            generatedAt: fmt.string(from: Date()),
            recommendations: recommendations
        )
        Self.saveRecommendations(set)
        return set
    }

    // MARK: - Prompt Building

    private func buildPrompt(hikes: [Hike], trails: [Trail], weather: [DayForecast], targetDate: String) -> String {
        let cal = Calendar.current
        let month = cal.component(.month, from: Date())
        let isWinter = month >= 11 || month <= 3
        let maxDrive = isWinter ? 60 : 90
        let season = isWinter ? "winter" : "summer"

        // Summarize hike preferences
        let trailCounts = Dictionary(grouping: hikes, by: \.trailName)
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
        let top10 = trailCounts.prefix(10).map { "\($0.key) (\($0.value)x)" }.joined(separator: ", ")

        let avgDist = hikes.isEmpty ? 0 : hikes.reduce(0.0) { $0 + $1.distanceMiles } / Double(hikes.count)
        let avgElev = hikes.isEmpty ? 0 : hikes.reduce(0.0) { $0 + $1.elevationGainFt } / Double(hikes.count)

        // Recent hikes (last 3 months)
        let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: Date())!
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let recentCutoff = fmt.string(from: threeMonthsAgo)
        let recent = hikes.filter { $0.date >= recentCutoff }
        let recentTrails = recent.map { "\($0.trailName) (\($0.date))" }.joined(separator: ", ")

        // Loved trails
        let p1 = PersonaConfig.person1
        let p2 = PersonaConfig.person2
        let lovedByPerson1 = trails.filter { $0.lovedByShaun == true }.map(\.name).joined(separator: ", ")
        let lovedByPerson2 = trails.filter { $0.lovedByJulie == true }.map(\.name).joined(separator: ", ")

        // Dog-friendly trails with coordinates
        let dogTrails = trails.filter { $0.dogFriendly == true }
        let dogTrailList = dogTrails.map { t in
            var desc = "\(t.name) (region: \(t.region)"
            if let d = t.distanceMiles { desc += ", \(d) mi" }
            if let e = t.elevationGainFt { desc += ", \(Int(e)) ft" }
            if let diff = t.difficulty { desc += ", \(diff)" }
            if let url = t.url { desc += ", \(url)" }
            if let notes = t.notes { desc += ", notes: \(notes)" }
            desc += ")"
            return desc
        }.joined(separator: "\n")

        // All trails for broader suggestions
        let allTrailList = trails.map { t in
            var desc = "\(t.name) (region: \(t.region), dog: \(t.dogFriendly == true ? "yes" : t.dogFriendly == false ? "no" : "unknown")"
            if let d = t.distanceMiles { desc += ", \(d) mi" }
            if let e = t.elevationGainFt { desc += ", \(Int(e)) ft" }
            if let diff = t.difficulty { desc += ", \(diff)" }
            if let url = t.url { desc += ", \(url)" }
            desc += ", lat: \(t.trailheadLat), lon: \(t.trailheadLon)"
            if t.lovedByShaun == true { desc += ", loved by \(p1)" }
            if t.lovedByJulie == true { desc += ", loved by \(p2)" }
            desc += ")"
            return desc
        }.joined(separator: "\n")

        // Weather for target date
        let targetWeather = weather.first { $0.date == targetDate }
        let weatherStr = targetWeather.map {
            "\($0.description), high \(Int($0.tempHighF))°F, low \(Int($0.tempLowF))°F, precip \($0.precipInches)in"
        } ?? "Weather forecast not available"

        // Seasonal patterns for this month
        let monthHikes = hikes.filter { Int($0.date.dropFirst(5).prefix(2)) == month }
        let monthTrails = Dictionary(grouping: monthHikes, by: \.trailName)
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { "\($0.key) (\($0.value)x)" }
            .joined(separator: ", ")

        return """
        You are a hiking recommendation engine for \(p1) and \(p2), a couple based in \(PersonaConfig.homeName) (\(PersonaConfig.homeLat), \(PersonaConfig.homeLon)). They hike with their dog, so ALL recommendations MUST be dog-friendly.

        TARGET DATE: \(targetDate) (this \(season))
        WEATHER FORECAST: \(weatherStr)
        MAX DRIVE DISTANCE: \(maxDrive) miles from \(PersonaConfig.homeName) (it's \(season))

        HIKING PROFILE:
        - Total hikes: \(hikes.count) over \(Set(hikes.map(\.year)).count) years
        - Average distance: \(String(format: "%.1f", avgDist)) miles
        - Average elevation: \(Int(avgElev)) ft
        - Most-hiked trails: \(top10)
        - Trails \(p1) loves: \(lovedByPerson1.isEmpty ? "none marked yet" : lovedByPerson1)
        - Trails \(p2) loves: \(lovedByPerson2.isEmpty ? "none marked yet" : lovedByPerson2)
        - Trails they usually hike in \(DateFormatter().monthSymbols[month - 1]): \(monthTrails.isEmpty ? "no clear pattern" : monthTrails)
        - Recent hikes (last 3 months): \(recentTrails.isEmpty ? "none" : recentTrails)

        THEIR TRAIL DATABASE:
        \(allTrailList)

        Please recommend 3-5 hikes for \(targetDate). Consider:
        1. ONLY dog-friendly trails (or trails where dog status is unknown but likely OK)
        2. Weather appropriateness — if rain/snow is heavy, suggest lower elevation or sheltered trails
        3. Season — in winter, prefer lower elevation trails that are snow-free; in summer, higher elevation is great
        4. Variety — don't just recommend their most-hiked trails, mix in some they haven't done recently or from their wishlist
        5. Drive distance must be within \(maxDrive) miles of West Seattle
        6. Their preference signals — loved trails, frequently hiked regions, typical distance/elevation

        For each recommendation, respond in EXACTLY this JSON format (no other text before or after):
        ```json
        [
          {
            "trailName": "Trail Name",
            "region": "Region",
            "explanation": "2-3 sentence explanation of why this is a good pick for this Saturday",
            "url": "https://alltrails.com/... or https://wta.org/... or null",
            "distanceMiles": 6.5,
            "elevationGainFt": 1500,
            "driveMiles": 45,
            "difficulty": "moderate"
          }
        ]
        ```
        """
    }

    // MARK: - Response Parsing

    private func parseRecommendations(_ text: String) -> [HikeRecommendation] {
        // Log raw response for debugging
        let debugURL = hikingLocalDir.appendingPathComponent("debug_response.txt")
        try? text.write(to: debugURL, atomically: true, encoding: .utf8)
        print("Claude response (\(text.count) chars) written to debug_response.txt")

        // Extract JSON array from response — find matching brackets
        var jsonStr = text
        if let start = text.firstIndex(of: "[") {
            var depth = 0
            var end = start
            for i in text[start...].indices {
                if text[i] == "[" { depth += 1 }
                if text[i] == "]" { depth -= 1 }
                if depth == 0 { end = i; break }
            }
            jsonStr = String(text[start...end])
        }

        guard let data = jsonStr.data(using: .utf8) else {
            print("Failed to convert to data")
            return []
        }

        struct RawRec: Codable {
            let trailName: String
            let region: String
            let explanation: String
            let url: String?
            let distanceMiles: Double?
            let elevationGainFt: Double?
            let driveMiles: Double?
            let difficulty: String?
        }

        do {
            let recs = try JSONDecoder().decode([RawRec].self, from: data)
            print("Parsed \(recs.count) recommendations")
            return recs.map {
                HikeRecommendation(
                    trailName: $0.trailName,
                    region: $0.region,
                    explanation: $0.explanation,
                    url: $0.url,
                    distanceMiles: $0.distanceMiles,
                    elevationGainFt: $0.elevationGainFt,
                    driveMiles: $0.driveMiles,
                    difficulty: $0.difficulty
                )
            }
        } catch {
            print("JSON decode error: \(error)")
            print("Attempted to parse: \(jsonStr.prefix(500))")
            return []
        }
    }

    enum ClaudeError: LocalizedError {
        case noAPIKey
        case requestFailed(String)
        case parseError

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No API key configured. Go to Settings to add your Anthropic API key."
            case .requestFailed(let msg): return "API request failed: \(msg)"
            case .parseError: return "Failed to parse the response"
            }
        }
    }
}
