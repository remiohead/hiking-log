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

// MARK: - Window Accessor (macOS)

#if os(macOS)
/// Bridges into AppKit to configure the NSWindow for full screen
/// and observe full screen state changes.
struct WindowFullScreenAccessor: NSViewRepresentable {
    @Binding var isFullScreen: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            // Force the green button to enter full screen (not just zoom)
            window.collectionBehavior.insert(.fullScreenPrimary)

            NotificationCenter.default.addObserver(
                context.coordinator,
                selector: #selector(Coordinator.didEnterFullScreen),
                name: NSWindow.didEnterFullScreenNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                context.coordinator,
                selector: #selector(Coordinator.didExitFullScreen),
                name: NSWindow.didExitFullScreenNotification,
                object: window
            )
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isFullScreen: $isFullScreen)
    }

    class Coordinator: NSObject {
        var isFullScreen: Binding<Bool>

        init(isFullScreen: Binding<Bool>) {
            self.isFullScreen = isFullScreen
        }

        @objc func didEnterFullScreen(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            // Hide the titlebar so the classic Mac view covers everything
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.toolbar?.isVisible = false
            isFullScreen.wrappedValue = true
        }

        @objc func didExitFullScreen(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            // Restore the titlebar
            window.titlebarAppearsTransparent = false
            window.titleVisibility = .visible
            window.toolbar?.isVisible = true
            isFullScreen.wrappedValue = false
        }
    }
}
#endif

#if os(macOS)
enum EasterEggMode: Equatable {
    case none
    case classicMac
    case commodore64
    case amiga500
    case nes
    case atari2600
    case playstation
    case gameboy
    case megadrive
    case windows31
}

extension Notification.Name {
    static let activateClassicMac = Notification.Name("activateClassicMac")
    static let activateCommodore64 = Notification.Name("activateCommodore64")
    static let activateAmiga500 = Notification.Name("activateAmiga500")
    static let activateNES = Notification.Name("activateNES")
    static let activateAtari2600 = Notification.Name("activateAtari2600")
    static let activatePlayStation = Notification.Name("activatePlayStation")
    static let activateGameBoy = Notification.Name("activateGameBoy")
    static let activateMegaDrive = Notification.Name("activateMegaDrive")
    static let activateWindows31 = Notification.Name("activateWindows31")
}
#endif

struct ContentView: View {
    @Environment(HikeStore.self) private var store
    @Environment(TrailStore.self) private var trailStore

    #if os(macOS)
    @State private var selection: NavItem = .dashboard
    @State private var dropTargeted = false
    @State private var isFullScreen = false
    @State private var easterEggMode: EasterEggMode = .none
    #else
    @State private var selectedTab = 0
    #endif

    var body: some View {
        #if os(macOS)
        ZStack {
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
                                Image(systemName: "arrow.down.doc.fill").font(.largeTitle)
                                Text("Drop to import").font(.headline)
                            }
                            .foregroundStyle(.green)
                        }
                        .padding(4)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                handleDrop(providers)
            }

            switch easterEggMode {
            case .none:
                EmptyView()
            case .classicMac:
                ClassicMacView()
                    .ignoresSafeArea()
            case .commodore64:
                C64View(onExit: { exitEasterEgg() })
                    .ignoresSafeArea()
            case .amiga500:
                AmigaView(onExit: { exitEasterEgg() })
                    .ignoresSafeArea()
            case .nes:
                NESView(onExit: { exitEasterEgg() })
                    .ignoresSafeArea()
            case .atari2600:
                AtariView(onExit: { exitEasterEgg() })
                    .ignoresSafeArea()
            case .playstation:
                PSOneView(onExit: { exitEasterEgg() })
                    .ignoresSafeArea()
            case .gameboy:
                GameBoyView(onExit: { exitEasterEgg() })
                    .ignoresSafeArea()
            case .megadrive:
                MegaDriveView(onExit: { exitEasterEgg() })
                    .ignoresSafeArea()
            case .windows31:
                Win31View(onExit: { exitEasterEgg() })
                    .ignoresSafeArea()
            }
        }
        .background {
            WindowFullScreenAccessor(isFullScreen: $isFullScreen)
        }
        .onChange(of: isFullScreen) { _, newValue in
            if newValue && easterEggMode == .none {
                // Green button default: Classic Mac
                easterEggMode = .classicMac
            } else if !newValue {
                easterEggMode = .none
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateClassicMac)) { _ in
            activateMode(.classicMac)
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateCommodore64)) { _ in
            activateMode(.commodore64)
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateAmiga500)) { _ in
            activateMode(.amiga500)
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateNES)) { _ in
            activateMode(.nes)
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateAtari2600)) { _ in
            activateMode(.atari2600)
        }
        .onReceive(NotificationCenter.default.publisher(for: .activatePlayStation)) { _ in
            activateMode(.playstation)
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateGameBoy)) { _ in
            activateMode(.gameboy)
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateMegaDrive)) { _ in
            activateMode(.megadrive)
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateWindows31)) { _ in
            activateMode(.windows31)
        }
        #else
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                .tag(0)
            HikeMapView()
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(1)
            HikeLogView()
                .tabItem { Label("Log", systemImage: "list.bullet") }
                .tag(2)
            TrailsView()
                .tabItem { Label("Trails", systemImage: "mountain.2.fill") }
                .tag(3)
            RecommendationsView()
                .tabItem { Label("For You", systemImage: "sparkles") }
                .tag(4)
        }
        #endif
    }

    #if os(macOS)
    private func activateMode(_ mode: EasterEggMode) {
        easterEggMode = mode
        if let window = NSApplication.shared.keyWindow,
           !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }

    private func exitEasterEgg() {
        easterEggMode = .none
        if let window = NSApplication.shared.keyWindow,
           window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
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
                                NotificationCenter.default.post(name: .showImportPreview, object: ImportPreview(hikes: result.hikes, skipped: result.skipped, errors: result.errors, source: "Health Auto Export"))
                            } else { store.importStatus = "No new hikes found (\(result.skipped) duplicates skipped)" }
                        } catch { store.importStatus = "Import failed: \(error.localizedDescription)" }
                    } else if ext == "json" {
                        do {
                            let hikes = try store.previewFromJSON(url)
                            if !hikes.isEmpty {
                                NotificationCenter.default.post(name: .showImportPreview, object: ImportPreview(hikes: hikes, skipped: 0, errors: [], source: "JSON"))
                            } else { store.importStatus = "No new hikes found" }
                        } catch { store.importStatus = "Import failed: \(error.localizedDescription)" }
                    }
                }
            }
        }
        return true
    }
    #endif
}
