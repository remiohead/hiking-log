import Foundation
import MCP
import ServiceLifecycle

// MARK: - Helpers

func textResult(_ json: String) -> CallTool.Result {
    .init(content: [.text(text: json, annotations: nil, _meta: nil)])
}

func errorResult(_ msg: String) -> CallTool.Result {
    .init(content: [.text(text: msg, annotations: nil, _meta: nil)], isError: true)
}

func prop(_ type: String, _ desc: String) -> Value {
    .object(["type": .string(type), "description": .string(desc)])
}

func enumProp(_ desc: String, _ values: [String]) -> Value {
    .object(["type": .string("string"), "description": .string(desc), "enum": .array(values.map { .string($0) })])
}

func schema(_ properties: [String: Value], required: [String] = []) -> Value {
    var obj: [String: Value] = [
        "type": .string("object"),
        "properties": .object(properties),
    ]
    if !required.isEmpty {
        obj["required"] = .array(required.map { .string($0) })
    }
    return .object(obj)
}

// MARK: - Tool Handlers

func handleGetHikeStats(_ params: CallTool.Parameters) -> CallTool.Result {
    let year = params.arguments?["year"]?.stringValue
    let month = params.arguments?["month"]?.stringValue
    let region = params.arguments?["region"]?.stringValue

    var hikes = DataLoader.loadHikes()
    if let year { hikes = hikes.filter { $0.date.hasPrefix(year) } }
    if let month {
        let m = month.count == 1 ? "0\(month)" : month
        hikes = hikes.filter { $0.date.dropFirst(5).prefix(2) == m }
    }
    if let region { hikes = hikes.filter { $0.region == region } }

    let n = max(hikes.count, 1)
    let totalMiles = hikes.reduce(0.0) { $0 + $1.distanceMiles }
    let totalElevation = hikes.reduce(0.0) { $0 + $1.elevationGainFt }
    let totalMinutes = hikes.reduce(0) { $0 + $1.durationMinutes }
    let uniqueTrails = Set(hikes.map(\.trailName)).count
    let regions = Array(Set(hikes.map(\.region))).sorted()
    let years = Array(Set(hikes.map { String($0.date.prefix(4)) })).sorted()

    let result: [String: Any] = [
        "total_hikes": hikes.count,
        "unique_trails": uniqueTrails,
        "total_miles": (totalMiles * 10).rounded() / 10,
        "total_elevation_ft": Int(totalElevation.rounded()),
        "total_duration_hours": (totalMinutes > 0 ? Double(totalMinutes) / 60.0 * 10 : 0).rounded() / 10,
        "avg_miles": (totalMiles / Double(n) * 10).rounded() / 10,
        "avg_elevation_ft": Int((totalElevation / Double(n)).rounded()),
        "avg_duration_minutes": Int((Double(totalMinutes) / Double(n)).rounded()),
        "regions": regions,
        "years": years,
        "date_range": hikes.isEmpty ? [:] : ["first": hikes.last!.date, "last": hikes.first!.date],
    ]
    return textResult(toJSON(result))
}

func handleGetTrailHistory(_ params: CallTool.Parameters) -> CallTool.Result {
    let trailName = params.arguments?["trail_name"]?.stringValue ?? ""
    let q = trailName.lowercased()
    let hikes = DataLoader.loadHikes().filter { $0.trailName.lowercased().contains(q) }
    let trails = DataLoader.loadTrails().filter { $0.name.lowercased().contains(q) }
    let trail = trails.first
    let n = max(hikes.count, 1)

    var trailInfo: [String: Any]? = nil
    if let t = trail {
        trailInfo = [
            "url": t.url as Any,
            "distance_miles": t.distanceMiles as Any,
            "elevation_gain_ft": t.elevationGainFt as Any,
            "difficulty": t.difficulty as Any,
            "dog_friendly": t.dogFriendly as Any,
            "loved_by_shaun": t.lovedByShaun ?? false,
            "loved_by_julie": t.lovedByJulie ?? false,
            "coordinates": ["lat": t.trailheadLat, "lon": t.trailheadLon],
        ]
    }

    let result: [String: Any] = [
        "trail_name": hikes.first?.trailName ?? trailName,
        "region": hikes.first?.region ?? trail?.region ?? "Unknown",
        "trail_info": trailInfo as Any,
        "total_visits": hikes.count,
        "avg_miles": (hikes.reduce(0.0) { $0 + $1.distanceMiles } / Double(n) * 10).rounded() / 10,
        "avg_elevation_ft": Int((hikes.reduce(0.0) { $0 + $1.elevationGainFt } / Double(n)).rounded()),
        "avg_duration_minutes": Int((Double(hikes.reduce(0) { $0 + $1.durationMinutes }) / Double(n)).rounded()),
        "hikes": hikes.map { h -> [String: Any] in
            ["date": h.date, "distance_miles": h.distanceMiles, "elevation_gain_ft": h.elevationGainFt, "duration_minutes": h.durationMinutes]
        },
    ]
    return textResult(toJSON(result))
}

func handleSearchTrails(_ params: CallTool.Parameters) -> CallTool.Result {
    let query = params.arguments?["query"]?.stringValue
    let region = params.arguments?["region"]?.stringValue
    let lovedBy = params.arguments?["loved_by"]?.stringValue
    let isWishlist = params.arguments?["is_wishlist"]?.boolValue
    let maxDist = params.arguments?["max_distance_miles"]?.doubleValue
    let minDist = params.arguments?["min_distance_miles"]?.doubleValue
    let difficulty = params.arguments?["difficulty"]?.stringValue
    let dogFriendly = params.arguments?["dog_friendly"]?.boolValue

    var trails = DataLoader.loadTrails()
    let hikes = DataLoader.loadHikes()
    let hikedNames = Set(hikes.map(\.trailName))
    let hikedIDs = Set(hikes.compactMap(\.trailID))

    if let query { let q = query.lowercased(); trails = trails.filter { $0.name.lowercased().contains(q) || $0.region.lowercased().contains(q) } }
    if let region { trails = trails.filter { $0.region == region } }
    if let difficulty { trails = trails.filter { $0.difficulty == difficulty } }
    if let dogFriendly { trails = trails.filter { $0.dogFriendly == dogFriendly } }
    if let maxDist { trails = trails.filter { ($0.distanceMiles ?? 0) <= maxDist } }
    if let minDist { trails = trails.filter { ($0.distanceMiles ?? 0) >= minDist } }
    if lovedBy == "shaun" { trails = trails.filter { $0.lovedByShaun == true } }
    if lovedBy == "julie" { trails = trails.filter { $0.lovedByJulie == true } }
    if lovedBy == "both" { trails = trails.filter { $0.lovedByShaun == true && $0.lovedByJulie == true } }
    if lovedBy == "either" { trails = trails.filter { $0.lovedByShaun == true || $0.lovedByJulie == true } }
    if isWishlist == true { trails = trails.filter { !hikedNames.contains($0.name) && !hikedIDs.contains($0.id) } }
    if isWishlist == false { trails = trails.filter { hikedNames.contains($0.name) || hikedIDs.contains($0.id) } }

    let result: [String: Any] = [
        "count": trails.count,
        "trails": trails.map { t -> [String: Any] in
            [
                "name": t.name, "region": t.region, "url": t.url as Any,
                "distance_miles": t.distanceMiles as Any, "elevation_gain_ft": t.elevationGainFt as Any,
                "difficulty": t.difficulty as Any, "dog_friendly": t.dogFriendly as Any,
                "loved_by_shaun": t.lovedByShaun ?? false, "loved_by_julie": t.lovedByJulie ?? false,
                "is_wishlist": !hikedNames.contains(t.name) && !hikedIDs.contains(t.id),
                "coordinates": ["lat": t.trailheadLat, "lon": t.trailheadLon],
                "hike_count": hikes.filter({ $0.trailName == t.name || $0.trailID == t.id }).count,
            ]
        },
    ]
    return textResult(toJSON(result))
}

func handleFindTrailsNear(_ params: CallTool.Parameters) -> CallTool.Result {
    var lat = params.arguments?["lat"]?.doubleValue
    var lon = params.arguments?["lon"]?.doubleValue
    let nearTrail = params.arguments?["near_trail"]?.stringValue
    let radiusMiles = params.arguments?["radius_miles"]?.doubleValue ?? 15

    let trails = DataLoader.loadTrails()

    if let nearTrail, lat == nil || lon == nil {
        if let ref = trails.first(where: { $0.name.lowercased().contains(nearTrail.lowercased()) }) {
            lat = ref.trailheadLat; lon = ref.trailheadLon
        }
    }
    guard let lat, let lon else {
        return textResult("Please provide coordinates or a trail name")
    }

    let hikes = DataLoader.loadHikes()
    let nearby = trails.map { t -> [String: Any] in
        [
            "name": t.name, "region": t.region,
            "distance_from_point_miles": (haversineDistanceMiles(lat, lon, t.trailheadLat, t.trailheadLon) * 100).rounded() / 100,
            "trail_distance_miles": t.distanceMiles as Any, "elevation_gain_ft": t.elevationGainFt as Any,
            "difficulty": t.difficulty as Any, "url": t.url as Any,
            "dog_friendly": t.dogFriendly as Any,
            "loved_by_shaun": t.lovedByShaun ?? false, "loved_by_julie": t.lovedByJulie ?? false,
            "coordinates": ["lat": t.trailheadLat, "lon": t.trailheadLon],
            "hike_count": hikes.filter({ $0.trailName == t.name || $0.trailID == t.id }).count,
        ]
    }
    .filter { ($0["distance_from_point_miles"] as! Double) <= radiusMiles }
    .sorted { ($0["distance_from_point_miles"] as! Double) < ($1["distance_from_point_miles"] as! Double) }

    let result: [String: Any] = ["center": ["lat": lat, "lon": lon], "radius_miles": radiusMiles, "count": nearby.count, "trails": nearby]
    return textResult(toJSON(result))
}

func handleGetHikingPatterns(_ params: CallTool.Parameters) -> CallTool.Result {
    let trailName = params.arguments?["trail_name"]?.stringValue

    var hikes = DataLoader.loadHikes()
    if let trailName { let q = trailName.lowercased(); hikes = hikes.filter { $0.trailName.lowercased().contains(q) } }

    var monthly: [String: Int] = [:]
    for h in hikes { let m = String(h.date.dropFirst(5).prefix(2)); monthly[m, default: 0] += 1 }

    var yearly: [String: [String: Any]] = [:]
    for h in hikes {
        let y = String(h.date.prefix(4))
        var entry = yearly[y] ?? ["count": 0, "miles": 0.0, "elevation": 0.0]
        entry["count"] = (entry["count"] as! Int) + 1
        entry["miles"] = (entry["miles"] as! Double) + h.distanceMiles
        entry["elevation"] = (entry["elevation"] as! Double) + h.elevationGainFt
        yearly[y] = entry
    }

    var trailCounts: [String: Int] = [:]
    for h in hikes { trailCounts[h.trailName, default: 0] += 1 }
    let topTrails = trailCounts.sorted { $0.value > $1.value }.prefix(10).map { ["name": $0.key, "count": $0.value] as [String: Any] }

    let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    let cal = Calendar(identifier: .gregorian)
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.timeZone = TimeZone(identifier: "America/Los_Angeles")
    var dayOfWeek: [String: Int] = [:]
    for h in hikes {
        if let d = df.date(from: h.date) {
            let weekday = cal.component(.weekday, from: d) - 1
            dayOfWeek[dayNames[weekday], default: 0] += 1
        }
    }

    let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    var monthlyNamed: [String: Int] = [:]
    for (m, c) in monthly { if let idx = Int(m) { monthlyNamed[monthNames[idx - 1]] = c } }

    let longest = hikes.max(by: { $0.distanceMiles < $1.distanceMiles })
    let mostElevation = hikes.max(by: { $0.elevationGainFt < $1.elevationGainFt })

    let result: [String: Any] = [
        "total_hikes": hikes.count,
        "monthly_distribution": monthlyNamed,
        "yearly_stats": yearly,
        "day_of_week": dayOfWeek,
        "top_trails": topTrails,
        "longest_hike": longest.map { ["date": $0.date, "trail_name": $0.trailName, "distance_miles": $0.distanceMiles, "elevation_gain_ft": $0.elevationGainFt, "duration_minutes": $0.durationMinutes] as [String: Any] } as Any,
        "most_elevation": mostElevation.map { ["date": $0.date, "trail_name": $0.trailName, "distance_miles": $0.distanceMiles, "elevation_gain_ft": $0.elevationGainFt, "duration_minutes": $0.durationMinutes] as [String: Any] } as Any,
    ]
    return textResult(toJSON(result))
}

func handleGetRecommendations(_ params: CallTool.Parameters) -> CallTool.Result {
    let forPerson = params.arguments?["for_person"]?.stringValue
    let maxDist = params.arguments?["max_distance_miles"]?.doubleValue
    let minDist = params.arguments?["min_distance_miles"]?.doubleValue
    let maxDrive = params.arguments?["max_drive_miles"]?.doubleValue
    let difficulty = params.arguments?["difficulty"]?.stringValue
    let dogFriendly = params.arguments?["dog_friendly"]?.boolValue
    let includeWishlist = params.arguments?["include_wishlist"]?.boolValue ?? true
    let includeHiked = params.arguments?["include_hiked"]?.boolValue ?? true

    var trails = DataLoader.loadTrails()
    let hikes = DataLoader.loadHikes()
    let hikedNames = Set(hikes.map(\.trailName))
    let hikedIDs = Set(hikes.compactMap(\.trailID))
    let cfg = DataLoader.loadConfig()

    if let difficulty { trails = trails.filter { $0.difficulty == difficulty } }
    if let dogFriendly, dogFriendly { trails = trails.filter { $0.dogFriendly == true } }
    if let maxDist { trails = trails.filter { $0.distanceMiles == nil || $0.distanceMiles! <= maxDist } }
    if let minDist { trails = trails.filter { $0.distanceMiles == nil || $0.distanceMiles! >= minDist } }

    struct ScoredTrail {
        let trail: Trail
        let isHiked: Bool
        let driveDist: Double
        let hikeCount: Int
    }

    var scored = trails.map { t -> ScoredTrail in
        let isHiked = hikedNames.contains(t.name) || hikedIDs.contains(t.id)
        let drive = haversineDistanceMiles(cfg.homeLat, cfg.homeLon, t.trailheadLat, t.trailheadLon)
        let count = hikes.filter { $0.trailName == t.name || $0.trailID == t.id }.count
        return ScoredTrail(trail: t, isHiked: isHiked, driveDist: (drive * 10).rounded() / 10, hikeCount: count)
    }

    if let maxDrive { scored = scored.filter { $0.driveDist <= maxDrive } }
    if !includeWishlist { scored = scored.filter { $0.isHiked } }
    if !includeHiked { scored = scored.filter { !$0.isHiked } }

    if forPerson == "shaun" { scored = scored.filter { $0.trail.lovedByShaun == true || !$0.isHiked } }
    if forPerson == "julie" { scored = scored.filter { $0.trail.lovedByJulie == true || !$0.isHiked } }
    if forPerson == "both" { scored = scored.filter { ($0.trail.lovedByShaun == true && $0.trail.lovedByJulie == true) || !$0.isHiked } }

    scored.sort { a, b in
        let aLoved = (a.trail.lovedByShaun == true ? 1 : 0) + (a.trail.lovedByJulie == true ? 1 : 0)
        let bLoved = (b.trail.lovedByShaun == true ? 1 : 0) + (b.trail.lovedByJulie == true ? 1 : 0)
        if aLoved != bLoved { return aLoved > bLoved }
        if a.isHiked != b.isHiked { return !a.isHiked }
        return a.driveDist < b.driveDist
    }

    let recommendations = scored.prefix(20).map { s -> [String: Any] in
        [
            "name": s.trail.name, "region": s.trail.region, "url": s.trail.url as Any,
            "distance_miles": s.trail.distanceMiles as Any, "elevation_gain_ft": s.trail.elevationGainFt as Any,
            "difficulty": s.trail.difficulty as Any, "dog_friendly": s.trail.dogFriendly as Any,
            "loved_by_shaun": s.trail.lovedByShaun ?? false, "loved_by_julie": s.trail.lovedByJulie ?? false,
            "is_wishlist": !s.isHiked, "drive_distance_miles": s.driveDist, "times_hiked": s.hikeCount,
            "coordinates": ["lat": s.trail.trailheadLat, "lon": s.trail.trailheadLon],
        ]
    }

    let result: [String: Any] = ["count": scored.count, "recommendations": Array(recommendations)]
    return textResult(toJSON(result))
}

func handleGetAllRegions(_ params: CallTool.Parameters) -> CallTool.Result {
    let trails = DataLoader.loadTrails()
    let hikes = DataLoader.loadHikes()
    var regions: [String: [String: Int]] = [:]
    for t in trails { regions[t.region, default: ["trails": 0, "hikes": 0]]["trails"]! += 1 }
    for h in hikes { regions[h.region, default: ["trails": 0, "hikes": 0]]["hikes"]! += 1 }

    let result = regions.map { ["name": $0.key, "trails": $0.value["trails"]!, "hikes": $0.value["hikes"]!] as [String: Any] }
        .sorted { ($0["hikes"] as! Int) > ($1["hikes"] as! Int) }
    return textResult(toJSON(result))
}

func handleGetAllHikes(_ params: CallTool.Parameters) -> CallTool.Result {
    let year = params.arguments?["year"]?.stringValue
    let month = params.arguments?["month"]?.stringValue
    let region = params.arguments?["region"]?.stringValue
    let dateFrom = params.arguments?["date_from"]?.stringValue
    let dateTo = params.arguments?["date_to"]?.stringValue
    let trailName = params.arguments?["trail_name"]?.stringValue

    var hikes = DataLoader.loadHikes()
    if let year { hikes = hikes.filter { $0.date.hasPrefix(year) } }
    if let month {
        let m = month.count == 1 ? "0\(month)" : month
        hikes = hikes.filter { $0.date.dropFirst(5).prefix(2) == m }
    }
    if let region { hikes = hikes.filter { $0.region == region } }
    if let dateFrom { hikes = hikes.filter { $0.date >= dateFrom } }
    if let dateTo { hikes = hikes.filter { $0.date <= dateTo } }
    if let trailName { let q = trailName.lowercased(); hikes = hikes.filter { $0.trailName.lowercased().contains(q) } }

    let result: [String: Any] = [
        "count": hikes.count,
        "hikes": hikes.map { h -> [String: Any] in
            ["date": h.date, "trail_name": h.trailName, "region": h.region,
             "distance_miles": h.distanceMiles, "elevation_gain_ft": h.elevationGainFt, "duration_minutes": h.durationMinutes]
        },
    ]
    return textResult(toJSON(result))
}

func handleGetMonthlyStats(_ params: CallTool.Parameters) -> CallTool.Result {
    let year = params.arguments?["year"]?.stringValue

    var hikes = DataLoader.loadHikes()
    if let year { hikes = hikes.filter { $0.date.hasPrefix(year) } }

    var months: [String: (hikes: Int, miles: Double, elevation: Double, minutes: Int, trails: Set<String>, regions: Set<String>)] = [:]
    for h in hikes {
        let key = String(h.date.prefix(7))
        var m = months[key] ?? (0, 0, 0, 0, Set(), Set())
        m.hikes += 1; m.miles += h.distanceMiles; m.elevation += h.elevationGainFt
        m.minutes += h.durationMinutes; m.trails.insert(h.trailName); m.regions.insert(h.region)
        months[key] = m
    }

    let result = months.sorted { $0.key < $1.key }.map { (month, m) -> [String: Any] in
        ["month": month, "hikes": m.hikes, "miles": (m.miles * 10).rounded() / 10,
         "elevation_ft": Int(m.elevation.rounded()), "duration_hours": (Double(m.minutes) / 60.0 * 10).rounded() / 10,
         "unique_trails": m.trails.count, "unique_regions": m.regions.count]
    }
    return textResult(toJSON(["count": result.count, "months": result] as [String: Any]))
}

func handleGetStreaks(_ params: CallTool.Parameters) -> CallTool.Result {
    let hikes = DataLoader.loadHikes()
    guard !hikes.isEmpty else {
        return textResult("{\"error\": \"No hikes found\"}")
    }

    let dates = Array(Set(hikes.map(\.date))).sorted()
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.timeZone = TimeZone(identifier: "America/Los_Angeles")
    let cal = Calendar(identifier: .gregorian)
    let hikeDateSet = Set(dates)

    guard let firstDate = df.date(from: dates[0]) else {
        return textResult("{\"error\": \"Invalid date\"}")
    }

    // Find nearest Saturday on or before the first hike
    var startSat = firstDate
    let weekday = cal.component(.weekday, from: startSat)
    let daysToSat = (weekday == 7) ? 0 : (7 - weekday)
    startSat = cal.date(byAdding: .day, value: daysToSat, to: startSat)!
    if startSat > firstDate {
        startSat = cal.date(byAdding: .day, value: -7, to: startSat)!
    }

    let today = Date()
    var allSaturdays: [(date: String, hiked: Bool)] = []
    var current = startSat
    while current <= today {
        let ds = df.string(from: current)
        allSaturdays.append((ds, hikeDateSet.contains(ds)))
        current = cal.date(byAdding: .day, value: 7, to: current)!
    }

    // Saturday streaks
    var longestStreak = 0, longestStart = "", longestEnd = ""
    var tempStreak = 0, streakStart = ""
    for sat in allSaturdays {
        if sat.hiked {
            tempStreak += 1
            if tempStreak == 1 { streakStart = sat.date }
            if tempStreak > longestStreak {
                longestStreak = tempStreak; longestStart = streakStart; longestEnd = sat.date
            }
        } else { tempStreak = 0 }
    }

    // Current streak backwards
    var currentStreak = 0, currentStreakStart = ""
    for i in stride(from: allSaturdays.count - 1, through: 0, by: -1) {
        if allSaturdays[i].hiked {
            currentStreak += 1; currentStreakStart = allSaturdays[i].date
        } else { break }
    }

    // Longest gap
    var longestGapDays = 0, gapFrom = "", gapTo = ""
    for i in 1..<dates.count {
        if let d1 = df.date(from: dates[i - 1]), let d2 = df.date(from: dates[i]) {
            let gap = cal.dateComponents([.day], from: d1, to: d2).day ?? 0
            if gap > longestGapDays { longestGapDays = gap; gapFrom = dates[i - 1]; gapTo = dates[i] }
        }
    }

    // Weekly streaks
    let hikeWeeks = Set(dates.compactMap { dateStr -> String? in
        guard let d = df.date(from: dateStr) else { return nil }
        let year = cal.component(.yearForWeekOfYear, from: d)
        let week = cal.component(.weekOfYear, from: d)
        return "\(year)-W\(String(format: "%02d", week))"
    })
    let sortedWeeks = hikeWeeks.sorted()
    var weekStreak = 0, longestWeekStreak = 0
    for i in 0..<sortedWeeks.count {
        if i == 0 { weekStreak = 1 } else {
            let prev = sortedWeeks[i - 1].split(separator: "-W").map { Int($0) ?? 0 }
            let cur = sortedWeeks[i].split(separator: "-W").map { Int($0) ?? 0 }
            let isConsecutive = (cur[0] == prev[0] && cur[1] == prev[1] + 1) ||
                (cur[0] == prev[0] + 1 && prev[1] >= 51 && cur[1] == 1)
            weekStreak = isConsecutive ? weekStreak + 1 : 1
        }
        longestWeekStreak = max(longestWeekStreak, weekStreak)
    }

    let saturdaysHiked = allSaturdays.filter(\.hiked).count
    let totalSaturdays = allSaturdays.count

    let result: [String: Any] = [
        "saturday_streaks": [
            "current_streak": currentStreak,
            "current_streak_start": currentStreakStart.isEmpty ? NSNull() : currentStreakStart as Any,
            "longest_streak": longestStreak,
            "longest_streak_period": ["from": longestStart, "to": longestEnd],
            "saturdays_hiked": saturdaysHiked,
            "total_saturdays": totalSaturdays,
            "saturday_hike_rate": "\(((Double(saturdaysHiked) / Double(totalSaturdays)) * 1000).rounded() / 10)%",
        ] as [String: Any],
        "weekly_streaks": ["longest_consecutive_weeks": longestWeekStreak],
        "gaps": [
            "longest_gap_days": longestGapDays,
            "longest_gap_period": ["from": gapFrom, "to": gapTo],
        ] as [String: Any],
        "total_unique_hike_days": dates.count,
        "date_range": ["first": dates[0], "last": dates[dates.count - 1]],
    ]
    return textResult(toJSON(result))
}

func handleGetWeeklyRecommendations(_ params: CallTool.Parameters) -> CallTool.Result {
    guard let recSet = DataLoader.loadRecommendations() else {
        return textResult(toJSON(["status": "none", "message": "No current recommendations generated. Recommendations are generated from the Hiking app."] as [String: Any]))
    }

    if recSet.isExpired {
        return textResult(toJSON(["status": "expired", "target_date": recSet.targetDate, "generated_at": recSet.generatedAt,
                                  "message": "Recommendations have expired (target date has passed)."] as [String: Any]))
    }

    let result: [String: Any] = [
        "status": "current",
        "target_date": recSet.targetDate,
        "generated_at": recSet.generatedAt,
        "count": recSet.recommendations.count,
        "recommendations": recSet.recommendations.map { r -> [String: Any] in
            [
                "trail_name": r.trailName, "region": r.region, "explanation": r.explanation,
                "url": r.url as Any, "distance_miles": r.distanceMiles as Any,
                "elevation_gain_ft": r.elevationGainFt as Any, "drive_miles": r.driveMiles as Any,
                "difficulty": r.difficulty as Any,
            ]
        },
    ]
    return textResult(toJSON(result))
}

// MARK: - Server Setup

let server = Server(
    name: "hiking",
    version: "1.0.0",
    capabilities: .init(
        resources: .init(subscribe: false, listChanged: false),
        tools: .init(listChanged: false)
    )
)

// Register tool list
await server.withMethodHandler(ListTools.self) { _ in
    .init(tools: [
        Tool(name: "get_hike_stats", description: "Get overall hiking statistics, optionally filtered by year or region",
             inputSchema: schema(["year": prop("string", "Filter by year (e.g. '2024')"), "month": prop("string", "Filter by month (e.g. '10' for October)"), "region": prop("string", "Filter by region")])),
        Tool(name: "get_trail_history", description: "Get all hikes for a specific trail, with stats",
             inputSchema: schema(["trail_name": prop("string", "Trail name to look up")], required: ["trail_name"])),
        Tool(name: "search_trails", description: "Search trails by name, region, or attributes",
             inputSchema: schema(["query": prop("string", "Search by name"), "region": prop("string", "Filter by region"),
                                  "loved_by": enumProp("Filter by who loved: shaun, julie, both, either", ["shaun", "julie", "both", "either"]),
                                  "is_wishlist": prop("boolean", "True for un-hiked trails, false for hiked"),
                                  "max_distance_miles": prop("number", "Max trail distance in miles"), "min_distance_miles": prop("number", "Min trail distance in miles"),
                                  "difficulty": prop("string", "Filter by difficulty: easy, moderate, hard"), "dog_friendly": prop("boolean", "Filter by dog-friendliness")])),
        Tool(name: "find_trails_near", description: "Find trails near a coordinate or another trail",
             inputSchema: schema(["lat": prop("number", "Latitude"), "lon": prop("number", "Longitude"),
                                  "near_trail": prop("string", "Find trails near this trail name"), "radius_miles": prop("number", "Search radius in miles (default 15)")])),
        Tool(name: "get_hiking_patterns", description: "Analyze hiking patterns — frequency, seasonal trends, progression over time",
             inputSchema: schema(["trail_name": prop("string", "Analyze patterns for a specific trail")])),
        Tool(name: "get_recommendations", description: "Get trail recommendations based on preferences and history",
             inputSchema: schema(["for_person": enumProp("Who is the recommendation for", ["shaun", "julie", "both"]),
                                  "max_distance_miles": prop("number", "Max trail distance"), "min_distance_miles": prop("number", "Min trail distance"),
                                  "max_drive_miles": prop("number", "Max drive distance from home"), "difficulty": prop("string", "Preferred difficulty"),
                                  "dog_friendly": prop("boolean", "Must be dog-friendly"), "include_wishlist": prop("boolean", "Include un-hiked trails (default true)"),
                                  "include_hiked": prop("boolean", "Include previously hiked trails (default true)")])),
        Tool(name: "get_all_regions", description: "List all regions with trail and hike counts",
             inputSchema: schema([:])),
        Tool(name: "get_all_hikes", description: "Get every individual hike record with optional filters — ideal for time-based analysis",
             inputSchema: schema(["year": prop("string", "Filter by year (e.g. '2024')"), "month": prop("string", "Filter by month (e.g. '10' for October)"),
                                  "region": prop("string", "Filter by region"), "date_from": prop("string", "Start date inclusive (YYYY-MM-DD)"),
                                  "date_to": prop("string", "End date inclusive (YYYY-MM-DD)"), "trail_name": prop("string", "Filter by trail name (partial match)")])),
        Tool(name: "get_monthly_stats", description: "Get aggregated hiking stats broken down by month — great for leaderboards and comparisons",
             inputSchema: schema(["year": prop("string", "Filter to a specific year (e.g. '2022')")])),
        Tool(name: "get_streaks", description: "Track hiking streaks — consecutive Saturdays hiked, longest gaps, current streak",
             inputSchema: schema([:])),
        Tool(name: "get_weekly_recommendations", description: "Get this week's generated trail recommendations (from the Hiking app), if available",
             inputSchema: schema([:])),
    ])
}

// Register tool call handler
await server.withMethodHandler(CallTool.self) { params in
    switch params.name {
    case "get_hike_stats": return handleGetHikeStats(params)
    case "get_trail_history": return handleGetTrailHistory(params)
    case "search_trails": return handleSearchTrails(params)
    case "find_trails_near": return handleFindTrailsNear(params)
    case "get_hiking_patterns": return handleGetHikingPatterns(params)
    case "get_recommendations": return handleGetRecommendations(params)
    case "get_all_regions": return handleGetAllRegions(params)
    case "get_all_hikes": return handleGetAllHikes(params)
    case "get_monthly_stats": return handleGetMonthlyStats(params)
    case "get_streaks": return handleGetStreaks(params)
    case "get_weekly_recommendations": return handleGetWeeklyRecommendations(params)
    default: return errorResult("Unknown tool: \(params.name)")
    }
}

// Register resources
await server.withMethodHandler(ListResources.self) { _ in
    .init(resources: [
        Resource(name: "Hike History", uri: "hiking://hikes", description: "All hike records", mimeType: "application/json"),
        Resource(name: "Trail Database", uri: "hiking://trails", description: "All trail data", mimeType: "application/json"),
    ])
}

await server.withMethodHandler(ReadResource.self) { params in
    switch params.uri {
    case "hiking://hikes":
        let hikes = DataLoader.loadHikes()
        let data = try JSONEncoder().encode(hikes)
        return .init(contents: [.text(String(data: data, encoding: .utf8) ?? "[]", uri: params.uri, mimeType: "application/json")])
    case "hiking://trails":
        let trails = DataLoader.loadTrails()
        let data = try JSONEncoder().encode(trails)
        return .init(contents: [.text(String(data: data, encoding: .utf8) ?? "[]", uri: params.uri, mimeType: "application/json")])
    default:
        throw MCPError.invalidParams("Unknown resource: \(params.uri)")
    }
}

// Start server with stdio transport
let transport = StdioTransport()
try await server.start(transport: transport)

// Keep running
try await Task.sleep(for: .seconds(365 * 24 * 3600))
