import SwiftUI

#if os(macOS)

// MARK: - Original Game Boy - "Pocket Hiking"

struct GameBoyView: View {
    @Environment(HikeStore.self) private var store
    @Environment(TrailStore.self) private var trailStore

    let onExit: () -> Void

    @State private var playerX: Int = 5
    @State private var playerY: Int = 4
    @State private var currentRoom: Int = 0
    @State private var roomsVisited: Set<Int> = [0]
    @State private var frame: Int = 0
    @State private var gameTimer: Timer?
    @State private var showTitle: Bool = true
    @State private var showStats: Bool = false
    @State private var showMessage: String? = nil
    @State private var messageTimer: Int = 0
    @State private var itemsFound: Int = 0
    @FocusState private var isFocused: Bool

    // Game Boy: 160x144 pixels, 4 shades of green
    private let vW = 160
    private let vH = 144
    private let gridW = 10  // 16px tiles
    private let gridH = 9

    // DMG palette
    static let lightest = Color(red: 0.61, green: 0.74, blue: 0.06)
    static let light    = Color(red: 0.55, green: 0.67, blue: 0.06)
    static let dark     = Color(red: 0.19, green: 0.38, blue: 0.19)
    static let darkest  = Color(red: 0.06, green: 0.22, blue: 0.06)

    var body: some View {
        GeometryReader { geo in
            let px = floor(min(geo.size.width / CGFloat(vW), geo.size.height / CGFloat(vH)))
            let screenW = px * CGFloat(vW)
            let screenH = px * CGFloat(vH)

            ZStack {
                // "Game Boy body" olive surround
                Color(red: 0.55, green: 0.56, blue: 0.42)

                VStack(spacing: 0) {
                    // Screen bezel
                    ZStack {
                        // LCD screen
                        Canvas { context, size in
                            // Fill with lightest green
                            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Self.lightest))

                            if showTitle {
                                drawTitleScreen(context: &context, px: px)
                            } else if showStats {
                                drawStatsScreen(context: &context, px: px)
                            } else {
                                drawHUD(context: &context, px: px)
                                drawRoom(context: &context, px: px)
                                drawPlayer(context: &context, px: px)
                                if let msg = showMessage {
                                    drawMessageBox(context: &context, px: px, text: msg)
                                }
                            }
                        }
                        .frame(width: screenW, height: screenH)

                        // Dot-matrix overlay
                        Canvas { context, size in
                            // Pixel grid gaps
                            for x in stride(from: 0, to: size.width, by: px) {
                                context.fill(
                                    Path(CGRect(x: x + px - 0.5, y: 0, width: 0.5, height: size.height)),
                                    with: .color(.black.opacity(0.08))
                                )
                            }
                            for y in stride(from: 0, to: size.height, by: px) {
                                context.fill(
                                    Path(CGRect(x: 0, y: y + px - 0.5, width: size.width, height: 0.5)),
                                    with: .color(.black.opacity(0.08))
                                )
                            }
                        }
                        .frame(width: screenW, height: screenH)
                        .allowsHitTesting(false)
                    }
                    .padding(px * 3)
                    .background(Color(red: 0.30, green: 0.32, blue: 0.28))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // "Nintendo GAME BOY" label
                    Text("GAME BOY")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .italic()
                        .foregroundStyle(Color(red: 0.25, green: 0.25, blue: 0.50))
                        .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(red: 0.55, green: 0.56, blue: 0.42))
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(keys: [.upArrow], phases: [.down, .repeat]) { _ in
            if showTitle { showTitle = false; return .handled }
            if showStats { showStats = false; return .handled }
            movePlayer(dx: 0, dy: -1); return .handled
        }
        .onKeyPress(keys: [.downArrow], phases: [.down, .repeat]) { _ in
            if showTitle { showTitle = false; return .handled }
            if showStats { showStats = false; return .handled }
            movePlayer(dx: 0, dy: 1); return .handled
        }
        .onKeyPress(keys: [.leftArrow], phases: [.down, .repeat]) { _ in
            if showTitle { showTitle = false; return .handled }
            movePlayer(dx: -1, dy: 0); return .handled
        }
        .onKeyPress(keys: [.rightArrow], phases: [.down, .repeat]) { _ in
            if showTitle { showTitle = false; return .handled }
            movePlayer(dx: 1, dy: 0); return .handled
        }
        .onKeyPress(.return) {
            if showTitle { showTitle = false }
            else if showStats { showStats = false }
            else { showStats = true }
            return .handled
        }
        .onKeyPress(.escape) { onExit(); return .handled }
        .onAppear {
            isFocused = true
            gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12, repeats: true) { _ in
                frame += 1
                if messageTimer > 0 { messageTimer -= 1; if messageTimer == 0 { showMessage = nil } }
            }
        }
        .onDisappear { gameTimer?.invalidate() }
    }

    // MARK: - Title Screen

    private func drawTitleScreen(context: inout GraphicsContext, px: CGFloat) {
        // Mountain art
        let mtnColor = Self.dark
        for x in 0..<vW {
            let h1 = Int(sin(Double(x) * 0.04) * 20 + 30)
            let h2 = Int(sin(Double(x) * 0.06 + 2) * 15 + 25)
            pxFill(context: &context, px: px, x: x, y: 60 - h1, w: 1, h: h1 + 20, color: mtnColor)
            pxFill(context: &context, px: px, x: x, y: 65 - h2, w: 1, h: h2 + 20, color: Self.darkest)
        }
        // Ground
        pxFill(context: &context, px: px, x: 0, y: 80, w: vW, h: 64, color: Self.dark)

        // Title
        drawGBText(context: &context, px: px, text: "POCKET", x: 40, y: 10, color: Self.darkest, size: 10)
        drawGBText(context: &context, px: px, text: "HIKING", x: 36, y: 24, color: Self.darkest, size: 12)

        // Trail badge
        pxFill(context: &context, px: px, x: 68, y: 42, w: 24, h: 24, color: Self.lightest)
        pxFill(context: &context, px: px, x: 70, y: 44, w: 20, h: 20, color: Self.darkest)
        // Mountain inside badge
        for dx in 0..<16 {
            let mh = max(0, 8 - abs(dx - 8))
            pxFill(context: &context, px: px, x: 72 + dx, y: 56 - mh, w: 1, h: mh, color: Self.lightest)
        }

        // Stats
        drawGBText(context: &context, px: px, text: "\(store.hikes.count) HIKES LOGGED", x: 20, y: 92, color: Self.lightest)
        drawGBText(context: &context, px: px, text: "\(Int(store.hikes.reduce(0){$0+$1.distanceMiles})) MILES", x: 40, y: 104, color: Self.lightest)

        // Blink prompt
        if frame % 16 < 10 {
            drawGBText(context: &context, px: px, text: "PRESS START", x: 38, y: 126, color: Self.darkest)
        }
    }

    // MARK: - Stats Screen

    private func drawStatsScreen(context: inout GraphicsContext, px: CGFloat) {
        pxFill(context: &context, px: px, x: 0, y: 0, w: vW, h: vH, color: Self.lightest)

        drawGBText(context: &context, px: px, text: "= HIKER CARD =", x: 20, y: 4, color: Self.darkest, size: 7)

        // Border
        pxFill(context: &context, px: px, x: 4, y: 14, w: vW - 8, h: 1, color: Self.darkest)
        pxFill(context: &context, px: px, x: 4, y: vH - 8, w: vW - 8, h: 1, color: Self.darkest)

        let count = store.hikes.count
        let miles = Int(store.hikes.reduce(0) { $0 + $1.distanceMiles })
        let elev = Int(store.hikes.reduce(0) { $0 + $1.elevationGainFt })
        let streak = store.streakInfo.currentWeeks
        let trails = Set(store.hikes.map(\.trailName)).count
        let regions = Set(store.hikes.map(\.region)).count

        let stats = [
            "HIKES:    \(count)",
            "MILES:    \(miles)",
            "ELEV:     \(elev)FT",
            "TRAILS:   \(trails)",
            "REGIONS:  \(regions)",
            "STREAK:   \(streak)WK",
            "BADGES:   \(roomsVisited.count)",
            "ITEMS:    \(itemsFound)",
        ]

        for (i, line) in stats.enumerated() {
            drawGBText(context: &context, px: px, text: line, x: 12, y: 20 + i * 12, color: Self.darkest)
        }

        // Top trail
        if let top = store.trailSummaries().first {
            drawGBText(context: &context, px: px, text: "BEST TRAIL:", x: 12, y: 118, color: Self.dark)
            drawGBText(context: &context, px: px, text: String(top.name.uppercased().prefix(20)), x: 12, y: 130, color: Self.darkest)
        }
    }

    // MARK: - HUD

    private func drawHUD(context: inout GraphicsContext, px: CGFloat) {
        pxFill(context: &context, px: px, x: 0, y: 0, w: vW, h: 16, color: Self.lightest)
        let trail = currentTrail
        let name = trail.map { String($0.name.uppercased().prefix(14)) } ?? "WILDERNESS"
        drawGBText(context: &context, px: px, text: name, x: 2, y: 2, color: Self.darkest)
        drawGBText(context: &context, px: px, text: "LV\(roomsVisited.count)", x: 130, y: 2, color: Self.dark)
        pxFill(context: &context, px: px, x: 0, y: 15, w: vW, h: 1, color: Self.darkest)
    }

    // MARK: - Room

    private func drawRoom(context: inout GraphicsContext, px: CGFloat) {
        let map = generateMap()
        let offsetY = 16

        for row in 0..<gridH {
            for col in 0..<gridW {
                let x = col * 16
                let y = offsetY + row * 14
                let tile = map[row][col]

                switch tile {
                case 0: // grass
                    pxFill(context: &context, px: px, x: x, y: y, w: 16, h: 14, color: Self.light)
                    if (row + col + currentRoom) % 3 == 0 {
                        pxFill(context: &context, px: px, x: x + 4, y: y + 4, w: 2, h: 3, color: Self.dark)
                        pxFill(context: &context, px: px, x: x + 3, y: y + 4, w: 4, h: 1, color: Self.dark)
                    }
                case 1: // path
                    pxFill(context: &context, px: px, x: x, y: y, w: 16, h: 14, color: Self.lightest)
                    if (row + col) % 3 == 0 {
                        pxFill(context: &context, px: px, x: x + 6, y: y + 5, w: 2, h: 2, color: Self.light)
                    }
                case 2: // tree
                    pxFill(context: &context, px: px, x: x, y: y, w: 16, h: 14, color: Self.light)
                    // Trunk
                    pxFill(context: &context, px: px, x: x + 6, y: y + 8, w: 4, h: 6, color: Self.dark)
                    // Canopy
                    pxFill(context: &context, px: px, x: x + 2, y: y + 1, w: 12, h: 8, color: Self.darkest)
                    pxFill(context: &context, px: px, x: x + 4, y: y, w: 8, h: 2, color: Self.darkest)
                case 3: // rock
                    pxFill(context: &context, px: px, x: x, y: y, w: 16, h: 14, color: Self.light)
                    pxFill(context: &context, px: px, x: x + 2, y: y + 3, w: 12, h: 8, color: Self.dark)
                    pxFill(context: &context, px: px, x: x + 3, y: y + 4, w: 10, h: 6, color: Self.darkest)
                    pxFill(context: &context, px: px, x: x + 5, y: y + 4, w: 3, h: 2, color: Self.dark) // highlight
                case 4: // water
                    let wc = frame % 8 < 4 ? Self.dark : Self.darkest
                    pxFill(context: &context, px: px, x: x, y: y, w: 16, h: 14, color: wc)
                    // Ripples
                    pxFill(context: &context, px: px, x: x + 2, y: y + 4, w: 6, h: 1, color: Self.light)
                    pxFill(context: &context, px: px, x: x + 8, y: y + 9, w: 5, h: 1, color: Self.light)
                case 5: // sign
                    pxFill(context: &context, px: px, x: x, y: y, w: 16, h: 14, color: Self.light)
                    pxFill(context: &context, px: px, x: x + 7, y: y + 6, w: 2, h: 8, color: Self.darkest)
                    pxFill(context: &context, px: px, x: x + 2, y: y + 2, w: 12, h: 6, color: Self.darkest)
                    pxFill(context: &context, px: px, x: x + 3, y: y + 3, w: 10, h: 4, color: Self.lightest)
                case 6: // item (badge)
                    pxFill(context: &context, px: px, x: x, y: y, w: 16, h: 14, color: Self.light)
                    if frame % 10 < 7 {
                        pxFill(context: &context, px: px, x: x + 4, y: y + 2, w: 8, h: 8, color: Self.darkest)
                        pxFill(context: &context, px: px, x: x + 5, y: y + 3, w: 6, h: 6, color: Self.lightest)
                        pxFill(context: &context, px: px, x: x + 7, y: y + 4, w: 2, h: 4, color: Self.darkest)
                    }
                default:
                    pxFill(context: &context, px: px, x: x, y: y, w: 16, h: 14, color: Self.light)
                }
            }
        }
    }

    // MARK: - Player Sprite

    private func drawPlayer(context: inout GraphicsContext, px: CGFloat) {
        let x = playerX * 16
        let y = 16 + playerY * 14
        let w = frame % 6 < 3 // walk toggle

        // Head
        pxFill(context: &context, px: px, x: x + 4, y: y, w: 8, h: 6, color: Self.lightest)
        pxFill(context: &context, px: px, x: x + 4, y: y, w: 8, h: 3, color: Self.darkest) // hair
        pxFill(context: &context, px: px, x: x + 5, y: y + 3, w: 2, h: 2, color: Self.darkest) // eye
        pxFill(context: &context, px: px, x: x + 9, y: y + 3, w: 2, h: 2, color: Self.darkest) // eye
        // Body
        pxFill(context: &context, px: px, x: x + 3, y: y + 6, w: 10, h: 4, color: Self.dark)
        // Backpack
        pxFill(context: &context, px: px, x: x + 12, y: y + 5, w: 3, h: 4, color: Self.darkest)
        // Legs
        if w {
            pxFill(context: &context, px: px, x: x + 4, y: y + 10, w: 3, h: 4, color: Self.darkest)
            pxFill(context: &context, px: px, x: x + 9, y: y + 10, w: 3, h: 4, color: Self.darkest)
        } else {
            pxFill(context: &context, px: px, x: x + 3, y: y + 10, w: 3, h: 4, color: Self.darkest)
            pxFill(context: &context, px: px, x: x + 10, y: y + 10, w: 3, h: 4, color: Self.darkest)
        }
    }

    // MARK: - Message Box

    private func drawMessageBox(context: inout GraphicsContext, px: CGFloat, text: String) {
        pxFill(context: &context, px: px, x: 8, y: 100, w: vW - 16, h: 36, color: Self.lightest)
        pxFill(context: &context, px: px, x: 9, y: 101, w: vW - 18, h: 34, color: Self.lightest)
        // Border
        pxFill(context: &context, px: px, x: 8, y: 100, w: vW - 16, h: 2, color: Self.darkest)
        pxFill(context: &context, px: px, x: 8, y: 134, w: vW - 16, h: 2, color: Self.darkest)
        pxFill(context: &context, px: px, x: 8, y: 100, w: 2, h: 36, color: Self.darkest)
        pxFill(context: &context, px: px, x: vW - 10, y: 100, w: 2, h: 36, color: Self.darkest)

        drawGBText(context: &context, px: px, text: String(text.prefix(22)), x: 14, y: 108, color: Self.darkest)
    }

    // MARK: - Map Generation

    private var currentTrail: TrailSummary? {
        let s = store.trailSummaries()
        guard !s.isEmpty else { return nil }
        return s[currentRoom % s.count]
    }

    private func generateMap() -> [[Int]] {
        let seed = currentRoom &* 2654435761
        var map = Array(repeating: Array(repeating: 0, count: gridW), count: gridH)

        // Path
        let pathY = 3 + seed % 3
        for x in 0..<gridW {
            let wobble = (seed >> 4 + x * 5) % 3 == 0 ? 1 : 0
            let py = pathY + wobble
            if py < gridH { map[py][x] = 1 }
        }

        // Trees
        let elevation = currentTrail?.avgElevation ?? 1000
        let treeCount = min(12, max(3, elevation / 200))
        for i in 0..<treeCount {
            let tx = (seed >> (i * 3 + 2)) % gridW
            let ty = (seed >> (i * 5 + 1)) % gridH
            if map[ty][tx] == 0 { map[ty][tx] = 2 }
        }

        // Rocks
        for i in 0..<(seed % 3 + 1) {
            let rx = (seed >> (i * 7 + 4)) % gridW
            let ry = (seed >> (i * 4 + 6)) % gridH
            if map[ry][rx] == 0 { map[ry][rx] = 3 }
        }

        // Water
        if currentRoom % 3 == 1 {
            let wy = min(gridH - 1, pathY + 2)
            for wx in 1..<4 { if map[wy][wx] == 0 { map[wy][wx] = 4 } }
        }

        // Sign
        if map[max(0, pathY - 1)][1] == 0 { map[max(0, pathY - 1)][1] = 5 }

        // Collectible badge
        let ix = (seed >> 12) % (gridW - 2) + 1
        let iy = (seed >> 15) % (gridH - 2) + 1
        if map[iy][ix] == 0 { map[iy][ix] = 6 }

        return map
    }

    // MARK: - Movement

    private func movePlayer(dx: Int, dy: Int) {
        let newX = playerX + dx
        let newY = playerY + dy
        let summaries = store.trailSummaries()
        let total = max(1, summaries.count)

        if newX < 0 { currentRoom = (currentRoom - 1 + total) % total; roomsVisited.insert(currentRoom); playerX = gridW - 2; showTrailName(); return }
        if newX >= gridW { currentRoom = (currentRoom + 1) % total; roomsVisited.insert(currentRoom); playerX = 1; showTrailName(); return }
        if newY < 0 { currentRoom = (currentRoom - 1 + total) % total; roomsVisited.insert(currentRoom); playerY = gridH - 2; showTrailName(); return }
        if newY >= gridH { currentRoom = (currentRoom + 1) % total; roomsVisited.insert(currentRoom); playerY = 1; showTrailName(); return }

        let map = generateMap()
        guard newX >= 0, newX < gridW, newY >= 0, newY < gridH else { return }
        let tile = map[newY][newX]
        if tile == 2 || tile == 3 || tile == 4 { return } // blocked
        if tile == 5 { showTrailName() }
        if tile == 6 { itemsFound += 1; showMessage = "FOUND A BADGE!"; messageTimer = 30 }
        playerX = newX; playerY = newY
    }

    private func showTrailName() {
        if let t = currentTrail {
            showMessage = String(t.name.uppercased().prefix(22))
            messageTimer = 40
        }
    }

    // MARK: - Drawing Helpers

    private func pxFill(context: inout GraphicsContext, px: CGFloat, x: Int, y: Int, w: Int, h: Int, color: Color) {
        context.fill(Path(CGRect(x: CGFloat(x) * px, y: CGFloat(y) * px, width: CGFloat(w) * px, height: CGFloat(h) * px)), with: .color(color))
    }

    private func drawGBText(context: inout GraphicsContext, px: CGFloat, text: String, x: Int, y: Int, color: Color, size: CGFloat = 6) {
        let resolved = context.resolve(
            Text(text)
                .font(.system(size: px * size, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        )
        context.draw(resolved, at: CGPoint(x: CGFloat(x) * px, y: CGFloat(y) * px), anchor: .topLeading)
    }
}

#endif
