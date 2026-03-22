import Foundation

struct DayForecast: Identifiable {
    let id = UUID()
    let date: String
    let tempHighF: Double
    let tempLowF: Double
    let precipInches: Double
    let weatherCode: Int

    var icon: String {
        switch weatherCode {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67: return "cloud.rain.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    var description: String {
        switch weatherCode {
        case 0: return "Clear"
        case 1: return "Mostly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63: return "Rain"
        case 65: return "Heavy rain"
        case 66, 67: return "Freezing rain"
        case 71, 73: return "Snow"
        case 75: return "Heavy snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown"
        }
    }

    var dayName: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: date) else { return date }
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInTomorrow(d) { return "Tomorrow" }
        fmt.dateFormat = "EEE"
        return fmt.string(from: d)
    }
}

actor WeatherService {
    static let shared = WeatherService()
    private var cache: [String: (forecast: [DayForecast], fetched: Date)] = [:]

    func forecast(lat: Double, lon: Double) async throws -> [DayForecast] {
        let key = "\(Int(lat * 100)),\(Int(lon * 100))"
        if let cached = cache[key], Date().timeIntervalSince(cached.fetched) < 1800 {
            return cached.forecast
        }

        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,weathercode&temperature_unit=fahrenheit&precipitation_unit=inch&timezone=America/Los_Angeles&forecast_days=7"
        guard let url = URL(string: urlStr) else { throw WeatherError.invalidURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let daily = json["daily"] as? [String: Any],
              let dates = daily["time"] as? [String],
              let highs = daily["temperature_2m_max"] as? [Double],
              let lows = daily["temperature_2m_min"] as? [Double],
              let precip = daily["precipitation_sum"] as? [Double],
              let codes = daily["weathercode"] as? [Int] else {
            throw WeatherError.parseError
        }

        let forecast = zip(dates, zip(highs, zip(lows, zip(precip, codes)))).map { date, rest in
            DayForecast(date: date, tempHighF: rest.0, tempLowF: rest.1.0, precipInches: rest.1.1.0, weatherCode: rest.1.1.1)
        }

        cache[key] = (forecast, Date())
        return forecast
    }

    enum WeatherError: Error {
        case invalidURL, parseError
    }
}
