import SwiftUI

struct HikeLogView: View {
    @Environment(HikeStore.self) private var store
    @Environment(TrailStore.self) private var trailStore
    @State private var selectedYear = "All"
    @State private var selectedRegion = "All"
    @State private var searchText = ""
    #if os(macOS)
    @State private var sortOrder = [KeyPathComparator(\Hike.date, order: .reverse)]
    @State private var selectedHikeID: String?
    @State private var showingAddSheet = false
    @State private var hikeToEdit: Hike?
    @State private var pendingBulkUpdate: BulkTrailUpdate?
    #endif
    @State private var hikeToView: Hike?
    @State private var photosHike: Hike?

    private var filtered: [Hike] {
        let base = store.hikes.filter { hike in
            (selectedYear == "All" || hike.year == selectedYear) &&
            (selectedRegion == "All" || hike.region == selectedRegion) &&
            (searchText.isEmpty || hike.trailName.localizedCaseInsensitiveContains(searchText))
        }
        #if os(macOS)
        return base.sorted(using: sortOrder)
        #else
        return base.sorted { $0.date > $1.date }
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Picker("Year", selection: $selectedYear) {
                    Text("All Years").tag("All")
                    ForEach(store.years, id: \.self) { year in
                        Text(year).tag(year)
                    }
                }
                .frame(width: 140)

                Picker("Region", selection: $selectedRegion) {
                    Text("All Regions").tag("All")
                    ForEach(store.regions, id: \.self) { region in
                        Text(region).tag(region)
                    }
                }
                .frame(width: 220)

                TextField("Search trails...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)

                Spacer()

                Text("\(filtered.count) hikes")
                    .foregroundStyle(.secondary)
                    .font(.callout)

                #if os(macOS)
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Hike", systemImage: "plus")
                }
                #endif
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Table
            #if os(macOS)
            Table(filtered, selection: $selectedHikeID, sortOrder: $sortOrder) {
                TableColumn("Date", value: \.date) { hike in
                    Text(hike.formattedDate)
                }
                .width(min: 90, ideal: 110)

                TableColumn("Trail", value: \.trailName) { hike in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(hike.trailName)
                            .fontWeight(.medium)
                        if hike.trailID != nil {
                            Text("linked")
                                .font(.system(size: 9))
                                .foregroundStyle(.green)
                        }
                    }
                }
                .width(min: 150, ideal: 250)

                TableColumn("Region", value: \.region) { hike in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(HikeStore.color(for: hike.region))
                            .frame(width: 8, height: 8)
                        Text(hike.region)
                    }
                }
                .width(min: 100, ideal: 160)

                TableColumn("Distance") { hike in
                    Text(String(format: "%.1f mi", hike.distanceMiles))
                        .monospacedDigit()
                }
                .width(70)

                TableColumn("Elevation") { hike in
                    Text("\(Int(hike.elevationGainFt).formatted()) ft")
                        .monospacedDigit()
                }
                .width(80)

                TableColumn("Duration") { hike in
                    Text(hike.formattedDuration)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .width(70)

                TableColumn(PersonaConfig.person2) { hike in
                    Button {
                        var updated = hike
                        updated.withJulie = !(hike.withJulie ?? false)
                        store.update(updated)
                    } label: {
                        Image(systemName: hike.withJulie == true ? "person.fill" : "person")
                            .foregroundStyle(hike.withJulie == true ? .green : .gray)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                .width(40)

                TableColumn("") { hike in
                    HStack(spacing: 6) {
                        Button {
                            photosHike = hike
                        } label: {
                            Image(systemName: "photo")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("View photos from this day")

                        Button {
                            hikeToEdit = hike
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)

                        Button {
                            store.delete(hike)
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
                if let hikeID = selection.first,
                   let hike = store.hikes.first(where: { $0.id == hikeID }) {
                    Button("View Details") {
                        hikeToView = hike
                    }
                    Button("Edit Hike") {
                        hikeToEdit = hike
                    }
                    Divider()
                    Button("Delete Hike", role: .destructive) {
                        store.delete(hike)
                    }
                }
            } primaryAction: { selection in
                // Double-click / Enter opens detail view
                if let hikeID = selection.first,
                   let hike = store.hikes.first(where: { $0.id == hikeID }) {
                    hikeToView = hike
                }
            }
            #else
            List(filtered) { hike in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hike.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(hike.trailName)
                            .fontWeight(.medium)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(HikeStore.color(for: hike.region))
                                .frame(width: 6, height: 6)
                            Text(hike.region)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f mi", hike.distanceMiles))
                            .monospacedDigit()
                        Text("\(Int(hike.elevationGainFt).formatted()) ft")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    hikeToView = hike
                }
            }
            #endif
        }
        .popover(item: $hikeToView, arrowEdge: .leading) { hike in
            HikeDetailView(hike: hike, store: store, trailStore: trailStore)
        }
        .popover(item: $photosHike, arrowEdge: .trailing) { hike in
            HikePhotosView(date: hike.date, trailName: hike.trailName, lat: hike.startLat, lon: hike.startLon)
        }
        #if os(macOS)
        .sheet(item: $hikeToEdit) { originalHike in
            HikeEditorView(hike: originalHike, mode: .edit, trailStore: trailStore) { edited in
                let oldTrailName = originalHike.trailName
                store.update(edited)

                // Sync the linked trail's name/region if they were edited
                if let trailID = edited.trailID,
                   var trail = trailStore.trail(byID: trailID) {
                    if trail.name != edited.trailName || trail.region != edited.region {
                        trail.name = edited.trailName
                        trail.region = edited.region
                        trailStore.update(trail)
                    }
                }

                // If trail changed and there are siblings, offer bulk update
                if edited.trailName != oldTrailName || edited.trailID != originalHike.trailID {
                    let siblings = store.siblingHikes(for: edited, oldTrailName: oldTrailName)
                    if !siblings.isEmpty {
                        pendingBulkUpdate = BulkTrailUpdate(
                            newTrailName: edited.trailName,
                            newRegion: edited.region,
                            newTrailID: edited.trailID,
                            siblings: siblings
                        )
                    }
                }
            }
        }
        .sheet(item: $pendingBulkUpdate) { update in
            BulkTrailUpdateView(update: update) { selectedIDs in
                store.bulkUpdateTrail(
                    hikeIDs: selectedIDs,
                    trailName: update.newTrailName,
                    region: update.newRegion,
                    trailID: update.newTrailID
                )
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            HikeEditorView(hike: Hike.blank(), mode: .add, trailStore: trailStore) { newHike in
                store.add(newHike)
            }
        }
        #endif
    }
}

// MARK: - Hike Editor

enum HikeEditorMode {
    case add, edit
}

#if os(macOS)

struct HikeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var hike: Hike
    let mode: HikeEditorMode
    let trailStore: TrailStore
    let onSave: (Hike) -> Void

    @State private var dateValue: Date
    @State private var distanceText: String
    @State private var elevationText: String
    @State private var durationText: String
    @State private var latText: String
    @State private var lonText: String
    @State private var showingTrailPicker = false

    init(hike: Hike, mode: HikeEditorMode, trailStore: TrailStore, onSave: @escaping (Hike) -> Void) {
        self._hike = State(initialValue: hike)
        self.mode = mode
        self.trailStore = trailStore
        self.onSave = onSave

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: hike.date) ?? Date()
        self._dateValue = State(initialValue: date)
        self._distanceText = State(initialValue: String(format: "%.2f", hike.distanceMiles))
        self._elevationText = State(initialValue: String(format: "%.0f", hike.elevationGainFt))
        self._durationText = State(initialValue: "\(hike.durationMinutes)")
        self._latText = State(initialValue: String(format: "%.6f", hike.startLat))
        self._lonText = State(initialValue: String(format: "%.6f", hike.startLon))
    }

    var linkedTrail: Trail? {
        trailStore.trail(byID: hike.trailID)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(mode == .add ? "Add Hike" : "Edit Hike")
                .font(.title2.bold())
                .padding()

            Form {
                // Trail association
                Section("Trail") {
                    if let trail = linkedTrail {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trail.name).fontWeight(.medium)
                                Text(trail.region)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let url = trail.displayURL {
                                    Text(url)
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                            Spacer()
                            Button("Change") { showingTrailPicker = true }
                            Button("Unlink") {
                                hike.trailID = nil
                            }
                            .foregroundStyle(.red)
                        }
                    } else {
                        HStack {
                            Text("No trail linked")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Choose Trail") { showingTrailPicker = true }
                        }

                        TextField("Trail Name", text: $hike.trailName)
                        TextField("Region", text: $hike.region)
                    }
                }

                Section("Date & Duration") {
                    DatePicker("Date", selection: $dateValue, displayedComponents: .date)
                    TextField("Duration (minutes)", text: $durationText)
                    Toggle("With \(PersonaConfig.person2)", isOn: Binding(
                        get: { hike.withJulie ?? false },
                        set: { hike.withJulie = $0 }
                    ))
                }

                Section("Distance & Elevation") {
                    TextField("Distance (miles)", text: $distanceText)
                    TextField("Elevation Gain (ft)", text: $elevationText)
                }

                Section("Coordinates") {
                    TextField("Latitude", text: $latText)
                    TextField("Longitude", text: $lonText)
                }
            }
            .formStyle(.grouped)
            .frame(width: 480)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button(mode == .add ? "Add" : "Save") {
                    applyEdits()
                    onSave(hike)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 530, height: 600)
        .sheet(isPresented: $showingTrailPicker) {
            TrailPickerView(trailStore: trailStore) { trail in
                hike.trailID = trail.id
                hike.trailName = trail.name
                hike.region = trail.region
            }
        }
    }

    private func applyEdits() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        hike.date = formatter.string(from: dateValue)
        hike.distanceMiles = Double(distanceText) ?? hike.distanceMiles
        hike.elevationGainFt = Double(elevationText) ?? hike.elevationGainFt
        hike.durationMinutes = Int(durationText) ?? hike.durationMinutes
        hike.startLat = Double(latText) ?? hike.startLat
        hike.startLon = Double(lonText) ?? hike.startLon
        hike.endLat = hike.startLat
        hike.endLon = hike.startLon
    }
}

// MARK: - Trail Picker

struct TrailPickerView: View {
    let trailStore: TrailStore
    let onSelect: (Trail) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [Trail] {
        if search.isEmpty { return trailStore.trails }
        return trailStore.trails.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.region.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose Trail")
                    .font(.title3.bold())
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            TextField("Search trails...", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List(filtered) { trail in
                Button {
                    onSelect(trail)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trail.name).fontWeight(.medium)
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(HikeStore.color(for: trail.region))
                                        .frame(width: 6, height: 6)
                                    Text(trail.region)
                                }
                                if let d = trail.distanceMiles {
                                    Text(String(format: "%.1f mi", d))
                                }
                                if let e = trail.elevationGainFt {
                                    Text("\(Int(e)) ft")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            if let url = trail.displayURL {
                                Text(url)
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 500, height: 450)
    }
}

// MARK: - Bulk Trail Update

struct BulkTrailUpdate: Identifiable {
    let id = UUID()
    let newTrailName: String
    let newRegion: String
    let newTrailID: String?
    let siblings: [(hike: Hike, distanceMiles: Double)]
}

struct BulkTrailUpdateView: View {
    let update: BulkTrailUpdate
    let onConfirm: (Set<String>) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String>

    init(update: BulkTrailUpdate, onConfirm: @escaping (Set<String>) -> Void) {
        self.update = update
        self.onConfirm = onConfirm
        // Pre-select hikes within 0.5 miles
        let closeIDs = update.siblings
            .filter { $0.distanceMiles <= 0.5 }
            .map { $0.hike.id }
        self._selected = State(initialValue: Set(closeIDs))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Update Other Hikes?")
                    .font(.title2.bold())
                Text("You changed the trail to **\(update.newTrailName)**.")
                    .font(.callout)
                Text("Select which other hikes with the same old trail should also be updated.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            // Select all / none
            HStack {
                Button("Select All") {
                    selected = Set(update.siblings.map { $0.hike.id })
                }
                Button("Select None") {
                    selected.removeAll()
                }
                Button("Select < 0.5 mi") {
                    selected = Set(update.siblings.filter { $0.distanceMiles <= 0.5 }.map { $0.hike.id })
                }
                Spacer()
                Text("\(selected.count) of \(update.siblings.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Hike list with checkboxes
            List {
                ForEach(update.siblings, id: \.hike.id) { item in
                    let isSelected = selected.contains(item.hike.id)
                    HStack(spacing: 10) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? .green : .secondary)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.hike.formattedDate)
                                .fontWeight(.medium)
                            Text(item.hike.trailName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Hike stats
                        Text(String(format: "%.1f mi", item.hike.distanceMiles))
                            .monospacedDigit()
                            .font(.callout)
                        Text("\(Int(item.hike.elevationGainFt).formatted()) ft")
                            .monospacedDigit()
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 65, alignment: .trailing)
                        Text(item.hike.formattedDuration)
                            .monospacedDigit()
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 55, alignment: .trailing)

                        // Distance from edited hike
                        distanceBadge(item.distanceMiles)
                            .frame(width: 70, alignment: .trailing)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selected.contains(item.hike.id) {
                            selected.remove(item.hike.id)
                        } else {
                            selected.insert(item.hike.id)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button("Skip") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Update \(selected.count) Hike\(selected.count == 1 ? "" : "s")") {
                    onConfirm(selected)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty)
            }
            .padding()
        }
        .frame(width: 680, height: 500)
    }

    @ViewBuilder
    private func distanceBadge(_ miles: Double) -> some View {
        let color: Color = miles <= 0.1 ? .green : miles <= 0.5 ? .orange : .red
        Text(String(format: "%.2f mi", miles))
            .font(.caption.bold())
            .foregroundStyle(color)
    }
}

// MARK: - Blank Hike

extension Hike {
    static func blank() -> Hike {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let id = formatter.string(from: now)
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: now)
        return Hike(
            id: id,
            date: date,
            distanceMiles: 0,
            elevationGainFt: 0,
            durationMinutes: 0,
            startLat: 47.55,
            startLon: -121.7,
            endLat: 47.55,
            endLon: -121.7,
            minAltitudeFt: 0,
            maxAltitudeFt: 0,
            trailName: "",
            region: "",
            matchConfidence: "manual",
            distanceToTrailheadMiles: 0,
            trailID: nil,
            withJulie: nil
        )
    }
}
#endif
