import SwiftUI

struct RecommendationsView: View {
    @Environment(HikeStore.self) private var store
    @Environment(TrailStore.self) private var trailStore
    @State private var recommendations: RecommendationSet?
    @State private var isGenerating = false
    @State private var error: String?
    @State private var showingSettings = false

    private var nextSaturday: (date: String, display: String) {
        let cal = Calendar.current
        var date = Date()
        // Find next Saturday
        while cal.component(.weekday, from: date) != 7 {
            date = cal.date(byAdding: .day, value: 1, to: date)!
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let dateStr = fmt.string(from: date)
        fmt.dateStyle = .full
        return (dateStr, fmt.string(from: date))
    }

    private var hasAPIKey: Bool {
        !ClaudeService.loadAPIKey().isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundStyle(.purple)
                    Text("Recommendations")
                        .font(.largeTitle.bold())
                    Spacer()

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }

                    Button {
                        generate()
                    } label: {
                        if isGenerating {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.horizontal, 4)
                        } else {
                            Label("Generate", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(isGenerating || !hasAPIKey)
                }

                // Target date
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text("For: **\(nextSaturday.display)**")

                    let month = Calendar.current.component(.month, from: Date())
                    let isWinter = month >= 11 || month <= 3
                    Text("(\(isWinter ? "winter" : "summer") range: \(isWinter ? "60" : "90") mi)")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)

                if !hasAPIKey {
                    GroupBox {
                        VStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("API Key Required")
                                .font(.headline)
                            Text("Add your Anthropic API key in Settings to enable Claude-powered recommendations.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Open Settings") {
                                showingSettings = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }

                if let error {
                    GroupBox {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .foregroundStyle(.red)
                        }
                        .font(.callout)
                    }
                }

                if let recs = recommendations {
                    HStack {
                        Text("Generated \(recs.generatedAt)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()

                        Button {
                            emailRecommendations(recs)
                        } label: {
                            Label("Email Us", systemImage: "envelope")
                        }
                        .controlSize(.small)

                        Text("for \(recs.targetDate)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    ForEach(recs.recommendations) { rec in
                        RecommendationCard(rec: rec)
                    }
                } else if hasAPIKey && !isGenerating {
                    VStack(spacing: 12) {
                        Image(systemName: "mountain.2.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No recommendations yet")
                            .foregroundStyle(.secondary)
                        Text("Click Generate to get personalized trail suggestions for this Saturday")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding()
        }
        .onAppear {
            recommendations = ClaudeService.loadRecommendations()
        }
        .sheet(isPresented: $showingSettings) {
            APIKeySettingsView()
        }
    }

    private func emailRecommendations(_ recs: RecommendationSet) {
        var body = "Hiking Recommendations for \(recs.targetDate)\n\n"
        for (i, rec) in recs.recommendations.enumerated() {
            body += "\(i + 1). \(rec.trailName) (\(rec.region))\n"
            if let d = rec.distanceMiles { body += "   Distance: \(String(format: "%.1f", d)) mi" }
            if let e = rec.elevationGainFt { body += " | Elevation: \(Int(e)) ft" }
            if let d = rec.driveMiles { body += " | Drive: \(String(format: "%.0f", d)) mi" }
            if let diff = rec.difficulty { body += " | \(diff.capitalized)" }
            body += "\n   \(rec.explanation)\n"
            if let url = rec.url { body += "   \(url)\n" }
            body += "\n"
        }

        let subject = "Hiking This Saturday - \(recs.targetDate)"
        let to = ClaudeService.loadEmailRecipients()
        guard !to.isEmpty else { return }
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        if let url = URL(string: "mailto:\(to)?subject=\(encodedSubject)&body=\(encodedBody)") {
            openURL(url)
        }
    }

    private func generate() {
        isGenerating = true
        error = nil

        Task {
            do {
                // Fetch weather for the general hiking area
                let weather = try await WeatherService.shared.forecast(lat: 47.5, lon: -121.8)

                let result = try await ClaudeService.shared.generateRecommendations(
                    hikes: store.hikes,
                    trails: trailStore.trails,
                    weather: weather,
                    targetDate: nextSaturday.date
                )

                await MainActor.run {
                    recommendations = result
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let rec: HikeRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rec.trailName)
                        .font(.title3.bold())
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(HikeStore.color(for: rec.region))
                                .frame(width: 8, height: 8)
                            Text(rec.region)
                        }
                        if let diff = rec.difficulty {
                            Text(diff.capitalized)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.purple.opacity(0.15))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()

                if let url = rec.url, let link = URL(string: url) {
                    Button {
                        openURL(link)
                    } label: {
                        Label("View Trail", systemImage: "safari")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Text(rec.explanation)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                if let d = rec.distanceMiles {
                    Label(String(format: "%.1f mi", d), systemImage: "arrow.right")
                        .foregroundStyle(.green)
                }
                if let e = rec.elevationGainFt {
                    Label("\(Int(e).formatted()) ft", systemImage: "arrow.up")
                        .foregroundStyle(.blue)
                }
                if let d = rec.driveMiles {
                    Label(String(format: "%.0f mi drive", d), systemImage: "car")
                        .foregroundStyle(.orange)
                }
            }
            .font(.callout)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.secondary)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.purple.opacity(0.06))
                        .padding(8)
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - API Key Settings

struct APIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var emailRecipients: String = ""
    @State private var person1: String = ""
    @State private var person2: String = ""
    @State private var homeName: String = ""
    @State private var homeLatText: String = ""
    @State private var homeLonText: String = ""
    @State private var showKey = false

    var body: some View {
        VStack(spacing: 0) {
            Text("Anthropic API Settings")
                .font(.title2.bold())
                .padding()

            Form {
                Section("API Key") {
                    HStack {
                        if showKey {
                            TextField("sk-ant-...", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("sk-ant-...", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button(showKey ? "Hide" : "Show") {
                            showKey.toggle()
                        }
                        .controlSize(.small)
                    }
                    Text("Get your key at console.anthropic.com")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Hiker Names") {
                    TextField("Person 1", text: $person1)
                        .textFieldStyle(.roundedBorder)
                    TextField("Person 2", text: $person2)
                        .textFieldStyle(.roundedBorder)
                    Text("Display names for the two hikers (used in UI and recommendations)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Home Location") {
                    TextField("Location name", text: $homeName)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        TextField("Latitude", text: $homeLatText)
                            .textFieldStyle(.roundedBorder)
                        TextField("Longitude", text: $homeLonText)
                            .textFieldStyle(.roundedBorder)
                    }
                    Text("Drive distances and seasonal radius are calculated from here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Email Recipients") {
                    TextField("email1@example.com, email2@example.com", text: $emailRecipients)
                        .textFieldStyle(.roundedBorder)
                    Text("Comma-separated email addresses for the Email Us button")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    Text("Recommendations use Claude Sonnet 4.6 to analyze your hiking history, trail preferences, and weather forecasts to suggest personalized hikes.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(width: 450)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Save") {
                    ClaudeService.saveAPIKey(apiKey)
                    ClaudeService.saveEmailRecipients(emailRecipients)
                    PersonaConfig.save(
                        person1: person1, person2: person2,
                        homeName: homeName,
                        homeLat: Double(homeLatText) ?? PersonaConfig.homeLat,
                        homeLon: Double(homeLonText) ?? PersonaConfig.homeLon
                    )
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .onAppear {
            apiKey = ClaudeService.loadAPIKey()
            emailRecipients = ClaudeService.loadEmailRecipients()
            person1 = PersonaConfig.person1
            person2 = PersonaConfig.person2
            homeName = PersonaConfig.homeName
            homeLatText = String(PersonaConfig.homeLat)
            homeLonText = String(PersonaConfig.homeLon)
        }
    }
}
