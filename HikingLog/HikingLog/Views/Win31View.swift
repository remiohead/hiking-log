import SwiftUI

#if os(macOS)

// MARK: - Windows 3.1 Program Manager

struct Win31View: View {
    @Environment(HikeStore.self) private var store
    @Environment(TrailStore.self) private var trailStore

    let onExit: () -> Void

    @State private var windows: [Win31Window] = []
    @State private var windowOrder: [UUID] = []
    @State private var dragStarts: [UUID: CGPoint] = [:]
    @State private var showAbout: Bool = false
    @FocusState private var isFocused: Bool

    // Windows 3.1 colors
    static let winTeal = Color(red: 0.0, green: 0.50, blue: 0.50)
    static let winGray = Color(red: 0.75, green: 0.75, blue: 0.75)
    static let winDarkGray = Color(red: 0.50, green: 0.50, blue: 0.50)
    static let winWhite = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let winBlack = Color(red: 0.0, green: 0.0, blue: 0.0)
    static let winNavy = Color(red: 0.0, green: 0.0, blue: 0.50)
    static let winBlue = Color(red: 0.0, green: 0.0, blue: 0.75)

    struct Win31Window: Identifiable {
        let id = UUID()
        var title: String
        var position: CGPoint
        var size: CGSize
        var icons: [Win31Icon]?   // group window (Program Manager style)
        var textContent: [String]? // text window (Notepad style)
    }

    struct Win31Icon: Identifiable {
        let id = UUID()
        let name: String
        let emoji: String
        let action: String // identifier
    }

    private let titleH: CGFloat = 20
    private let menuH: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Teal desktop
                Self.winTeal.ignoresSafeArea()

                // Desktop icons/windows
                ForEach($windows) { $window in
                    win31Window(window: window, isActive: windowOrder.last == window.id) {
                        closeWindow(window.id)
                    } onBringToFront: {
                        bringToFront(window.id)
                    } onDragChanged: { t in
                        if dragStarts[window.id] == nil { dragStarts[window.id] = window.position }
                        if let s = dragStarts[window.id] {
                            window.position = CGPoint(x: s.x + t.width, y: s.y + t.height)
                        }
                    } onDragEnded: {
                        dragStarts[window.id] = nil
                    } onIconAction: { action in
                        handleAction(action)
                    }
                    .zIndex(Double(windowOrder.firstIndex(of: window.id) ?? 0))
                }

                // About dialog
                if showAbout {
                    aboutDialog.zIndex(1000)
                }

                // Menu bar (on top)
                menuBar(width: geo.size.width)
                    .zIndex(2000)
            }
        }
        .background(Self.winTeal)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(.escape) { onExit(); return .handled }
        .onAppear {
            isFocused = true
            setupProgramManager()
        }
    }

    // MARK: - Menu Bar

    @ViewBuilder
    private func menuBar(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("  Program Manager - Hiking Edition")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Self.winWhite)
                Spacer()
            }
            .frame(height: titleH)
            .background(Self.winNavy)

            HStack(spacing: 0) {
                winMenuButton("File")
                winMenuButton("Options")
                winMenuButton("Window")
                winMenuButton("Help") { showAbout = true }
                Spacer()
            }
            .frame(height: menuH)
            .background(Self.winGray)
            .overlay(alignment: .top) { bevel3DTop() }
            .overlay(alignment: .bottom) { bevel3DBottom() }
        }
    }

    @ViewBuilder
    private func winMenuButton(_ title: String, action: (() -> Void)? = nil) -> some View {
        Text("  \(title)  ")
            .font(.system(size: 12))
            .foregroundStyle(Self.winBlack)
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
            .onTapGesture { action?() }
    }

    // MARK: - Window Chrome

    @ViewBuilder
    private func win31Window(window: Win31Window, isActive: Bool,
                             onClose: @escaping () -> Void,
                             onBringToFront: @escaping () -> Void,
                             onDragChanged: @escaping (CGSize) -> Void,
                             onDragEnded: @escaping () -> Void,
                             onIconAction: @escaping (String) -> Void) -> some View {
        VStack(spacing: 0) {
            // Title bar
            HStack(spacing: 4) {
                // System menu button
                Rectangle()
                    .fill(isActive ? Self.winNavy : Self.winDarkGray)
                    .frame(width: 18, height: 14)
                    .overlay {
                        Text("-")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Self.winWhite)
                    }

                Text(window.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Self.winWhite)
                    .lineLimit(1)

                Spacer()

                // Minimize
                win31Button("▼", size: 14)
                // Maximize
                win31Button("▲", size: 14)
            }
            .padding(.horizontal, 3)
            .frame(height: titleH)
            .background(isActive ? Self.winNavy : Self.winDarkGray)
            .gesture(
                DragGesture()
                    .onChanged { v in onBringToFront(); onDragChanged(v.translation) }
                    .onEnded { _ in onDragEnded() }
            )

            // Content area
            if let icons = window.icons {
                // Program group: icon grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                        ForEach(icons) { icon in
                            VStack(spacing: 4) {
                                Text(icon.emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 36, height: 36)
                                Text(icon.name)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Self.winBlack)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 72)
                            }
                            .onTapGesture(count: 2) { onIconAction(icon.action) }
                        }
                    }
                    .padding(10)
                }
                .background(Self.winWhite)
            } else if let lines = window.textContent {
                // Notepad-style text content
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Self.winBlack)
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Self.winWhite)
            }
        }
        .frame(width: window.size.width, height: window.size.height)
        .background(Self.winGray)
        .overlay(
            Rectangle().stroke(Self.winBlack, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) { bevel3DTop() }
        .overlay(alignment: .topLeading) {
            Rectangle().fill(Self.winWhite).frame(width: 1, height: window.size.height)
        }
        .overlay(alignment: .topLeading) {
            Rectangle().fill(Self.winWhite).frame(width: window.size.width, height: 1)
        }
        .shadow(color: .black.opacity(0.3), radius: 0, x: 2, y: 2)
        .position(x: window.position.x + window.size.width / 2,
                  y: window.position.y + window.size.height / 2)
        .onTapGesture { onBringToFront() }
    }

    @ViewBuilder
    private func win31Button(_ label: String, size: CGFloat) -> some View {
        Text(label)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(Self.winBlack)
            .frame(width: size, height: size)
            .background(Self.winGray)
            .overlay(
                Rectangle().stroke(Self.winBlack, lineWidth: 0.5)
            )
    }

    @ViewBuilder
    private func bevel3DTop() -> some View {
        Rectangle().fill(Self.winWhite).frame(height: 1)
    }

    @ViewBuilder
    private func bevel3DBottom() -> some View {
        Rectangle().fill(Self.winDarkGray).frame(height: 1)
    }

    // MARK: - About Dialog

    @ViewBuilder
    private var aboutDialog: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
                .onTapGesture { showAbout = false }

            VStack(spacing: 8) {
                Text("About Program Manager")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Self.winBlack)

                Rectangle().fill(Self.winDarkGray).frame(height: 1)

                VStack(spacing: 4) {
                    Text("Microsoft Windows")
                        .font(.system(size: 16, weight: .bold))
                    Text("Hiking Edition 3.1")
                        .font(.system(size: 12))
                    Text("Copyright © 1992-2026")
                        .font(.system(size: 10))
                        .foregroundStyle(Self.winDarkGray)
                }

                Rectangle().fill(Self.winDarkGray).frame(height: 1)

                let miles = Int(store.hikes.reduce(0) { $0 + $1.distanceMiles })
                VStack(spacing: 2) {
                    Text("Memory: \(store.hikes.count) hikes loaded")
                        .font(.system(size: 10, design: .monospaced))
                    Text("Disk: \(miles) trail miles available")
                        .font(.system(size: 10, design: .monospaced))
                    Text("System Resources: \(store.streakInfo.currentWeeks) week streak")
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(Self.winBlack)

                Button("OK") { showAbout = false }
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 80)
                    .buttonStyle(.bordered)
            }
            .padding(16)
            .frame(width: 320)
            .background(Self.winGray)
            .border(Self.winBlack, width: 2)
            .overlay(alignment: .topLeading) {
                Rectangle().fill(Self.winWhite).frame(width: 316, height: 1).offset(x: 2, y: 2)
            }
            .shadow(color: .black.opacity(0.5), radius: 0, x: 3, y: 3)
        }
    }

    // MARK: - Setup

    private func setupProgramManager() {
        // Main program group
        let mainGroup = Win31Window(
            title: "Main",
            position: CGPoint(x: 20, y: 50),
            size: CGSize(width: 400, height: 250),
            icons: [
                Win31Icon(name: "File Manager", emoji: "📁", action: "filemanager"),
                Win31Icon(name: "Hike Log", emoji: "🥾", action: "hikelog"),
                Win31Icon(name: "Trail Guide", emoji: "🗺️", action: "trailguide"),
                Win31Icon(name: "Statistics", emoji: "📊", action: "stats"),
                Win31Icon(name: "Notepad", emoji: "📝", action: "notepad"),
                Win31Icon(name: "Calculator", emoji: "🔢", action: "calc"),
                Win31Icon(name: "Write", emoji: "✍️", action: "write"),
                Win31Icon(name: "Paintbrush", emoji: "🎨", action: "paint"),
                Win31Icon(name: "Solitaire", emoji: "🃏", action: "sol"),
                Win31Icon(name: "Minesweeper", emoji: "💣", action: "mine"),
            ],
            textContent: nil
        )

        let accessories = Win31Window(
            title: "Accessories",
            position: CGPoint(x: 440, y: 80),
            size: CGSize(width: 350, height: 200),
            icons: [
                Win31Icon(name: "Clock", emoji: "🕐", action: "clock"),
                Win31Icon(name: "Terminal", emoji: "🖥️", action: "terminal"),
                Win31Icon(name: "Cardfile", emoji: "🗃️", action: "cardfile"),
                Win31Icon(name: "Calendar", emoji: "📅", action: "calendar"),
                Win31Icon(name: "Recorder", emoji: "🎙️", action: "recorder"),
            ],
            textContent: nil
        )

        windows = [mainGroup, accessories]
        windowOrder = windows.map(\.id)
    }

    // MARK: - Actions

    private func handleAction(_ action: String) {
        switch action {
        case "hikelog":
            openTextWindow(title: "Hike Log - Notepad", content: hikeLogContent())
        case "trailguide":
            openTextWindow(title: "Trail Guide - Write", content: trailGuideContent())
        case "stats":
            openTextWindow(title: "Statistics - Notepad", content: statsContent())
        case "notepad":
            openTextWindow(title: "Untitled - Notepad", content: [
                "Welcome to Windows 3.1 Hiking Edition!",
                "",
                "Double-click icons to open applications.",
                "Press ESC to return to the future.",
                "",
                "Tip: Try the Hike Log and Trail Guide!",
            ])
        default:
            openTextWindow(title: "\(action.capitalized) - Not Installed", content: [
                "This application is not available.",
                "",
                "Please insert Disk 7 of 14 to continue.",
                "",
                "A>: [Abort]  R>: [Retry]  F>: [Fail]",
            ])
        }
    }

    private func openTextWindow(title: String, content: [String]) {
        if windows.contains(where: { $0.title == title }) {
            if let w = windows.first(where: { $0.title == title }) { bringToFront(w.id) }
            return
        }
        let offset = CGFloat(windows.count) * 20
        let w = Win31Window(
            title: title,
            position: CGPoint(x: 60 + offset, y: 60 + offset),
            size: CGSize(width: 450, height: 300),
            icons: nil,
            textContent: content
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

    // MARK: - Content

    private func hikeLogContent() -> [String] {
        var lines = [
            "HIKE LOG",
            String(repeating: "=", count: 50),
            "",
            String(format: "%-12s %-6s %-6s %s", "DATE", "MILES", "ELEV", "TRAIL"),
            String(repeating: "-", count: 50),
        ]
        for h in store.hikes.prefix(30) {
            let mi = String(format: "%5.1f", h.distanceMiles)
            let el = String(format: "%5d", Int(h.elevationGainFt))
            lines.append("\(h.date)  \(mi)  \(el)  \(h.trailName.prefix(24))")
        }
        lines.append("")
        lines.append("\(store.hikes.count) records total")
        return lines
    }

    private func trailGuideContent() -> [String] {
        var lines = [
            "TRAIL GUIDE",
            String(repeating: "=", count: 50),
            "",
        ]
        let loved = trailStore.trails.filter { $0.lovedByShaun == true || $0.lovedByJulie == true }
        let trails = loved.isEmpty ? Array(trailStore.trails.prefix(20)) : loved
        for t in trails.sorted(by: { $0.name < $1.name }) {
            let mi = t.distanceMiles.map { String(format: "%.1f mi", $0) } ?? "  ? mi"
            let who = [t.lovedByShaun == true ? "♥S" : nil, t.lovedByJulie == true ? "♥J" : nil]
                .compactMap { $0 }.joined(separator: " ")
            lines.append("\(t.name.padding(toLength: 30, withPad: " ", startingAt: 0)) \(mi)  \(who)")
        }
        return lines
    }

    private func statsContent() -> [String] {
        let count = store.hikes.count
        let miles = String(format: "%.1f", store.hikes.reduce(0) { $0 + $1.distanceMiles })
        let elev = Int(store.hikes.reduce(0) { $0 + $1.elevationGainFt }).formatted()
        let streak = store.streakInfo.currentWeeks
        let trails = Set(store.hikes.map(\.trailName)).count
        let regions = Set(store.hikes.map(\.region)).count

        var lines = [
            "HIKING STATISTICS",
            String(repeating: "=", count: 40),
            "",
            "Total Hikes:      \(count)",
            "Total Miles:      \(miles)",
            "Total Elevation:  \(elev) ft",
            "Unique Trails:    \(trails)",
            "Regions Explored: \(regions)",
            "Current Streak:   \(streak) weeks",
            "Longest Streak:   \(store.streakInfo.longestWeeks) weeks",
            "",
            "TOP 10 TRAILS",
            String(repeating: "-", count: 40),
        ]
        for (i, t) in store.trailSummaries().prefix(10).enumerated() {
            lines.append(" \(i + 1). \(t.name) (\(t.count)x, \(String(format: "%.1f", t.avgMiles)) mi avg)")
        }
        return lines
    }
}

#endif
