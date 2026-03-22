import SwiftUI
import UniformTypeIdentifiers

enum NavItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case map = "Map"
    case log = "Hike Log"
    case trails = "Trails"
    case review = "Year in Review"
    case recommendations = "Recommendations"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .map: return "map.fill"
        case .log: return "list.bullet.rectangle.fill"
        case .trails: return "mountain.2.fill"
        case .review: return "calendar"
        case .recommendations: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .dashboard: return .green
        case .map: return .blue
        case .log: return .orange
        case .trails: return .teal
        case .review: return .purple
        case .recommendations: return .pink
        }
    }
}

struct ContentView: View {
    @Environment(HikeStore.self) private var store
    @Environment(TrailStore.self) private var trailStore
    @State private var selection: NavItem = .dashboard
    @State private var dropTargeted = false

    var body: some View {
        NavigationSplitView {
            List(NavItem.allCases, selection: $selection) { item in
                Label {
                    Text(item.rawValue)
                } icon: {
                    Image(systemName: item.icon)
                        .foregroundStyle(item.tint)
                }
                .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
            .listStyle(.sidebar)
        } detail: {
            switch selection {
            case .dashboard: DashboardView()
            case .map: HikeMapView()
            case .log: HikeLogView()
            case .trails: TrailsView()
            case .review: YearInReviewView()
            case .recommendations: RecommendationsView()
            }
        }
        .frame(minWidth: 1000, minHeight: 650)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.green, lineWidth: 3)
                    .background(.green.opacity(0.05))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.largeTitle)
                            Text("Drop to import")
                                .font(.headline)
                        }
                        .foregroundStyle(.green)
                    }
                    .padding(4)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    let ext = url.pathExtension.lowercased()
                    if ext == "zip" {
                        do {
                            let result = try store.previewFromHealthExportZip(url, trailStore: trailStore)
                            if !result.hikes.isEmpty {
                                NotificationCenter.default.post(
                                    name: .showImportPreview,
                                    object: ImportPreview(hikes: result.hikes, skipped: result.skipped, errors: result.errors, source: "Health Auto Export")
                                )
                            } else {
                                store.importStatus = "No new hikes found (\(result.skipped) duplicates skipped)"
                            }
                        } catch {
                            store.importStatus = "Import failed: \(error.localizedDescription)"
                        }
                    } else if ext == "json" {
                        do {
                            let hikes = try store.previewFromJSON(url)
                            if !hikes.isEmpty {
                                NotificationCenter.default.post(
                                    name: .showImportPreview,
                                    object: ImportPreview(hikes: hikes, skipped: 0, errors: [], source: "JSON")
                                )
                            } else {
                                store.importStatus = "No new hikes found"
                            }
                        } catch {
                            store.importStatus = "Import failed: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
        return true
    }
}

extension Notification.Name {
    static let showImportPreview = Notification.Name("showImportPreview")
}
