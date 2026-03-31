import SwiftUI

#if os(macOS)

// MARK: - NES "The Legend of Hiking" - Zelda-style Adventure

struct NESView: View {
    @Environment(HikeStore.self) private var store
    @Environment(TrailStore.self) private var trailStore

    let onExit: () -> Void

    // Game state
    @State private var playerX: Int = 7
    @State private var playerY: Int = 5
    @State private var playerDir: Int = 2 // 0=up,1=right,2=down,3=left
    @State private var frame: Int = 0
    @State private var gameTimer: Timer?
    @State private var currentRoom: Int = 0
    @State private var roomsVisited: Set<Int> = [0]
    @State private var showingTitle: Bool = true
    @State private var titleBlink: Bool = true
    @State private var itemsCollected: Int = 0
    @State private var showMessage: String? = nil
    @State private var messageTimer: Int = 0
    @FocusState private var isFocused: Bool

    // NES resolution: 256x240, we use a 16x14 tile grid (below 2-row HUD)
    private let tileSize = 16
    private let gridW = 16
    private let gridH = 12 // playfield rows (below HUD)
    private let hudRows = 2

    // NES color palette
    static let nesBlack = Color(red: 0.0, green: 0.0, blue: 0.0)
    static let nesWhite = Color(red: 0.93, green: 0.93, blue: 0.93)
    static let nesGreen = Color(red: 0.0, green: 0.53, blue: 0.0)
    static let nesLightGreen = Color(red: 0.47, green: 0.73, blue: 0.0)
    static let nesDarkGreen = Color(red: 0.0, green: 0.33, blue: 0.0)
    static let nesBrown = Color(red: 0.53, green: 0.33, blue: 0.13)
    static let nesDarkBrown = Color(red: 0.33, green: 0.20, blue: 0.07)
    static let nesBlue = Color(red: 0.20, green: 0.40, blue: 0.87)
    static let nesLightBlue = Color(red: 0.40, green: 0.60, blue: 1.0)
    static let nesRed = Color(red: 0.80, green: 0.13, blue: 0.13)
    static let nesOrange = Color(red: 0.93, green: 0.53, blue: 0.13)
    static let nesTan = Color(red: 0.87, green: 0.73, blue: 0.53)
    static let nesGrey = Color(red: 0.47, green: 0.47, blue: 0.47)
    static let nesDarkGrey = Color(red: 0.27, green: 0.27, blue: 0.27)

    // Tile types
    enum Tile: Int {
        case grass = 0, path, tree, rock, water, bridge, bush, flower,
             exitN, exitE, exitS, exitW, item, chest, signpost
    }

    var body: some View {
        GeometryReader { geo in
            let px = floor(min(geo.size.width / 256, geo.size.height / 240))
            let screenW = px * 256
            let screenH = px * 240

            ZStack {
                Color.black

                if showingTitle {
                    titleScreen(px: px, screenW: screenW, screenH: screenH)
                } else {
                    Canvas { context, size in
                        drawHUD(context: &context, px: px)
                        drawRoom(context: &context, px: px)
                        drawPlayer(context: &context, px: px)
                        if let msg = showMessage {
                            drawMessage(context: &context, px: px, text: msg)
                        }
                    }
                    .frame(width: screenW, height: screenH)

                    // NES scanline overlay
                    Canvas { context, size in
                        for y in stride(from: 0, to: size.height, by: px * 2) {
                            context.fill(
                                Path(CGRect(x: 0, y: y + px, width: size.width, height: px * 0.4)),
                                with: .color(.black.opacity(0.15))
                            )
                        }
                    }
                    .frame(width: screenW, height: screenH)
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.black)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(keys: [.upArrow], phases: [.down, .repeat]) { _ in
            if showingTitle { showingTitle = false; return .handled }
            movePlayer(dx: 0, dy: -1, dir: 0); return .handled
        }
        .onKeyPress(keys: [.downArrow], phases: [.down, .repeat]) { _ in
            if showingTitle { showingTitle = false; return .handled }
            movePlayer(dx: 0, dy: 1, dir: 2); return .handled
        }
        .onKeyPress(keys: [.leftArrow], phases: [.down, .repeat]) { _ in
            if showingTitle { showingTitle = false; return .handled }
            movePlayer(dx: -1, dy: 0, dir: 3); return .handled
        }
        .onKeyPress(keys: [.rightArrow], phases: [.down, .repeat]) { _ in
            if showingTitle { showingTitle = false; return .handled }
            movePlayer(dx: 1, dy: 0, dir: 1); return .handled
        }
        .onKeyPress(.escape) {
            onExit(); return .handled
        }
        .onKeyPress(.return) {
            if showingTitle { showingTitle = false }
            return .handled
        }
        .onAppear {
            isFocused = true
            gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15, repeats: true) { _ in
                frame += 1
                if messageTimer > 0 {
                    messageTimer -= 1
                    if messageTimer == 0 { showMessage = nil }
                }
            }
        }
        .onDisappear { gameTimer?.invalidate() }
    }

    // MARK: - Title Screen

    @ViewBuilder
    private func titleScreen(px: CGFloat, screenW: CGFloat, screenH: CGFloat) -> some View {
        Canvas { context, size in
            // Black background
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

            // Mountain silhouette
            let mtns: [(x: CGFloat, h: CGFloat)] = [
                (30, 60), (60, 45), (90, 70), (120, 50), (150, 65),
                (180, 40), (210, 55), (240, 48),
            ]
            for m in mtns {
                var path = Path()
                path.move(to: CGPoint(x: (m.x - 20) * px, y: 160 * px))
                path.addLine(to: CGPoint(x: m.x * px, y: (160 - m.h) * px))
                path.addLine(to: CGPoint(x: (m.x + 20) * px, y: 160 * px))
                path.closeSubpath()
                context.fill(path, with: .color(Self.nesDarkGreen))
            }
            // Ground line
            context.fill(Path(CGRect(x: 0, y: 160 * px, width: 256 * px, height: 80 * px)), with: .color(Self.nesDarkGreen))

            // Title
            let title = context.resolve(
                Text("THE LEGEND OF HIKING")
                    .font(.system(size: px * 14, weight: .black, design: .monospaced))
                    .foregroundColor(Self.nesOrange)
            )
            context.draw(title, at: CGPoint(x: 128 * px, y: 50 * px), anchor: .center)

            // Subtitle
            let sub = context.resolve(
                Text("A Trail Adventure")
                    .font(.system(size: px * 7, weight: .bold, design: .monospaced))
                    .foregroundColor(Self.nesWhite)
            )
            context.draw(sub, at: CGPoint(x: 128 * px, y: 75 * px), anchor: .center)

            // Decorative sword... er, trekking pole
            let poleX: CGFloat = 128
            context.fill(Path(CGRect(x: (poleX - 1) * px, y: 90 * px, width: 2 * px, height: 40 * px)),
                         with: .color(Self.nesTan))
            context.fill(Path(CGRect(x: (poleX - 4) * px, y: 92 * px, width: 8 * px, height: 2 * px)),
                         with: .color(Self.nesGrey))

            // Stats
            let statsY: CGFloat = 170
            let stats = [
                "\(store.hikes.count) HIKES LOGGED",
                "\(Int(store.hikes.reduce(0) { $0 + $1.distanceMiles })) MILES CONQUERED",
                "\(Set(store.hikes.map(\.trailName)).count) TRAILS DISCOVERED",
            ]
            for (i, s) in stats.enumerated() {
                let t = context.resolve(
                    Text(s)
                        .font(.system(size: px * 5, weight: .bold, design: .monospaced))
                        .foregroundColor(Self.nesLightGreen)
                )
                context.draw(t, at: CGPoint(x: 128 * px, y: (statsY + CGFloat(i) * 12) * px), anchor: .center)
            }

            // Blinking prompt
            if frame % 30 < 20 {
                let prompt = context.resolve(
                    Text("- PRESS ANY KEY -")
                        .font(.system(size: px * 6, weight: .bold, design: .monospaced))
                        .foregroundColor(Self.nesWhite)
                )
                context.draw(prompt, at: CGPoint(x: 128 * px, y: 215 * px), anchor: .center)
            }
        }
        .frame(width: screenW, height: screenH)
    }

    // MARK: - HUD

    private func drawHUD(context: inout GraphicsContext, px: CGFloat) {
        let hudH = CGFloat(hudRows * tileSize)
        // Black HUD background
        context.fill(Path(CGRect(x: 0, y: 0, width: 256 * px, height: hudH * px)), with: .color(.black))

        // Hearts (streak weeks, max 10)
        let hearts = min(10, store.streakInfo.currentWeeks)
        for i in 0..<hearts {
            let hx = CGFloat(8 + i * 10)
            drawHeart(context: &context, px: px, x: hx, y: 4)
        }

        // Labels
        let lifeLabel = context.resolve(
            Text("-LIFE-")
                .font(.system(size: px * 5, weight: .bold, design: .monospaced))
                .foregroundColor(Self.nesRed)
        )
        context.draw(lifeLabel, at: CGPoint(x: 8 * px, y: 16 * px), anchor: .topLeading)

        // Rupees = miles
        let miles = Int(store.hikes.reduce(0) { $0 + $1.distanceMiles })
        let rupee = context.resolve(
            Text("MILES:\(miles)")
                .font(.system(size: px * 5, weight: .bold, design: .monospaced))
                .foregroundColor(Self.nesLightGreen)
        )
        context.draw(rupee, at: CGPoint(x: 130 * px, y: 4 * px), anchor: .topLeading)

        // Keys = trails visited
        let keys = context.resolve(
            Text("TRAILS:\(roomsVisited.count)")
                .font(.system(size: px * 5, weight: .bold, design: .monospaced))
                .foregroundColor(Self.nesOrange)
        )
        context.draw(keys, at: CGPoint(x: 130 * px, y: 16 * px), anchor: .topLeading)

        // Items
        let items = context.resolve(
            Text("ITEMS:\(itemsCollected)")
                .font(.system(size: px * 5, weight: .bold, design: .monospaced))
                .foregroundColor(Self.nesWhite)
        )
        context.draw(items, at: CGPoint(x: 210 * px, y: 4 * px), anchor: .topLeading)

        // Separator
        context.fill(Path(CGRect(x: 0, y: (hudH - 1) * px, width: 256 * px, height: px)),
                     with: .color(Self.nesWhite))
    }

    private func drawHeart(context: inout GraphicsContext, px: CGFloat, x: CGFloat, y: CGFloat) {
        // Tiny pixel heart
        let heart: [(Int, Int)] = [
            (1,0),(2,0),(4,0),(5,0),
            (0,1),(1,1),(2,1),(3,1),(4,1),(5,1),(6,1),
            (0,2),(1,2),(2,2),(3,2),(4,2),(5,2),(6,2),
            (1,3),(2,3),(3,3),(4,3),(5,3),
            (2,4),(3,4),(4,4),
            (3,5),
        ]
        for (dx, dy) in heart {
            context.fill(
                Path(CGRect(x: (x + CGFloat(dx)) * px, y: (y + CGFloat(dy)) * px, width: px, height: px)),
                with: .color(Self.nesRed)
            )
        }
    }

    // MARK: - Room Generation & Drawing

    private func drawRoom(context: inout GraphicsContext, px: CGFloat) {
        let offsetY = CGFloat(hudRows * tileSize)
        let map = generateRoom(index: currentRoom)

        for row in 0..<gridH {
            for col in 0..<gridW {
                let tile = map[row][col]
                let x = CGFloat(col * tileSize)
                let y = offsetY + CGFloat(row * tileSize)
                drawTile(context: &context, px: px, tile: tile, x: x, y: y, row: row, col: col)
            }
        }
    }

    private func drawTile(context: inout GraphicsContext, px: CGFloat, tile: Tile,
                          x: CGFloat, y: CGFloat, row: Int, col: Int) {
        let rect = CGRect(x: x * px, y: y * px, width: CGFloat(tileSize) * px, height: CGFloat(tileSize) * px)

        switch tile {
        case .grass:
            context.fill(Path(rect), with: .color(Self.nesGreen))
            // Grass detail
            if (row + col + currentRoom) % 3 == 0 {
                context.fill(Path(CGRect(x: (x + 3) * px, y: (y + 6) * px, width: 2 * px, height: 2 * px)),
                             with: .color(Self.nesLightGreen))
            }
        case .path:
            context.fill(Path(rect), with: .color(Self.nesTan))
            // Path texture
            if (row + col) % 4 == 0 {
                context.fill(Path(CGRect(x: (x + 5) * px, y: (y + 5) * px, width: 2 * px, height: 2 * px)),
                             with: .color(Self.nesBrown))
            }
        case .tree:
            context.fill(Path(rect), with: .color(Self.nesGreen))
            // Tree trunk
            context.fill(Path(CGRect(x: (x + 6) * px, y: (y + 10) * px, width: 4 * px, height: 6 * px)),
                         with: .color(Self.nesBrown))
            // Canopy (diamond)
            let cx = x + 8, cy = y + 3
            for dy in 0..<8 {
                let w = dy < 4 ? (dy + 1) * 2 : (8 - dy) * 2
                let ox = cx - CGFloat(w / 2)
                context.fill(Path(CGRect(x: ox * px, y: (cy + CGFloat(dy)) * px, width: CGFloat(w) * px, height: px)),
                             with: .color(Self.nesDarkGreen))
            }
        case .rock:
            context.fill(Path(rect), with: .color(Self.nesGreen))
            let rockRect = CGRect(x: (x + 2) * px, y: (y + 3) * px, width: 12 * px, height: 10 * px)
            context.fill(Path(rockRect), with: .color(Self.nesGrey))
            context.stroke(Path(rockRect), with: .color(Self.nesDarkGrey), lineWidth: px)
        case .water:
            let waterColor = (frame / 8 + row + col) % 2 == 0 ? Self.nesBlue : Self.nesLightBlue
            context.fill(Path(rect), with: .color(waterColor))
        case .bridge:
            context.fill(Path(rect), with: .color(Self.nesBlue))
            context.fill(Path(CGRect(x: (x + 2) * px, y: y * px, width: 12 * px, height: CGFloat(tileSize) * px)),
                         with: .color(Self.nesBrown))
            // Planks
            for py in stride(from: 0, to: tileSize, by: 4) {
                context.fill(Path(CGRect(x: (x + 2) * px, y: (y + CGFloat(py)) * px, width: 12 * px, height: px)),
                             with: .color(Self.nesDarkBrown))
            }
        case .bush:
            context.fill(Path(rect), with: .color(Self.nesGreen))
            context.fill(Path(CGRect(x: (x + 2) * px, y: (y + 4) * px, width: 12 * px, height: 8 * px)),
                         with: .color(Self.nesDarkGreen))
            context.fill(Path(CGRect(x: (x + 4) * px, y: (y + 2) * px, width: 8 * px, height: 4 * px)),
                         with: .color(Self.nesDarkGreen))
        case .flower:
            context.fill(Path(rect), with: .color(Self.nesGreen))
            let flowerColor = (col % 3 == 0) ? Self.nesRed : (col % 3 == 1 ? Self.nesOrange : Self.nesWhite)
            context.fill(Path(CGRect(x: (x + 6) * px, y: (y + 6) * px, width: 4 * px, height: 4 * px)),
                         with: .color(flowerColor))
            context.fill(Path(CGRect(x: (x + 7) * px, y: (y + 5) * px, width: 2 * px, height: px)),
                         with: .color(flowerColor))
            context.fill(Path(CGRect(x: (x + 7) * px, y: (y + 10) * px, width: 2 * px, height: 3 * px)),
                         with: .color(Self.nesDarkGreen))
        case .exitN, .exitE, .exitS, .exitW:
            context.fill(Path(rect), with: .color(Self.nesTan))
        case .item:
            context.fill(Path(rect), with: .color(Self.nesGreen))
            // Blinking item
            if frame % 20 < 14 {
                // Diamond shape
                let ix = x + 4, iy = y + 2
                for dy in 0..<6 {
                    let w = dy < 3 ? (dy + 1) * 2 : (6 - dy) * 2
                    context.fill(
                        Path(CGRect(x: (ix + CGFloat(3 - min(dy, 5 - dy))) * px, y: (iy + CGFloat(dy) * 2) * px,
                                    width: CGFloat(w) * px, height: 2 * px)),
                        with: .color(Self.nesOrange)
                    )
                }
            }
        case .chest:
            context.fill(Path(rect), with: .color(Self.nesGreen))
            let chestRect = CGRect(x: (x + 3) * px, y: (y + 5) * px, width: 10 * px, height: 8 * px)
            context.fill(Path(chestRect), with: .color(Self.nesBrown))
            context.stroke(Path(chestRect), with: .color(Self.nesDarkBrown), lineWidth: px)
            context.fill(Path(CGRect(x: (x + 7) * px, y: (y + 8) * px, width: 2 * px, height: 2 * px)),
                         with: .color(Self.nesOrange))
        case .signpost:
            context.fill(Path(rect), with: .color(Self.nesGreen))
            // Post
            context.fill(Path(CGRect(x: (x + 7) * px, y: (y + 6) * px, width: 2 * px, height: 10 * px)),
                         with: .color(Self.nesBrown))
            // Sign
            context.fill(Path(CGRect(x: (x + 2) * px, y: (y + 3) * px, width: 12 * px, height: 5 * px)),
                         with: .color(Self.nesTan))
            context.stroke(Path(CGRect(x: (x + 2) * px, y: (y + 3) * px, width: 12 * px, height: 5 * px)),
                           with: .color(Self.nesDarkBrown), lineWidth: px * 0.5)
        }
    }

    // MARK: - Room Map Generation

    private func generateRoom(index: Int) -> [[Tile]] {
        let summaries = store.trailSummaries()
        guard !summaries.isEmpty else { return Array(repeating: Array(repeating: .grass, count: gridW), count: gridH) }
        let trail = summaries[index % summaries.count]
        let seed = index &* 2654435761 // Knuth multiplicative hash

        var map = Array(repeating: Array(repeating: Tile.grass, count: gridW), count: gridH)

        // Path through the middle (varies by trail)
        let pathY = 4 + (seed >> 4) % 4
        for x in 0..<gridW {
            let wobble = (seed >> 8 + x * 3) % 3 == 0 ? 1 : 0
            let py = pathY + wobble
            if py < gridH { map[py][x] = .path }
            if py + 1 < gridH { map[py + 1][x] = .path }
        }

        // Exits
        map[pathY][0] = .exitW
        map[pathY][gridW - 1] = .exitE
        if index > 0 { map[0][gridW / 2] = .exitN }
        map[gridH - 1][gridW / 2] = .exitS

        // Trees (more trees for higher elevation trails)
        let treeCount = min(20, max(5, Int(Double(trail.avgElevation) / 200)))
        for i in 0..<treeCount {
            let tx = (seed >> (i * 3 + 2)) % gridW
            let ty = (seed >> (i * 5 + 1)) % gridH
            if map[ty][tx] == .grass { map[ty][tx] = .tree }
        }

        // Rocks
        let rockCount = (seed >> 12) % 4 + 1
        for i in 0..<rockCount {
            let rx = (seed >> (i * 7 + 4)) % gridW
            let ry = (seed >> (i * 4 + 6)) % gridH
            if map[ry][rx] == .grass { map[ry][rx] = .rock }
        }

        // Water feature (some trails)
        if trail.avgElevation > 1500 || index % 4 == 2 {
            let wy = min(gridH - 2, pathY + 3)
            for wx in 2..<6 {
                if map[wy][wx] == .grass { map[wy][wx] = .water }
            }
            map[wy][3] = .bridge
        }

        // Flowers and bushes
        for i in 0..<4 {
            let fx = (seed >> (i * 6 + 8)) % gridW
            let fy = (seed >> (i * 4 + 3)) % gridH
            if map[fy][fx] == .grass { map[fy][fx] = (i % 2 == 0) ? .flower : .bush }
        }

        // Items to collect
        let itemX = (seed >> 15) % (gridW - 4) + 2
        let itemY = (seed >> 18) % (gridH - 4) + 2
        if map[itemY][itemX] == .grass { map[itemY][itemX] = .item }

        // Signpost near start
        if map[pathY - 1][2] == .grass { map[pathY - 1][2] = .signpost }

        return map
    }

    // MARK: - Player

    private func drawPlayer(context: inout GraphicsContext, px: CGFloat) {
        let offsetY = CGFloat(hudRows * tileSize)
        let x = CGFloat(playerX * tileSize)
        let y = offsetY + CGFloat(playerY * tileSize)
        let walkFrame = (frame / 4) % 2

        // Green tunic hiker (Link-inspired)
        // Body
        let bodyColor = Self.nesGreen
        let skinColor = Self.nesTan
        let bootColor = Self.nesBrown

        // Head
        context.fill(Path(CGRect(x: (x + 4) * px, y: (y + 1) * px, width: 8 * px, height: 6 * px)),
                     with: .color(skinColor))
        // Hair
        context.fill(Path(CGRect(x: (x + 4) * px, y: (y + 0) * px, width: 8 * px, height: 3 * px)),
                     with: .color(Self.nesBrown))
        // Eyes
        context.fill(Path(CGRect(x: (x + 5) * px, y: (y + 3) * px, width: 2 * px, height: 2 * px)),
                     with: .color(Self.nesBlack))
        context.fill(Path(CGRect(x: (x + 9) * px, y: (y + 3) * px, width: 2 * px, height: 2 * px)),
                     with: .color(Self.nesBlack))
        // Body (tunic)
        context.fill(Path(CGRect(x: (x + 3) * px, y: (y + 7) * px, width: 10 * px, height: 5 * px)),
                     with: .color(bodyColor))
        // Belt
        context.fill(Path(CGRect(x: (x + 3) * px, y: (y + 9) * px, width: 10 * px, height: 2 * px)),
                     with: .color(Self.nesDarkBrown))
        // Legs/boots
        if walkFrame == 0 {
            context.fill(Path(CGRect(x: (x + 4) * px, y: (y + 12) * px, width: 3 * px, height: 4 * px)),
                         with: .color(bootColor))
            context.fill(Path(CGRect(x: (x + 9) * px, y: (y + 12) * px, width: 3 * px, height: 4 * px)),
                         with: .color(bootColor))
        } else {
            context.fill(Path(CGRect(x: (x + 3) * px, y: (y + 12) * px, width: 3 * px, height: 4 * px)),
                         with: .color(bootColor))
            context.fill(Path(CGRect(x: (x + 10) * px, y: (y + 12) * px, width: 3 * px, height: 4 * px)),
                         with: .color(bootColor))
        }
        // Backpack
        context.fill(Path(CGRect(x: (x + 12) * px, y: (y + 6) * px, width: 3 * px, height: 5 * px)),
                     with: .color(Self.nesDarkBrown))
    }

    private func drawMessage(context: inout GraphicsContext, px: CGFloat, text: String) {
        // Message box at bottom of screen
        let boxY: CGFloat = 200
        context.fill(Path(CGRect(x: 16 * px, y: boxY * px, width: 224 * px, height: 30 * px)),
                     with: .color(.black))
        context.stroke(Path(CGRect(x: 16 * px, y: boxY * px, width: 224 * px, height: 30 * px)),
                       with: .color(Self.nesWhite), lineWidth: px)
        let resolved = context.resolve(
            Text(text)
                .font(.system(size: px * 5, weight: .bold, design: .monospaced))
                .foregroundColor(Self.nesWhite)
        )
        context.draw(resolved, at: CGPoint(x: 24 * px, y: (boxY + 6) * px), anchor: .topLeading)
    }

    // MARK: - Movement

    private func movePlayer(dx: Int, dy: Int, dir: Int) {
        playerDir = dir
        let newX = playerX + dx
        let newY = playerY + dy
        let map = generateRoom(index: currentRoom)
        let summaries = store.trailSummaries()

        // Check room transitions
        if newY < 0 && currentRoom > 0 {
            currentRoom -= 1; roomsVisited.insert(currentRoom)
            playerY = gridH - 2; showTrailMessage(); return
        }
        if newY >= gridH {
            currentRoom = (currentRoom + 1) % max(1, summaries.count)
            roomsVisited.insert(currentRoom)
            playerY = 1; showTrailMessage(); return
        }
        if newX < 0 {
            currentRoom = (currentRoom - 1 + max(1, summaries.count)) % max(1, summaries.count)
            roomsVisited.insert(currentRoom)
            playerX = gridW - 2; showTrailMessage(); return
        }
        if newX >= gridW {
            currentRoom = (currentRoom + 1) % max(1, summaries.count)
            roomsVisited.insert(currentRoom)
            playerX = 1; showTrailMessage(); return
        }

        // Check tile passability
        guard newX >= 0, newX < gridW, newY >= 0, newY < gridH else { return }
        let tile = map[newY][newX]
        switch tile {
        case .tree, .rock, .water, .bush:
            return // blocked
        case .item:
            itemsCollected += 1
            showMessage = "GOT TRAIL MARKER! (\(itemsCollected))"
            messageTimer = 45
            playerX = newX; playerY = newY
        case .signpost:
            let trail = summaries.isEmpty ? nil : summaries[currentRoom % summaries.count]
            showMessage = trail.map { "\($0.name.uppercased().prefix(30))" } ?? "UNKNOWN TRAIL"
            messageTimer = 60
        case .chest:
            showMessage = "FOUND HIKING GEAR!"
            messageTimer = 45
            itemsCollected += 3
        default:
            playerX = newX; playerY = newY
        }
    }

    private func showTrailMessage() {
        let summaries = store.trailSummaries()
        guard !summaries.isEmpty else { return }
        let trail = summaries[currentRoom % summaries.count]
        showMessage = "~ \(trail.name.uppercased().prefix(28)) ~"
        messageTimer = 60
    }
}

#endif
