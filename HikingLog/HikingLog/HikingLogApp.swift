import SwiftUI
import UniformTypeIdentifiers

@main
struct HikingApp: App {
    @State private var store = HikeStore()
    @State private var trailStore = TrailStore()
    @State private var showingImportAlert = false
    #if os(macOS)
    @State private var importPreview: ImportPreview?
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(trailStore)
                .tint(Color(red: 0.18, green: 0.65, blue: 0.45))
                .alert("Import Complete", isPresented: $showingImportAlert) {
                    Button("OK") { store.importStatus = nil }
                } message: {
                    Text(store.importStatus ?? "")
                }
                .onChange(of: store.importStatus) { _, newValue in
                    if newValue != nil {
                        showingImportAlert = true
                    }
                }
                #if os(macOS)
                .onReceive(NotificationCenter.default.publisher(for: .showImportPreview)) { notification in
                    if let preview = notification.object as? ImportPreview {
                        importPreview = preview
                    }
                }
                .sheet(item: $importPreview) { preview in
                    ImportPreviewView(preview: preview) { selected in
                        store.importSelected(selected)
                    }
                }
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .toolbar) {
                Divider()
                Menu("Retro Mode") {
                    Button("Macintosh 1984") {
                        NotificationCenter.default.post(name: .activateClassicMac, object: nil)
                    }
                    Button("Commodore 64") {
                        NotificationCenter.default.post(name: .activateCommodore64, object: nil)
                    }
                    Button("Amiga 500") {
                        NotificationCenter.default.post(name: .activateAmiga500, object: nil)
                    }
                    Button("NES") {
                        NotificationCenter.default.post(name: .activateNES, object: nil)
                    }
                    Button("Game Boy") {
                        NotificationCenter.default.post(name: .activateGameBoy, object: nil)
                    }
                    Button("Mega Drive") {
                        NotificationCenter.default.post(name: .activateMegaDrive, object: nil)
                    }
                    Button("Atari 2600") {
                        NotificationCenter.default.post(name: .activateAtari2600, object: nil)
                    }
                    Button("PlayStation") {
                        NotificationCenter.default.post(name: .activatePlayStation, object: nil)
                    }
                    Button("Windows 3.1") {
                        NotificationCenter.default.post(name: .activateWindows31, object: nil)
                    }
                }
            }
            CommandGroup(after: .importExport) {
                Button("Import Health Auto Export (.zip)...") {
                    importHealthExportZip()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Import Hike History (.json)...") {
                    importJSON()
                }

                Divider()

                Button("Export Hike History...") {
                    exportData()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                Button("Reveal Data in Finder") {
                    let dir = HikeStore.dataFileURL.deletingLastPathComponent()
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dir.path)
                }
            }
        }
        #endif
    }

    #if os(macOS)
    private func importHealthExportZip() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.zip]
        panel.allowsMultipleSelection = false
        panel.message = "Select a Health Auto Export zip file"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let result = try store.previewFromHealthExportZip(url, trailStore: trailStore)
                if result.hikes.isEmpty {
                    store.importStatus = "No new hikes found (\(result.skipped) duplicates skipped)"
                } else {
                    importPreview = ImportPreview(
                        hikes: result.hikes,
                        skipped: result.skipped,
                        errors: result.errors,
                        source: "Health Auto Export"
                    )
                }
            } catch {
                showError("Import Failed", error)
            }
        }
    }

    private func importJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.message = "Select a hike history JSON file"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let hikes = try store.previewFromJSON(url)
                if hikes.isEmpty {
                    store.importStatus = "No new hikes found (all duplicates)"
                } else {
                    importPreview = ImportPreview(
                        hikes: hikes,
                        skipped: 0,
                        errors: [],
                        source: "JSON"
                    )
                }
            } catch {
                showError("Import Failed", error)
            }
        }
    }

    private func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "hike_history.json"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try store.exportToFile(url)
            } catch {
                showError("Export Failed", error)
            }
        }
    }

    private func showError(_ title: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
    #endif
}

// MARK: - Import Preview (macOS only)

#if os(macOS)
struct ImportPreview: Identifiable {
    let id = UUID()
    let hikes: [Hike]
    let skipped: Int
    let errors: [String]
    let source: String
}

struct ImportPreviewView: View {
    let preview: ImportPreview
    let onImport: ([Hike]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String>

    init(preview: ImportPreview, onImport: @escaping ([Hike]) -> Void) {
        self.preview = preview
        self.onImport = onImport
        let preselected = preview.hikes.filter { $0.distanceMiles > 5.0 }.map(\.id)
        self._selected = State(initialValue: Set(preselected))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Import Preview").font(.title2.bold())
                Text("\(preview.hikes.count) new hikes found from \(preview.source)").font(.callout)
                if preview.skipped > 0 {
                    Text("\(preview.skipped) duplicates already skipped").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
            Divider()
            HStack {
                Button("Select All") { selected = Set(preview.hikes.map(\.id)) }
                Button("Select None") { selected.removeAll() }
                Button("Select > 5 mi") { selected = Set(preview.hikes.filter { $0.distanceMiles > 5.0 }.map(\.id)) }
                Button("Select > 3 mi") { selected = Set(preview.hikes.filter { $0.distanceMiles > 3.0 }.map(\.id)) }
                Spacer()
                Text("\(selected.count) of \(preview.hikes.count) selected").font(.caption).foregroundStyle(.secondary)
            }
            .buttonStyle(.bordered).controlSize(.small)
            .padding(.horizontal).padding(.vertical, 8)
            Divider()
            List {
                ForEach(preview.hikes) { hike in
                    let isSelected = selected.contains(hike.id)
                    HStack(spacing: 10) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? .green : .secondary).font(.title3)
                        Text(hike.formattedDate).frame(width: 100, alignment: .leading)
                        Text(hike.trailName).fontWeight(.medium).lineLimit(1)
                        Spacer()
                        Text(String(format: "%.1f mi", hike.distanceMiles)).monospacedDigit().frame(width: 60, alignment: .trailing)
                        Text("\(Int(hike.elevationGainFt).formatted()) ft").monospacedDigit().foregroundStyle(.secondary).frame(width: 65, alignment: .trailing)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selected.contains(hike.id) { selected.remove(hike.id) } else { selected.insert(hike.id) }
                    }
                }
            }
            Divider()
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button("Import \(selected.count) Hike\(selected.count == 1 ? "" : "s")") {
                    onImport(preview.hikes.filter { selected.contains($0.id) })
                    dismiss()
                }.keyboardShortcut(.return).buttonStyle(.borderedProminent).disabled(selected.isEmpty)
            }.padding()
        }
        .frame(width: 780, height: 550)
    }
}

extension Notification.Name {
    static let showImportPreview = Notification.Name("showImportPreview")
}
#endif
