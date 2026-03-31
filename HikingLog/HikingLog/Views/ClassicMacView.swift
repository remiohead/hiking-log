import SwiftUI

#if os(macOS)
import AppKit

// MARK: - Types

enum BootPhase {
    case black, happyMac, welcome, desktop
}

struct ClassicFileItem: Identifiable {
    let id = UUID()
    let name: String
    let kind: String
    let size: String
    let date: String
    let isFolder: Bool
    let openFolderID: String?
}

struct FinderWindowState: Identifiable {
    let id = UUID()
    var title: String
    var position: CGPoint
    var size: CGSize
    var items: [ClassicFileItem]
}

// MARK: - Classic Mac View

struct ClassicMacView: View {
    @Environment(HikeStore.self) private var store
    @Environment(TrailStore.self) private var trailStore

    @State private var bootPhase: BootPhase = .black
    @State private var activeMenu: String? = nil
    @State private var showAbout = false
    @State private var selectedDesktopIcon: String? = nil
    @State private var currentTime = Date()
    @State private var clockTimer: Timer?

    // Windows
    @State private var windows: [FinderWindowState] = []
    @State private var windowOrder: [UUID] = []
    @State private var dragStartPositions: [UUID: CGPoint] = [:]

    private let menuBarHeight: CGFloat = 26

    var body: some View {
        GeometryReader { geo in
            ZStack {
                switch bootPhase {
                case .black:
                    Color.black.ignoresSafeArea()
                case .happyMac:
                    Color.black.ignoresSafeArea()
                    HappyMacIcon()
                        .frame(width: 80, height: 100)
                case .welcome:
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 20) {
                        HappyMacIcon()
                            .frame(width: 80, height: 100)
                        Text("Welcome to Macintosh")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                case .desktop:
                    desktopView(in: geo)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.black)
        .onAppear {
            startBootSequence()
            startClock()
        }
        .onDisappear {
            clockTimer?.invalidate()
            clockTimer = nil
        }
    }

    // MARK: - Boot Sequence

    private func startBootSequence() {
        bootPhase = .black
        windows = []
        windowOrder = []
        showAbout = false
        activeMenu = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.3)) { bootPhase = .happyMac }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.3)) { bootPhase = .welcome }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeIn(duration: 0.4)) { bootPhase = .desktop }
            // Auto-open the Hiking HD window after boot
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                openFolder("root")
            }
        }
    }

    private func startClock() {
        clockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            currentTime = Date()
        }
    }

    // MARK: - Desktop View

    @ViewBuilder
    private func desktopView(in geo: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            // Desktop pattern background
            DesktopPatternView()
                .ignoresSafeArea()
                .onTapGesture {
                    activeMenu = nil
                    selectedDesktopIcon = nil
                }

            // Desktop icons
            desktopIcons(in: geo)

            // Open windows
            ForEach($windows) { $window in
                ClassicFinderWindowView(
                    window: window,
                    isActive: windowOrder.last == window.id,
                    onClose: { closeWindow(window.id) },
                    onBringToFront: { bringToFront(window.id); activeMenu = nil },
                    onDragChanged: { translation in
                        if dragStartPositions[window.id] == nil {
                            dragStartPositions[window.id] = window.position
                        }
                        if let start = dragStartPositions[window.id] {
                            window.position = CGPoint(
                                x: start.x + translation.width,
                                y: start.y + translation.height
                            )
                        }
                    },
                    onDragEnded: {
                        dragStartPositions[window.id] = nil
                    },
                    onOpenFolder: { folderID in openFolder(folderID) }
                )
                .zIndex(Double(windowOrder.firstIndex(of: window.id) ?? 0))
            }

            // About dialog
            if showAbout {
                ClassicAboutBox(
                    totalHikes: store.hikes.count,
                    totalMiles: store.hikes.reduce(0) { $0 + $1.distanceMiles },
                    totalTrails: Set(store.hikes.map(\.trailName)).count,
                    streakWeeks: store.streakInfo.currentWeeks,
                    onDismiss: { showAbout = false }
                )
                .zIndex(1000)
            }

            // Menu bar (always on top)
            VStack(spacing: 0) {
                ClassicMenuBarView(
                    activeMenu: $activeMenu,
                    currentTime: currentTime,
                    onAbout: { showAbout = true; activeMenu = nil },
                    onCloseWindow: { closeTopWindow() },
                    onCleanUp: {},
                    onReturnToModern: { exitFullScreen() }
                )
                Spacer()
            }
            .zIndex(2000)

            // CRT scanline effect
            CRTOverlay()
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(3000)
        }
    }

    // MARK: - Desktop Icons

    @ViewBuilder
    private func desktopIcons(in geo: GeometryProxy) -> some View {
        let iconSpacing: CGFloat = 90
        let rightMargin: CGFloat = 60
        let topMargin: CGFloat = menuBarHeight + 20

        // Hiking HD - top right
        ClassicDesktopIconView(
            name: "Hiking HD",
            iconType: .hardDrive,
            isSelected: selectedDesktopIcon == "hd",
            position: CGPoint(x: geo.size.width - rightMargin, y: topMargin + 30)
        ) {
            selectedDesktopIcon = "hd"
        } onDoubleClick: {
            openFolder("root")
        }

        // Hike Log - below HD
        ClassicDesktopIconView(
            name: "Hike Log",
            iconType: .folder,
            isSelected: selectedDesktopIcon == "hikelog",
            position: CGPoint(x: geo.size.width - rightMargin, y: topMargin + 30 + iconSpacing)
        ) {
            selectedDesktopIcon = "hikelog"
        } onDoubleClick: {
            openFolder("hikes")
        }

        // Trail Guide - below Hike Log
        ClassicDesktopIconView(
            name: "Trail Guide",
            iconType: .folder,
            isSelected: selectedDesktopIcon == "trails",
            position: CGPoint(x: geo.size.width - rightMargin, y: topMargin + 30 + iconSpacing * 2)
        ) {
            selectedDesktopIcon = "trails"
        } onDoubleClick: {
            openFolder("trails")
        }

        // Trash - bottom right
        ClassicDesktopIconView(
            name: "Trash",
            iconType: .trash,
            isSelected: selectedDesktopIcon == "trash",
            position: CGPoint(x: geo.size.width - rightMargin, y: geo.size.height - 60)
        ) {
            selectedDesktopIcon = "trash"
        } onDoubleClick: {}
    }

    // MARK: - Window Management

    private func openFolder(_ folderID: String) {
        // Don't open duplicates
        let title = windowTitle(for: folderID)
        if windows.contains(where: { $0.title == title }) {
            if let existing = windows.first(where: { $0.title == title }) {
                bringToFront(existing.id)
            }
            return
        }

        let items = folderItems(for: folderID)
        let offset = CGFloat(windows.count) * 26
        let newWindow = FinderWindowState(
            title: title,
            position: CGPoint(x: 40 + offset, y: menuBarHeight + 10 + offset),
            size: CGSize(width: 520, height: 320),
            items: items
        )
        windows.append(newWindow)
        windowOrder.append(newWindow.id)
        activeMenu = nil
    }

    private func windowTitle(for folderID: String) -> String {
        switch folderID {
        case "root": return "Hiking HD"
        case "hikes": return "Hike Log"
        case "trails": return "Trail Guide"
        case "system": return "System Folder"
        case "stats": return "Trail Stats"
        default: return folderID
        }
    }

    private func folderItems(for folderID: String) -> [ClassicFileItem] {
        switch folderID {
        case "root":
            return [
                ClassicFileItem(name: "System Folder", kind: "Folder", size: "--", date: "Jan 24, 1984", isFolder: true, openFolderID: "system"),
                ClassicFileItem(name: "Hike Log", kind: "Folder", size: "--", date: todayFormatted(), isFolder: true, openFolderID: "hikes"),
                ClassicFileItem(name: "Trail Guide", kind: "Folder", size: "--", date: todayFormatted(), isFolder: true, openFolderID: "trails"),
                ClassicFileItem(name: "Trail Stats", kind: "Folder", size: "--", date: todayFormatted(), isFolder: true, openFolderID: "stats"),
                ClassicFileItem(name: "Read Me", kind: "Document", size: "2K", date: "Jan 24, 1984", isFolder: false, openFolderID: nil),
            ]
        case "hikes":
            return recentHikeItems()
        case "trails":
            return favoriteTrailItems()
        case "system":
            return [
                ClassicFileItem(name: "Finder", kind: "Application", size: "184K", date: "Jan 24, 1984", isFolder: false, openFolderID: nil),
                ClassicFileItem(name: "Trail Matcher", kind: "Application", size: "96K", date: "Mar 15, 2024", isFolder: false, openFolderID: nil),
                ClassicFileItem(name: "GPS Toolkit", kind: "Application", size: "64K", date: "Jun 1, 2023", isFolder: false, openFolderID: nil),
                ClassicFileItem(name: "Elevation Calculator", kind: "DA", size: "12K", date: "Sep 20, 2022", isFolder: false, openFolderID: nil),
                ClassicFileItem(name: "Clipboard", kind: "DA", size: "8K", date: "Jan 24, 1984", isFolder: false, openFolderID: nil),
                ClassicFileItem(name: "Scrapbook", kind: "DA", size: "32K", date: "Jan 24, 1984", isFolder: false, openFolderID: nil),
            ]
        case "stats":
            return trailStatsItems()
        default:
            return []
        }
    }

    private func recentHikeItems() -> [ClassicFileItem] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d, yyyy"

        return Array(store.hikes.prefix(25)).map { hike in
            let displayDate: String
            if let d = dateFormatter.date(from: hike.date) {
                displayDate = displayFormatter.string(from: d)
            } else {
                displayDate = hike.date
            }
            return ClassicFileItem(
                name: "\(hike.trailName)",
                kind: "Hike",
                size: String(format: "%.1f mi", hike.distanceMiles),
                date: displayDate,
                isFolder: false,
                openFolderID: nil
            )
        }
    }

    private func favoriteTrailItems() -> [ClassicFileItem] {
        let lovedTrails = trailStore.trails.filter { $0.lovedByShaun == true || $0.lovedByJulie == true }
        let trails = lovedTrails.isEmpty ? Array(trailStore.trails.prefix(20)) : lovedTrails

        return trails.sorted(by: { $0.name < $1.name }).map { trail in
            let miles = trail.distanceMiles.map { String(format: "%.1f mi", $0) } ?? "--"
            return ClassicFileItem(
                name: trail.name,
                kind: "Trail",
                size: miles,
                date: trail.region,
                isFolder: false,
                openFolderID: nil
            )
        }
    }

    private func trailStatsItems() -> [ClassicFileItem] {
        let summaries = store.trailSummaries().prefix(20)
        return summaries.map { summary in
            ClassicFileItem(
                name: "\(summary.name) (\(summary.count)x)",
                kind: "Stats",
                size: String(format: "%.1f mi avg", summary.avgMiles),
                date: summary.region,
                isFolder: false,
                openFolderID: nil
            )
        }
    }

    private func todayFormatted() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: Date())
    }

    private func closeWindow(_ id: UUID) {
        windows.removeAll { $0.id == id }
        windowOrder.removeAll { $0 == id }
    }

    private func closeTopWindow() {
        guard let topID = windowOrder.last else { return }
        closeWindow(topID)
        activeMenu = nil
    }

    private func bringToFront(_ id: UUID) {
        windowOrder.removeAll { $0 == id }
        windowOrder.append(id)
    }

    private func exitFullScreen() {
        activeMenu = nil
        if let window = NSApplication.shared.keyWindow {
            window.toggleFullScreen(nil)
        }
    }
}

// MARK: - Desktop Pattern

struct DesktopPatternView: View {
    var body: some View {
        Canvas { context, size in
            // Fill white
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            // Draw classic Mac desktop pattern (fine grid dots)
            let step: CGFloat = 4
            for x in stride(from: 0, to: size.width, by: step) {
                for y in stride(from: 0, to: size.height, by: step) {
                    let shouldDraw = (Int(x / step) + Int(y / step)) % 2 == 0
                    if shouldDraw {
                        context.fill(
                            Path(CGRect(x: x, y: y, width: 1, height: 1)),
                            with: .color(.black)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Menu Bar

struct ClassicMenuBarView: View {
    @Binding var activeMenu: String?
    let currentTime: Date
    let onAbout: () -> Void
    let onCloseWindow: () -> Void
    let onCleanUp: () -> Void
    let onReturnToModern: () -> Void

    private let height: CGFloat = 26

    var body: some View {
        ZStack(alignment: .top) {
            // Menu bar background
            VStack(spacing: 0) {
                Rectangle()
                    .fill(.white)
                    .frame(height: height)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(.black).frame(height: 1)
                    }
            }

            // Menu items
            HStack(spacing: 0) {
                // Apple menu (U+F8FF is the Apple logo on macOS)
                classicMenuButton("\u{F8FF}", id: "apple", width: 34)
                classicMenuButton("File", id: "file")
                classicMenuButton("Edit", id: "edit")
                classicMenuButton("View", id: "view")
                classicMenuButton("Special", id: "special")

                Spacer()

                // Clock
                Text(timeString)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
            }
            .frame(height: height)

            // Dropdown menus
            if let menu = activeMenu {
                dropdownMenu(for: menu)
            }
        }
    }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: currentTime)
    }

    @ViewBuilder
    private func classicMenuButton(_ title: String, id: String, width: CGFloat? = nil) -> some View {
        let isActive = activeMenu == id
        Text(title)
            .font(.system(size: 14, weight: id == "apple" ? .bold : .regular))
            .foregroundStyle(isActive ? .white : .black)
            .padding(.horizontal, 10)
            .frame(width: width, height: height)
            .background(isActive ? Color.black : Color.clear)
            .onTapGesture {
                activeMenu = activeMenu == id ? nil : id
            }
            .onHover { hovering in
                if hovering && activeMenu != nil {
                    activeMenu = id
                }
            }
    }

    @ViewBuilder
    private func dropdownMenu(for menu: String) -> some View {
        let xOffset: CGFloat = {
            switch menu {
            case "apple": return 0
            case "file": return 30
            case "edit": return 30 + 46
            case "view": return 30 + 46 + 46
            case "special": return 30 + 46 + 46 + 52
            default: return 0
            }
        }()

        VStack(alignment: .leading, spacing: 0) {
            switch menu {
            case "apple":
                menuItem("About Hiking Finder...") { onAbout() }
                menuDivider()
                menuItemDisabled("Scrapbook")
                menuItemDisabled("Alarm Clock")
                menuItemDisabled("Calculator")
            case "file":
                menuItemDisabled("New Folder")
                menuItem("Open") { }
                menuItemDisabled("Print")
                menuDivider()
                menuItem("Close Window       \u{2318}W") { onCloseWindow() }
            case "edit":
                menuItem("Undo               \u{2318}Z") { }
                menuDivider()
                menuItem("Cut                \u{2318}X") { }
                menuItem("Copy               \u{2318}C") { }
                menuItem("Paste              \u{2318}V") { }
                menuItem("Clear") { }
            case "view":
                menuItem("by Icon") { }
                menuItem("by Name") { }
                menuItem("by Date") { }
                menuItem("by Size") { }
            case "special":
                menuItem("Clean Up Desktop") { onCleanUp() }
                menuItemDisabled("Empty Trash")
                menuDivider()
                menuItem("Return to 2026...") { onReturnToModern() }
            default:
                EmptyView()
            }
        }
        .frame(minWidth: 220)
        .background(
            Rectangle()
                .fill(.white)
                .border(.black, width: 1)
                .shadow(color: .black.opacity(0.4), radius: 0, x: 2, y: 2)
        )
        .padding(.top, height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, xOffset)
    }

    @ViewBuilder
    private func menuItem(_ title: String, action: @escaping () -> Void) -> some View {
        ClassicMenuItemView(title: title) {
            action()
            activeMenu = nil
        }
    }

    @ViewBuilder
    private func menuItemDisabled(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14))
            .foregroundStyle(.gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func menuDivider() -> some View {
        Rectangle()
            .fill(.black)
            .frame(height: 1)
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
    }
}

/// A menu item with classic Mac hover behavior: inverted text on black background
struct ClassicMenuItemView: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Text(title)
            .font(.system(size: 14))
            .foregroundStyle(isHovered ? .white : .black)
            .padding(.horizontal, 16)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? Color.black : Color.clear)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture { action() }
    }
}

// MARK: - Finder Window

struct ClassicFinderWindowView: View {
    let window: FinderWindowState
    let isActive: Bool
    let onClose: () -> Void
    let onBringToFront: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onOpenFolder: (String) -> Void

    private let titleBarHeight: CGFloat = 22
    private let scrollBarWidth: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            titleBar
            // Content area
            contentArea
        }
        .frame(width: window.size.width, height: window.size.height)
        .border(.black, width: 2)
        .background(.white)
        .shadow(color: .black.opacity(0.3), radius: 0, x: 3, y: 3)
        .position(x: window.position.x + window.size.width / 2,
                  y: window.position.y + window.size.height / 2)
        .onTapGesture { onBringToFront() }
    }

    @ViewBuilder
    private var titleBar: some View {
        ZStack {
            if isActive {
                // Active title bar: horizontal stripes
                Canvas { context, size in
                    for y in stride(from: 0, to: size.height, by: 2) {
                        context.fill(
                            Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                            with: .color(.black)
                        )
                    }
                }
            } else {
                Color.white
            }

            // Title text with white background
            Text(window.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .background(.white)

            // Close box
            HStack {
                closeBox
                    .padding(.leading, 6)
                Spacer()
            }
        }
        .frame(height: titleBarHeight)
        .clipped()
        .gesture(
            DragGesture()
                .onChanged { value in
                    onBringToFront()
                    onDragChanged(value.translation)
                }
                .onEnded { _ in
                    onDragEnded()
                }
        )
    }

    @ViewBuilder
    private var closeBox: some View {
        Rectangle()
            .fill(.white)
            .frame(width: 14, height: 14)
            .border(.black, width: 1)
            .onTapGesture { onClose() }
    }

    @ViewBuilder
    private var contentArea: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(.white)
            Rectangle().fill(.black).frame(height: 1) // top border

            VStack(spacing: 0) {
                // Column headers
                HStack(spacing: 0) {
                    Text("Name")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Size")
                        .frame(width: 80, alignment: .trailing)
                    Text("Kind")
                        .frame(width: 90, alignment: .leading)
                        .padding(.leading, 12)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)

                Rectangle().fill(.black).frame(height: 1)

                // File list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(window.items) { item in
                            fileRow(item)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            // Right scrollbar decoration
            HStack {
                Spacer()
                ClassicScrollBar()
                    .frame(width: scrollBarWidth)
            }
            .padding(.top, 22) // below header

            // Bottom scrollbar decoration
            VStack {
                Spacer()
                HStack {
                    ClassicScrollBarHorizontal()
                        .frame(height: scrollBarWidth)
                    // Grow box
                    Rectangle()
                        .fill(.white)
                        .frame(width: scrollBarWidth, height: scrollBarWidth)
                        .border(.black, width: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func fileRow(_ item: ClassicFileItem) -> some View {
        HStack(spacing: 0) {
            // Small icon
            smallIcon(for: item)
                .frame(width: 18, height: 14)
                .padding(.trailing, 4)

            Text(item.name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.size)
                .frame(width: 80, alignment: .trailing)

            Text(item.kind)
                .frame(width: 90, alignment: .leading)
                .padding(.leading, 12)
        }
        .font(.system(size: 12))
        .foregroundStyle(.black)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if let folderID = item.openFolderID {
                onOpenFolder(folderID)
            }
        }
    }

    @ViewBuilder
    private func smallIcon(for item: ClassicFileItem) -> some View {
        if item.isFolder {
            SmallFolderIcon()
        } else {
            SmallDocumentIcon()
        }
    }
}

// MARK: - Classic Scroll Bars (Decorative)

struct ClassicScrollBar: View {
    var body: some View {
        VStack(spacing: 0) {
            // Up arrow
            scrollArrow(pointingUp: true)
            // Track
            Rectangle()
                .fill(.white)
                .border(.black, width: 1)
            // Down arrow
            scrollArrow(pointingUp: false)
        }
        .background(.white)
        .overlay(
            Rectangle().stroke(.black, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func scrollArrow(pointingUp: Bool) -> some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var path = Path()
            if pointingUp {
                path.move(to: CGPoint(x: size.width / 2, y: 3))
                path.addLine(to: CGPoint(x: size.width - 3, y: size.height - 3))
                path.addLine(to: CGPoint(x: 3, y: size.height - 3))
            } else {
                path.move(to: CGPoint(x: size.width / 2, y: size.height - 3))
                path.addLine(to: CGPoint(x: size.width - 3, y: 3))
                path.addLine(to: CGPoint(x: 3, y: 3))
            }
            path.closeSubpath()
            context.fill(path, with: .color(.black))
        }
        .frame(height: 16)
        .border(.black, width: 1)
    }
}

struct ClassicScrollBarHorizontal: View {
    var body: some View {
        HStack(spacing: 0) {
            scrollArrow(pointingLeft: true)
            Rectangle()
                .fill(.white)
                .border(.black, width: 1)
            scrollArrow(pointingLeft: false)
        }
        .background(.white)
        .overlay(
            Rectangle().stroke(.black, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func scrollArrow(pointingLeft: Bool) -> some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var path = Path()
            if pointingLeft {
                path.move(to: CGPoint(x: 3, y: size.height / 2))
                path.addLine(to: CGPoint(x: size.width - 3, y: 3))
                path.addLine(to: CGPoint(x: size.width - 3, y: size.height - 3))
            } else {
                path.move(to: CGPoint(x: size.width - 3, y: size.height / 2))
                path.addLine(to: CGPoint(x: 3, y: 3))
                path.addLine(to: CGPoint(x: 3, y: size.height - 3))
            }
            path.closeSubpath()
            context.fill(path, with: .color(.black))
        }
        .frame(width: 16)
        .border(.black, width: 1)
    }
}

// MARK: - Desktop Icons

struct ClassicDesktopIconView: View {
    let name: String
    let iconType: IconType
    let isSelected: Bool
    let position: CGPoint
    let onClick: () -> Void
    let onDoubleClick: () -> Void

    enum IconType {
        case hardDrive, folder, document, trash
    }

    var body: some View {
        VStack(spacing: 2) {
            iconImage
                .frame(width: 48, height: 36)
            Text(name)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white : .black)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(isSelected ? Color.black : Color.clear)
                .lineLimit(1)
        }
        .position(position)
        .onTapGesture(count: 2) { onDoubleClick() }
        .onTapGesture(count: 1) { onClick() }
    }

    @ViewBuilder
    private var iconImage: some View {
        switch iconType {
        case .hardDrive:
            HardDriveIcon()
        case .folder:
            FolderIcon()
        case .document:
            DocumentIcon()
        case .trash:
            TrashIcon()
        }
    }
}

// MARK: - Pixel Art Icons

struct HappyMacIcon: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 24, size.height / 30)
            let xOff = (size.width - 24 * scale) / 2
            let yOff = (size.height - 30 * scale) / 2

            func px(_ x: Int, _ y: Int) {
                context.fill(
                    Path(CGRect(x: xOff + CGFloat(x) * scale, y: yOff + CGFloat(y) * scale, width: scale, height: scale)),
                    with: .color(.white)
                )
            }

            // Mac body outline (white on black)
            let bodyPath = Path(roundedRect: CGRect(x: xOff + 2 * scale, y: yOff, width: 20 * scale, height: 22 * scale), cornerRadius: 2 * scale)
            context.fill(bodyPath, with: .color(.white))

            // Screen area (black)
            let screenPath = Path(CGRect(x: xOff + 4 * scale, y: yOff + 2 * scale, width: 16 * scale, height: 12 * scale))
            context.fill(screenPath, with: .color(.black))

            // Happy face on screen (white)
            // Eyes
            px(8, 5); px(9, 5)
            px(14, 5); px(15, 5)
            px(8, 6); px(9, 6)
            px(14, 6); px(15, 6)

            // Smile
            px(8, 9)
            px(9, 10); px(10, 10); px(11, 10); px(12, 10); px(13, 10)
            px(14, 9)

            // Disk slot
            let slotPath = Path(CGRect(x: xOff + 8 * scale, y: yOff + 16 * scale, width: 8 * scale, height: 2 * scale))
            context.fill(slotPath, with: .color(.black))

            // Base
            let basePath = Path(CGRect(x: xOff + 4 * scale, y: yOff + 22 * scale, width: 16 * scale, height: 4 * scale))
            context.fill(basePath, with: .color(.white))
            let baseInner = Path(CGRect(x: xOff + 6 * scale, y: yOff + 23 * scale, width: 12 * scale, height: 2 * scale))
            context.fill(baseInner, with: .color(.black))

            // Foot
            let footPath = Path(CGRect(x: xOff + 1 * scale, y: yOff + 26 * scale, width: 22 * scale, height: 3 * scale))
            context.fill(footPath, with: .color(.white))
        }
    }
}

struct HardDriveIcon: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(x: 4, y: 2, width: size.width - 8, height: size.height - 4)
            // Main body
            context.fill(Path(rect), with: .color(.white))
            context.stroke(Path(rect), with: .color(.black), lineWidth: 2)
            // Lines on front
            for i in 0..<3 {
                let y = rect.minY + 8 + CGFloat(i) * 6
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: rect.minX + 4, y: y))
                        p.addLine(to: CGPoint(x: rect.maxX - 4, y: y))
                    },
                    with: .color(.black), lineWidth: 1
                )
            }
            // Light indicator
            context.fill(
                Path(CGRect(x: rect.maxX - 10, y: rect.maxY - 8, width: 4, height: 4)),
                with: .color(.black)
            )
        }
    }
}

struct FolderIcon: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            // Tab
            path.move(to: CGPoint(x: 2, y: 8))
            path.addLine(to: CGPoint(x: 2, y: 4))
            path.addLine(to: CGPoint(x: 18, y: 4))
            path.addLine(to: CGPoint(x: 22, y: 8))
            // Body
            path.addLine(to: CGPoint(x: size.width - 2, y: 8))
            path.addLine(to: CGPoint(x: size.width - 2, y: size.height - 2))
            path.addLine(to: CGPoint(x: 2, y: size.height - 2))
            path.closeSubpath()

            context.fill(path, with: .color(.white))
            context.stroke(path, with: .color(.black), lineWidth: 2)
            // Fold line
            context.stroke(
                Path { p in
                    p.move(to: CGPoint(x: 2, y: 12))
                    p.addLine(to: CGPoint(x: size.width - 2, y: 12))
                },
                with: .color(.black), lineWidth: 1
            )
        }
    }
}

struct DocumentIcon: View {
    var body: some View {
        Canvas { context, size in
            let foldSize: CGFloat = 8
            var path = Path()
            path.move(to: CGPoint(x: 8, y: 2))
            path.addLine(to: CGPoint(x: size.width - 8 - foldSize, y: 2))
            path.addLine(to: CGPoint(x: size.width - 8, y: 2 + foldSize))
            path.addLine(to: CGPoint(x: size.width - 8, y: size.height - 2))
            path.addLine(to: CGPoint(x: 8, y: size.height - 2))
            path.closeSubpath()

            context.fill(path, with: .color(.white))
            context.stroke(path, with: .color(.black), lineWidth: 1.5)

            // Dog ear fold
            var fold = Path()
            fold.move(to: CGPoint(x: size.width - 8 - foldSize, y: 2))
            fold.addLine(to: CGPoint(x: size.width - 8 - foldSize, y: 2 + foldSize))
            fold.addLine(to: CGPoint(x: size.width - 8, y: 2 + foldSize))
            context.stroke(fold, with: .color(.black), lineWidth: 1)

            // Text lines
            for i in 0..<3 {
                let y: CGFloat = 16 + CGFloat(i) * 5
                context.fill(
                    Path(CGRect(x: 12, y: y, width: size.width - 24, height: 1.5)),
                    with: .color(.black)
                )
            }
        }
    }
}

struct TrashIcon: View {
    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            // Lid
            context.fill(
                Path(CGRect(x: cx - 14, y: 2, width: 28, height: 4)),
                with: .color(.white)
            )
            context.stroke(
                Path(CGRect(x: cx - 14, y: 2, width: 28, height: 4)),
                with: .color(.black), lineWidth: 1.5
            )
            // Handle
            context.stroke(
                Path(CGRect(x: cx - 5, y: 0, width: 10, height: 3)),
                with: .color(.black), lineWidth: 1.5
            )
            // Body (trapezoid)
            var body = Path()
            body.move(to: CGPoint(x: cx - 12, y: 6))
            body.addLine(to: CGPoint(x: cx + 12, y: 6))
            body.addLine(to: CGPoint(x: cx + 10, y: size.height - 2))
            body.addLine(to: CGPoint(x: cx - 10, y: size.height - 2))
            body.closeSubpath()
            context.fill(body, with: .color(.white))
            context.stroke(body, with: .color(.black), lineWidth: 1.5)
            // Vertical lines on body
            for offset: CGFloat in [-5, 0, 5] {
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: cx + offset, y: 9))
                        p.addLine(to: CGPoint(x: cx + offset, y: size.height - 5))
                    },
                    with: .color(.black), lineWidth: 1
                )
            }
        }
    }
}

// Small icons for list view

struct SmallFolderIcon: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 1, y: 4))
            path.addLine(to: CGPoint(x: 1, y: 2))
            path.addLine(to: CGPoint(x: 7, y: 2))
            path.addLine(to: CGPoint(x: 9, y: 4))
            path.addLine(to: CGPoint(x: size.width - 1, y: 4))
            path.addLine(to: CGPoint(x: size.width - 1, y: size.height - 1))
            path.addLine(to: CGPoint(x: 1, y: size.height - 1))
            path.closeSubpath()
            context.fill(path, with: .color(.white))
            context.stroke(path, with: .color(.black), lineWidth: 1)
        }
    }
}

struct SmallDocumentIcon: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 3, y: 1))
            path.addLine(to: CGPoint(x: size.width - 6, y: 1))
            path.addLine(to: CGPoint(x: size.width - 3, y: 4))
            path.addLine(to: CGPoint(x: size.width - 3, y: size.height - 1))
            path.addLine(to: CGPoint(x: 3, y: size.height - 1))
            path.closeSubpath()
            context.fill(path, with: .color(.white))
            context.stroke(path, with: .color(.black), lineWidth: 1)
        }
    }
}

// MARK: - About Box

struct ClassicAboutBox: View {
    let totalHikes: Int
    let totalMiles: Double
    let totalTrails: Int
    let streakWeeks: Int
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Dimming background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Dialog
            VStack(spacing: 12) {
                HappyMacIcon()
                    .frame(width: 50, height: 62)
                    .padding(.top, 8)

                Text("Hiking Finder")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)

                Text("Version 1984.0")
                    .font(.system(size: 12))
                    .foregroundStyle(.black)

                Rectangle().fill(.black).frame(height: 1).padding(.horizontal, 20)

                VStack(spacing: 4) {
                    statLine("Total Hikes", value: "\(totalHikes)")
                    statLine("Miles Logged", value: String(format: "%.0f", totalMiles))
                    statLine("Trails Explored", value: "\(totalTrails)")
                    statLine("Current Streak", value: "\(streakWeeks) weeks")
                }

                Rectangle().fill(.black).frame(height: 1).padding(.horizontal, 20)

                Text("\u{00A9} 1984-2026 Trail Computing, Inc.")
                    .font(.system(size: 10))
                    .foregroundStyle(.black)

                // OK button
                Button(action: onDismiss) {
                    Text("OK")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 80, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.black, lineWidth: 2)
                                .background(RoundedRectangle(cornerRadius: 6).fill(.white))
                        )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
            }
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.black, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 0, x: 4, y: 4)
            )
        }
    }

    @ViewBuilder
    private func statLine(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .frame(width: 100, alignment: .leading)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - CRT Overlay

struct CRTOverlay: View {
    var body: some View {
        Canvas { context, size in
            // Subtle scanlines
            for y in stride(from: 0, to: size.height, by: 3) {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(.black.opacity(0.04))
                )
            }
            // Vignette corners
            let gradient = Gradient(colors: [
                .black.opacity(0.15),
                .black.opacity(0.0),
            ])
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxDim = max(size.width, size.height)
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    gradient,
                    center: center,
                    startRadius: maxDim * 0.35,
                    endRadius: maxDim * 0.75
                )
            )
        }
    }
}

#endif
