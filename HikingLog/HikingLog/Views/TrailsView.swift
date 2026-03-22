import SwiftUI

struct TrailsView: View {
    @Environment(TrailStore.self) private var trailStore
    @Environment(HikeStore.self) private var hikeStore
    @State private var searchText = ""
    @State private var segment = TrailSegment.hiked
    @State private var showingAddURL = false
    @State private var showingAddManual = false
    @State private var trailToEdit: Trail?
    @State private var trailToView: Trail?
    @State private var selectedTrailID: String?
    @State private var urlText = ""
    @State private var importingURL = false
    @State private var importError: String?
    @State private var importedTrail: Trail?

    enum Person { case shaun, julie }
    enum TrailSegment: String, CaseIterable { case hiked = "Hiked", wishlist = "Want to Do" }

    private func toggleLove(trail: Trail, person: Person) {
        var updated = trail
        switch person {
        case .shaun: updated.lovedByShaun = !(trail.lovedByShaun ?? false)
        case .julie: updated.lovedByJulie = !(trail.lovedByJulie ?? false)
        }
        trailStore.update(updated)
    }

    private var hikedTrailIDs: Set<String> {
        Set(hikeStore.hikes.compactMap(\.trailID))
    }

    private var hikedTrailNames: Set<String> {
        Set(hikeStore.hikes.map(\.trailName))
    }

    private func isHiked(_ trail: Trail) -> Bool {
        hikedTrailIDs.contains(trail.id) || hikedTrailNames.contains(trail.name)
    }

    private var filtered: [Trail] {
        trailStore.trails.filter { trail in
            let matchesSegment: Bool
            switch segment {
            case .hiked: matchesSegment = isHiked(trail)
            case .wishlist: matchesSegment = !isHiked(trail)
            }
            guard matchesSegment else { return false }
            if searchText.isEmpty { return true }
            return trail.name.localizedCaseInsensitiveContains(searchText) ||
                   trail.region.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Picker("", selection: $segment) {
                    ForEach(TrailSegment.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                TextField("Search trails...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)

                Spacer()

                Text("\(filtered.count) trails")
                    .foregroundStyle(.secondary)
                    .font(.callout)

                Button {
                    urlText = ""
                    importError = nil
                    importedTrail = nil
                    showingAddURL = true
                } label: {
                    Label("Add from URL", systemImage: "link.badge.plus")
                }

                Button {
                    showingAddManual = true
                } label: {
                    Label("Add Manually", systemImage: "plus")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Trail list
            Table(filtered, selection: $selectedTrailID) {
                TableColumn("Trail") { trail in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trail.name).fontWeight(.medium)
                        if let url = trail.displayURL {
                            Text(url)
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .lineLimit(1)
                        }
                    }
                }
                .width(min: 180, ideal: 280)

                TableColumn("Region") { trail in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(HikeStore.color(for: trail.region))
                            .frame(width: 8, height: 8)
                        Text(trail.region)
                    }
                }
                .width(min: 100, ideal: 160)

                TableColumn(PersonaConfig.person1) { trail in
                    Button {
                        toggleLove(trail: trail, person: .shaun)
                    } label: {
                        Image(systemName: trail.lovedByShaun == true ? "heart.fill" : "heart")
                            .foregroundStyle(trail.lovedByShaun == true ? .red : .secondary.opacity(0.4))
                    }
                    .buttonStyle(.borderless)
                }
                .width(45)

                TableColumn(PersonaConfig.person2) { trail in
                    Button {
                        toggleLove(trail: trail, person: .julie)
                    } label: {
                        Image(systemName: trail.lovedByJulie == true ? "heart.fill" : "heart")
                            .foregroundStyle(trail.lovedByJulie == true ? .pink : .secondary.opacity(0.4))
                    }
                    .buttonStyle(.borderless)
                }
                .width(45)

                TableColumn("Distance") { trail in
                    if let d = trail.distanceMiles {
                        Text(String(format: "%.1f mi", d))
                            .monospacedDigit()
                    } else {
                        Text("-").foregroundStyle(.tertiary)
                    }
                }
                .width(70)

                TableColumn("Elevation") { trail in
                    if let e = trail.elevationGainFt {
                        Text("\(Int(e).formatted()) ft")
                            .monospacedDigit()
                    } else {
                        Text("-").foregroundStyle(.tertiary)
                    }
                }
                .width(80)

                TableColumn("Difficulty") { trail in
                    if let d = trail.difficulty {
                        Text(d.capitalized)
                    } else {
                        Text("-").foregroundStyle(.tertiary)
                    }
                }
                .width(80)

                TableColumn("Source") { trail in
                    Text(trail.source ?? "—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .width(70)

                TableColumn("") { trail in
                    HStack(spacing: 8) {
                        if let urlStr = trail.url, let url = URL(string: urlStr) {
                            Button {
                                NSWorkspace.shared.open(url)
                            } label: {
                                Image(systemName: "safari")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("Open in browser")
                        }

                        Button {
                            trailToEdit = trail
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)

                        Button {
                            trailStore.delete(trail)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .width(80)
            }
            .contextMenu(forSelectionType: String.self) { selection in
                if let trailID = selection.first,
                   let trail = trailStore.trails.first(where: { $0.id == trailID }) {
                    Button("View Hikes") {
                        trailToView = trail
                    }
                    Button("Edit Trail") {
                        trailToEdit = trail
                    }
                    if let urlStr = trail.url, let url = URL(string: urlStr) {
                        Button("Open in Browser") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Divider()
                    Button("Delete Trail", role: .destructive) {
                        trailStore.delete(trail)
                    }
                }
            } primaryAction: { selection in
                if let trailID = selection.first,
                   let trail = trailStore.trails.first(where: { $0.id == trailID }) {
                    trailToView = trail
                }
            }
        }
        .popover(item: $trailToView, arrowEdge: .leading) { trail in
            TrailHikesView(trail: trail, hikeStore: hikeStore)
        }
        .sheet(isPresented: $showingAddURL) {
            AddTrailFromURLView(trailStore: trailStore)
        }
        .sheet(isPresented: $showingAddManual) {
            TrailEditorView(trail: Trail.blank(), mode: .add) { trail in
                trailStore.add(trail)
            }
        }
        .sheet(item: $trailToEdit) { trail in
            TrailEditorView(trail: trail, mode: .edit) { updated in
                trailStore.update(updated)
            }
        }
    }
}

// MARK: - Add Trail from URL

struct AddTrailFromURLView: View {
    let trailStore: TrailStore
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var importedTrail: Trail?

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Trail from URL")
                .font(.title2.bold())
                .padding()

            VStack(alignment: .leading, spacing: 12) {
                Text("Paste an AllTrails or WTA link:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("https://www.alltrails.com/trail/...", text: $urlText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        fetchTrail()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Fetch")
                        }
                    }
                    .disabled(urlText.isEmpty || isLoading)
                    .buttonStyle(.borderedProminent)
                }

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal)

            if let trail = importedTrail {
                Divider().padding(.vertical, 8)

                Form {
                    Section("Imported Trail") {
                        TextField("Name", text: binding(\.name))
                        TextField("Region", text: binding(\.region))
                        if let url = trail.url {
                            LabeledContent("URL") {
                                Text(url)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Section("Details") {
                        TextField("Distance (mi)", value: binding(\.distanceMiles), format: .number)
                        TextField("Elevation (ft)", value: binding(\.elevationGainFt), format: .number)
                        TextField("Difficulty", text: Binding(
                            get: { importedTrail?.difficulty ?? "" },
                            set: { importedTrail?.difficulty = $0.isEmpty ? nil : $0 }
                        ))
                    }
                    Section("Location") {
                        TextField("Latitude", value: binding(\.trailheadLat), format: .number)
                        TextField("Longitude", value: binding(\.trailheadLon), format: .number)
                    }
                }
                .formStyle(.grouped)
            }

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                if importedTrail != nil {
                    Button("Add Trail") {
                        if let trail = importedTrail {
                            trailStore.add(trail)
                            dismiss()
                        }
                    }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 550, height: importedTrail != nil ? 580 : 200)
    }

    private func fetchTrail() {
        isLoading = true
        error = nil
        importedTrail = nil

        Task {
            do {
                let trail = try await trailStore.importFromURL(urlText.trimmingCharacters(in: .whitespacesAndNewlines))
                await MainActor.run {
                    importedTrail = trail
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<Trail, T>) -> Binding<T> {
        Binding(
            get: { importedTrail![keyPath: keyPath] },
            set: { importedTrail![keyPath: keyPath] = $0 }
        )
    }
}

// MARK: - Trail Editor

struct TrailEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var trail: Trail
    let mode: HikeEditorMode
    let onSave: (Trail) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(mode == .add ? "Add Trail" : "Edit Trail")
                .font(.title2.bold())
                .padding()

            Form {
                Section("Trail Info") {
                    TextField("Name", text: $trail.name)
                    TextField("Region", text: $trail.region)
                    TextField("URL", text: Binding(
                        get: { trail.url ?? "" },
                        set: { trail.url = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Details") {
                    TextField("Distance (mi)", value: $trail.distanceMiles, format: .number)
                    TextField("Elevation (ft)", value: $trail.elevationGainFt, format: .number)
                    TextField("Difficulty", text: Binding(
                        get: { trail.difficulty ?? "" },
                        set: { trail.difficulty = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Location") {
                    TextField("Latitude", value: $trail.trailheadLat, format: .number)
                    TextField("Longitude", value: $trail.trailheadLon, format: .number)
                }

                Section("Notes") {
                    TextEditor(text: Binding(
                        get: { trail.notes ?? "" },
                        set: { trail.notes = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(height: 60)
                }

                Section("Tags") {
                    TextField("Tags (comma-separated)", text: Binding(
                        get: { trail.tags?.joined(separator: ", ") ?? "" },
                        set: { trail.tags = $0.isEmpty ? nil : $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                    ))
                }
            }
            .formStyle(.grouped)
            .frame(width: 450)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button(mode == .add ? "Add" : "Save") {
                    onSave(trail)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 480)
    }
}

// MARK: - Trail Hikes Popover

struct TrailHikesView: View {
    let trail: Trail
    let hikeStore: HikeStore
    @State private var forecast: [DayForecast] = []

    private var hikes: [Hike] {
        hikeStore.hikes
            .filter { $0.trailName == trail.name || $0.trailID == trail.id }
            .sorted { $0.date > $1.date }
    }

    private var totalMiles: Double {
        hikes.reduce(0) { $0 + $1.distanceMiles }
    }

    private var totalElevation: Double {
        hikes.reduce(0) { $0 + $1.elevationGainFt }
    }

    private var avgMiles: Double {
        guard !hikes.isEmpty else { return 0 }
        return totalMiles / Double(hikes.count)
    }

    private var avgElevation: Int {
        guard !hikes.isEmpty else { return 0 }
        return Int(totalElevation / Double(hikes.count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(trail.name)
                    .font(.title2.bold())
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(HikeStore.color(for: trail.region))
                            .frame(width: 8, height: 8)
                        Text(trail.region)
                    }
                    if let urlStr = trail.url, let url = URL(string: urlStr) {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "safari")
                                Text(trail.displayURL ?? "")
                                    .lineLimit(1)
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.blue)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            // Summary stats
            HStack(spacing: 0) {
                MiniStat(label: "Hikes", value: "\(hikes.count)")
                MiniStat(label: "Total Miles", value: String(format: "%.1f", totalMiles))
                MiniStat(label: "Total Elev.", value: "\(Int(totalElevation).formatted()) ft")
                MiniStat(label: "Avg Dist", value: String(format: "%.1f mi", avgMiles))
                MiniStat(label: "Avg Elev", value: "\(avgElevation.formatted()) ft")
            }
            .padding(.vertical, 8)
            .background(.background.secondary)

            Divider()

            // Weather forecast
            if !forecast.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(forecast) { day in
                            VStack(spacing: 2) {
                                Text(day.dayName)
                                    .font(.caption2.bold())
                                Image(systemName: day.icon)
                                    .font(.callout)
                                    .foregroundStyle(day.precipInches > 0.1 ? .blue : .yellow)
                                Text("\(Int(day.tempHighF))°")
                                    .font(.caption.bold())
                                Text("\(Int(day.tempLowF))°")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if day.precipInches > 0 {
                                    Text(String(format: "%.1f\"", day.precipInches))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.blue)
                                }
                            }
                            .frame(width: 50)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 4)
                Divider()
            }

            // Notes
            if let notes = trail.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                Divider()
            }

            if hikes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.hiking")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No hikes recorded for this trail")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Hike list
                List(hikes) { hike in
                    HStack {
                        Text(hike.formattedDate)
                            .frame(width: 100, alignment: .leading)
                        Spacer()
                        Text(String(format: "%.1f mi", hike.distanceMiles))
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                        Text("\(Int(hike.elevationGainFt).formatted()) ft")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                        Text(hike.formattedDuration)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .font(.callout)
                }
            }
        }
        .frame(width: 480, height: 500)
        .task {
            do {
                forecast = try await WeatherService.shared.forecast(lat: trail.trailheadLat, lon: trail.trailheadLon)
            } catch {}
        }
    }
}

private struct MiniStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
