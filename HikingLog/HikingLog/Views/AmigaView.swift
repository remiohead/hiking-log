import SwiftUI

#if os(macOS)

// MARK: - Amiga 500 Workbench 1.3

struct AmigaView: View {
    @Environment(HikeStore.self) private var store
    @Environment(TrailStore.self) private var trailStore

    let onExit: () -> Void

    @State private var windows: [AmigaWindow] = []
    @State private var windowOrder: [UUID] = []
    @State private var selectedIcon: String? = nil
    @State private var dragStarts: [UUID: CGPoint] = [:]
    @FocusState private var isFocused: Bool

    // Amiga Workbench 1.3 colors
    static let wbBlue = Color(red: 0.0, green: 0.22, blue: 0.53)
    static let wbWhite = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let wbBlack = Color(red: 0.0, green: 0.0, blue: 0.0)
    static let wbOrange = Color(red: 1.0, green: 0.53, blue: 0.0)

    struct AmigaWindow: Identifiable {
        let id = UUID()
        var title: String
        var position: CGPoint
        var size: CGSize
        var lines: [String]
    }

    private let titleBarH: CGFloat = 22
    private let screenTitleH: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Desktop pattern (blue/white horizontal stripes)
                Canvas { context, size in
                    for y in stride(from: 0, to: size.height, by: 2) {
                        let color: Color = Int(y) % 4 < 2 ? Self.wbBlue : Color(red: 0.33, green: 0.53, blue: 0.80)
                        context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 2)), with: .color(color))
                    }
                }
                .ignoresSafeArea()
                .onTapGesture { selectedIcon = nil }

                // Desktop icons
                desktopIcons(in: geo)

                // Windows
                ForEach($windows) { $window in
                    amigaWindow(window: window, isActive: windowOrder.last == window.id) {
                        closeWindow(window.id)
                    } onBringToFront: {
                        bringToFront(window.id)
                    } onDragChanged: { translation in
                        if dragStarts[window.id] == nil { dragStarts[window.id] = window.position }
                        if let s = dragStarts[window.id] {
                            window.position = CGPoint(x: s.x + translation.width, y: s.y + translation.height)
                        }
                    } onDragEnded: {
                        dragStarts[window.id] = nil
                    }
                    .zIndex(Double(windowOrder.firstIndex(of: window.id) ?? 0))
                }

                // Screen title bar (topmost)
                screenTitleBar(width: geo.size.width)
                    .zIndex(1000)
            }
        }
        .background(Self.wbBlue)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(.escape) {
            onExit()
            return .handled
        }
        .onAppear { isFocused = true }
    }

    // MARK: - Screen Title Bar

    @ViewBuilder
    private func screenTitleBar(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text("  Amiga Hiking Workbench")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Self.wbWhite)
            Spacer()
            // Depth gadgets (front/back)
            ZStack {
                Rectangle().stroke(Self.wbWhite, lineWidth: 1)
                    .frame(width: 16, height: 12)
                    .offset(x: -3, y: -2)
                Rectangle().fill(Self.wbBlue).frame(width: 16, height: 12).offset(x: 3, y: 2)
                Rectangle().stroke(Self.wbWhite, lineWidth: 1)
                    .frame(width: 16, height: 12)
                    .offset(x: 3, y: 2)
            }
            .frame(width: 30, height: 20)
            .padding(.trailing, 4)
        }
        .frame(height: screenTitleH)
        .background(
            LinearGradient(colors: [Self.wbBlue, Color(red: 0.0, green: 0.33, blue: 0.67)],
                           startPoint: .leading, endPoint: .trailing)
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(Self.wbWhite).frame(height: 1)
        }
    }

    // MARK: - Desktop Icons

    @ViewBuilder
    private func desktopIcons(in geo: GeometryProxy) -> some View {
        let rightX = geo.size.width - 70
        let topY = screenTitleH + 30

        amigaIcon(name: "Ram Disk:", x: rightX, y: topY, icon: "disk") {
            selectedIcon = "ram"
        } onDouble: {
            openWindow(title: "Ram Disk:", content: systemInfo())
        }

        amigaIcon(name: "Hiking:", x: rightX, y: topY + 80, icon: "disk") {
            selectedIcon = "hiking"
        } onDouble: {
            openWindow(title: "Hiking:", content: hikingOverview())
        }

        amigaIcon(name: "Trails", x: rightX, y: topY + 160, icon: "drawer") {
            selectedIcon = "trails"
        } onDouble: {
            openWindow(title: "Trails", content: trailList())
        }

        amigaIcon(name: "Hike Log", x: rightX, y: topY + 240, icon: "drawer") {
            selectedIcon = "hikes"
        } onDouble: {
            openWindow(title: "Hike Log", content: hikeList())
        }

        // Trashcan bottom-right
        amigaIcon(name: "Trashcan", x: rightX, y: geo.size.height - 70, icon: "trash") {
            selectedIcon = "trash"
        } onDouble: { }
    }

    @ViewBuilder
    private func amigaIcon(name: String, x: CGFloat, y: CGFloat, icon: String,
                           onClick: @escaping () -> Void, onDouble: @escaping () -> Void) -> some View {
        VStack(spacing: 2) {
            Canvas { context, size in
                let r = CGRect(x: 4, y: 0, width: size.width - 8, height: size.height - 4)
                switch icon {
                case "disk":
                    context.fill(Path(r), with: .color(Self.wbOrange))
                    context.stroke(Path(r), with: .color(Self.wbBlack), lineWidth: 1.5)
                    // Disk slot
                    let slot = CGRect(x: r.midX - 12, y: r.maxY - 10, width: 24, height: 6)
                    context.fill(Path(slot), with: .color(Self.wbBlue))
                    context.stroke(Path(slot), with: .color(Self.wbBlack), lineWidth: 1)
                case "drawer":
                    // Amiga drawer icon
                    var path = Path()
                    path.move(to: CGPoint(x: r.minX, y: r.minY + 8))
                    path.addLine(to: CGPoint(x: r.minX, y: r.minY + 4))
                    path.addLine(to: CGPoint(x: r.minX + 16, y: r.minY + 4))
                    path.addLine(to: CGPoint(x: r.minX + 20, y: r.minY + 8))
                    path.addLine(to: CGPoint(x: r.maxX, y: r.minY + 8))
                    path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
                    path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
                    path.closeSubpath()
                    context.fill(path, with: .color(Self.wbOrange))
                    context.stroke(path, with: .color(Self.wbBlack), lineWidth: 1.5)
                case "trash":
                    let body = CGRect(x: r.minX + 4, y: r.minY + 6, width: r.width - 8, height: r.height - 6)
                    context.fill(Path(body), with: .color(Self.wbWhite))
                    context.stroke(Path(body), with: .color(Self.wbBlack), lineWidth: 1.5)
                    let lid = CGRect(x: r.minX + 2, y: r.minY + 2, width: r.width - 4, height: 6)
                    context.fill(Path(lid), with: .color(Self.wbWhite))
                    context.stroke(Path(lid), with: .color(Self.wbBlack), lineWidth: 1.5)
                default:
                    break
                }
            }
            .frame(width: 52, height: 36)

            Text(name)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(selectedIcon == name.lowercased() ? Self.wbBlue : Self.wbWhite)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(selectedIcon == name.lowercased() ? Self.wbOrange : Color.clear)
        }
        .position(x: x, y: y)
        .onTapGesture(count: 2) { onDouble() }
        .onTapGesture(count: 1) { onClick() }
    }

    // MARK: - Amiga Window

    @ViewBuilder
    private func amigaWindow(window: AmigaWindow, isActive: Bool,
                             onClose: @escaping () -> Void,
                             onBringToFront: @escaping () -> Void,
                             onDragChanged: @escaping (CGSize) -> Void,
                             onDragEnded: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            // Title bar
            HStack(spacing: 0) {
                // Close gadget
                Rectangle()
                    .fill(isActive ? Self.wbOrange : Self.wbBlue)
                    .frame(width: 20, height: titleBarH)
                    .overlay {
                        Circle().fill(Self.wbBlack).frame(width: 8, height: 8)
                    }
                    .border(Self.wbBlack, width: 1)
                    .onTapGesture { onClose() }

                // Title
                HStack {
                    Text("  " + window.title)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(isActive ? Self.wbBlack : Self.wbWhite)
                        .lineLimit(1)
                    Spacer()
                }
                .frame(height: titleBarH)
                .background(isActive ? Self.wbOrange : Self.wbBlue)
                .border(Self.wbBlack, width: 1)

                // Depth gadgets
                ZStack {
                    Rectangle().fill(isActive ? Self.wbOrange : Self.wbBlue)
                        .frame(width: 22, height: titleBarH / 2)
                        .border(Self.wbBlack, width: 1)
                        .offset(x: -3, y: -3)
                    Rectangle().fill(isActive ? Self.wbOrange : Self.wbBlue)
                        .frame(width: 22, height: titleBarH / 2)
                        .border(Self.wbBlack, width: 1)
                        .offset(x: 3, y: 3)
                }
                .frame(width: 34, height: titleBarH)
                .background(isActive ? Self.wbOrange : Self.wbBlue)
            }
            .gesture(
                DragGesture()
                    .onChanged { v in onBringToFront(); onDragChanged(v.translation) }
                    .onEnded { _ in onDragEnded() }
            )

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(window.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(Self.wbWhite)
                            .lineLimit(1)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Self.wbBlue)
        }
        .frame(width: window.size.width, height: window.size.height)
        .border(Self.wbWhite, width: 2)
        .background(Self.wbBlue)
        .shadow(color: .black.opacity(0.4), radius: 0, x: 3, y: 3)
        .position(x: window.position.x + window.size.width / 2,
                  y: window.position.y + window.size.height / 2)
        .onTapGesture { onBringToFront() }
    }

    // MARK: - Window Management

    private func openWindow(title: String, content: [String]) {
        if windows.contains(where: { $0.title == title }) {
            if let w = windows.first(where: { $0.title == title }) { bringToFront(w.id) }
            return
        }
        let offset = CGFloat(windows.count) * 24
        let w = AmigaWindow(
            title: title,
            position: CGPoint(x: 30 + offset, y: screenTitleH + 10 + offset),
            size: CGSize(width: 500, height: 300),
            lines: content
        )
        windows.append(w)
        windowOrder.append(w.id)
    }

    private func closeWindow(_ id: UUID) {
        windows.removeAll { $0.id == id }
        windowOrder.removeAll { $0 == id }
    }

    private func bringToFront(_ id: UUID) {
        windowOrder.removeAll { $0 == id }
        windowOrder.append(id)
    }

    // MARK: - Content Generators

    private func systemInfo() -> [String] {
        [
            "Amiga Hiking Workbench 1.3",
            "Copyright (c) 1985-2026 Trail Computing",
            "",
            "Chip RAM:    512K",
            "Fast RAM:    512K",
            "Hiking RAM:  \(store.hikes.count) records",
            "Trail DB:    \(trailStore.trails.count) trails",
            "",
            "Kickstart 1.3 (34.5)",
            "Workbench 1.3.2",
        ]
    }

    private func hikingOverview() -> [String] {
        let miles = String(format: "%.1f", store.hikes.reduce(0) { $0 + $1.distanceMiles })
        let elev = Int(store.hikes.reduce(0) { $0 + $1.elevationGainFt })
        let years = Set(store.hikes.map(\.year)).count
        return [
            "=== HIKING OVERVIEW ===",
            "",
            "Total Hikes:     \(store.hikes.count)",
            "Total Miles:     \(miles)",
            "Total Elevation: \(elev.formatted()) ft",
            "Years Active:    \(years)",
            "Unique Trails:   \(Set(store.hikes.map(\.trailName)).count)",
            "Regions:         \(Set(store.hikes.map(\.region)).count)",
            "",
            "Current Streak:  \(store.streakInfo.currentWeeks) weeks",
            "Longest Streak:  \(store.streakInfo.longestWeeks) weeks",
            "Days Since Last: \(store.streakInfo.daysSinceLastHike)",
            "",
            "--- Personal Records ---",
            store.personalRecords.longestDistance.map { "Longest: \(String(format: "%.1f", $0.distanceMiles))mi - \($0.trailName)" } ?? "",
            store.personalRecords.mostElevation.map { "Highest: \(Int($0.elevationGainFt))ft - \($0.trailName)" } ?? "",
        ]
    }

    private func trailList() -> [String] {
        var result = ["=== FAVORITE TRAILS ===", ""]
        let loved = trailStore.trails.filter { $0.lovedByShaun == true || $0.lovedByJulie == true }
        let trails = loved.isEmpty ? Array(trailStore.trails.prefix(20)) : loved
        for t in trails.sorted(by: { $0.name < $1.name }) {
            let mi = t.distanceMiles.map { String(format: "%.1fmi", $0) } ?? "   ?mi"
            let who = [t.lovedByShaun == true ? "S" : nil, t.lovedByJulie == true ? "J" : nil]
                .compactMap { $0 }.joined()
            let heart = who.isEmpty ? "  " : "[\(who)]"
            result.append("\(heart) \(t.name.padding(toLength: 32, withPad: " ", startingAt: 0)) \(mi)")
        }
        return result
    }

    private func hikeList() -> [String] {
        var result = ["=== RECENT HIKES ===", ""]
        result.append("Date        Miles  Elev   Trail")
        result.append(String(repeating: "-", count: 50))
        for h in store.hikes.prefix(25) {
            let mi = String(format: "%5.1f", h.distanceMiles)
            let el = String(format: "%5d", Int(h.elevationGainFt))
            result.append("\(h.date)  \(mi)  \(el)  \(h.trailName.prefix(20))")
        }
        return result
    }
}

#endif
