import SwiftUI

#if os(macOS)

// MARK: - Atari 2600 Hiking Adventure

struct AtariView: View {
    @Environment(HikeStore.self) private var store
    @Environment(TrailStore.self) private var trailStore

    let onExit: () -> Void

    @State private var hikerX: Int = 20
    @State private var currentTrailIndex: Int = 0
    @State private var frame: Int = 0
    @State private var gameTimer: Timer?
    @State private var trailsVisited: Set<Int> = [0]
    @FocusState private var isFocused: Bool

    // Virtual resolution (authentic Atari 2600)
    private let vW = 160
    private let vH = 192

    var body: some View {
        GeometryReader { geo in
            let pxW = geo.size.width / CGFloat(vW)
            let pxH = geo.size.height / CGFloat(vH)
            let px = floor(min(pxW, pxH))
            let screenW = px * CGFloat(vW)
            let screenH = px * CGFloat(vH)

            ZStack {
                Color.black

                Canvas { context, size in
                    drawScene(context: &context, px: px)
                }
                .frame(width: screenW, height: screenH)

                // Scanline overlay
                Canvas { context, size in
                    for y in stride(from: 0, to: size.height, by: px) {
                        context.fill(
                            Path(CGRect(x: 0, y: y + px * 0.65, width: size.width, height: px * 0.35)),
                            with: .color(.black.opacity(0.25))
                        )
                    }
                }
                .frame(width: screenW, height: screenH)
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.black)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(keys: [.rightArrow], phases: [.down, .repeat]) { _ in
            moveHiker(dx: 3)
            return .handled
        }
        .onKeyPress(keys: [.leftArrow], phases: [.down, .repeat]) { _ in
            moveHiker(dx: -3)
            return .handled
        }
        .onKeyPress(.escape) {
            onExit()
            return .handled
        }
        .onAppear {
            isFocused = true
            gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { _ in
                frame += 1
            }
        }
        .onDisappear {
            gameTimer?.invalidate()
            gameTimer = nil
        }
    }

    // MARK: - Movement

    private func moveHiker(dx: Int) {
        let newX = hikerX + dx
        let summaries = trailSummaries
        guard !summaries.isEmpty else { return }

        if newX > vW - 6 {
            currentTrailIndex = (currentTrailIndex + 1) % summaries.count
            trailsVisited.insert(currentTrailIndex)
            hikerX = 6
        } else if newX < 2 {
            currentTrailIndex = (currentTrailIndex - 1 + summaries.count) % summaries.count
            trailsVisited.insert(currentTrailIndex)
            hikerX = vW - 10
        } else {
            hikerX = newX
        }
    }

    private var trailSummaries: [TrailSummary] {
        store.trailSummaries()
    }

    private var currentTrail: TrailSummary? {
        let s = trailSummaries
        guard !s.isEmpty else { return nil }
        return s[currentTrailIndex % s.count]
    }

    // MARK: - Scene Drawing

    private func drawScene(context: inout GraphicsContext, px: CGFloat) {
        drawSky(context: &context, px: px)
        drawMountains(context: &context, px: px)
        drawTrees(context: &context, px: px)
        drawGround(context: &context, px: px)
        drawCollectibles(context: &context, px: px)
        drawHiker(context: &context, px: px)
        drawScoreBar(context: &context, px: px)
        drawTrailInfo(context: &context, px: px)
    }

    // MARK: - Sky

    private func drawSky(context: inout GraphicsContext, px: CGFloat) {
        let bands: [(rows: Int, color: Color)] = [
            (14, Color(red: 0.00, green: 0.00, blue: 0.27)),
            (14, Color(red: 0.00, green: 0.00, blue: 0.40)),
            (14, Color(red: 0.00, green: 0.00, blue: 0.53)),
            (14, Color(red: 0.00, green: 0.07, blue: 0.60)),
            (14, Color(red: 0.07, green: 0.17, blue: 0.67)),
            (14, Color(red: 0.17, green: 0.27, blue: 0.73)),
            (14, Color(red: 0.27, green: 0.37, blue: 0.80)),
        ]
        var y = 16 // below score bar
        for band in bands {
            px_fill(context: &context, px: px, x: 0, y: y, w: vW, h: band.rows, color: band.color)
            y += band.rows
        }
    }

    // MARK: - Mountains

    private func drawMountains(context: inout GraphicsContext, px: CGFloat) {
        let elevation = Double(currentTrail?.avgElevation ?? 1500)
        let idx = currentTrailIndex

        // Back range (darker, taller)
        for x in 0..<vW {
            let h = mtnH(x: x, layer: 0, idx: idx, elev: elevation)
            px_fill(context: &context, px: px, x: x, y: 80 - h, w: 1, h: h + 30,
                    color: Color(red: 0.20, green: 0.05, blue: 0.33))
        }
        // Snow caps on tall peaks
        for x in 0..<vW {
            let h = mtnH(x: x, layer: 0, idx: idx, elev: elevation)
            if h > 35 {
                px_fill(context: &context, px: px, x: x, y: 80 - h, w: 1, h: 3,
                        color: Color(red: 0.87, green: 0.87, blue: 0.93))
            }
        }
        // Front range (lighter, shorter)
        for x in 0..<vW {
            let h = mtnH(x: x, layer: 1, idx: idx, elev: elevation)
            px_fill(context: &context, px: px, x: x, y: 98 - h, w: 1, h: h + 22,
                    color: Color(red: 0.33, green: 0.10, blue: 0.47))
        }
    }

    private func mtnH(x: Int, layer: Int, idx: Int, elev: Double) -> Int {
        let baseH = min(45, max(10, Int(elev / 70)))
        let phase = Double(idx) * 2.7 + Double(layer) * 1.8
        let w1 = sin(Double(x) * 0.03 + phase) * Double(baseH) * 0.5
        let w2 = sin(Double(x) * 0.07 + phase * 0.6) * Double(baseH) * 0.3
        let w3 = sin(Double(x) * 0.15 + phase * 1.4) * Double(baseH) * 0.1
        let scale = layer == 0 ? 1.0 : 0.6
        return max(4, Int(Double(baseH) * scale + w1 + w2 + w3))
    }

    // MARK: - Trees

    private func drawTrees(context: inout GraphicsContext, px: CGFloat) {
        let idx = currentTrailIndex
        for i in 0..<14 {
            let treeX = ((idx + 1) * 41 + i * 13 + 3) % (vW - 8) + 4
            let treeY = 108 + ((idx * 3 + i * 7) % 5) * 3
            let treeH = 6 + ((idx + i) % 3) * 2

            // Trunk
            px_fill(context: &context, px: px, x: treeX + 1, y: treeY, w: 2, h: 4,
                    color: Color(red: 0.40, green: 0.20, blue: 0.07))

            // Canopy layers
            let green = (i % 2 == 0)
                ? Color(red: 0.10, green: 0.50, blue: 0.05)
                : Color(red: 0.05, green: 0.37, blue: 0.0)

            for row in 0..<treeH {
                let w = max(1, (treeH - row + 1) / 2)
                let xOff = treeX + 2 - w / 2
                px_fill(context: &context, px: px, x: xOff, y: treeY - row - 1, w: w, h: 1, color: green)
            }
        }
    }

    // MARK: - Ground & Trail Path

    private func drawGround(context: inout GraphicsContext, px: CGFloat) {
        // Trail bed
        px_fill(context: &context, px: px, x: 0, y: 126, w: vW, h: 9,
                color: Color(red: 0.47, green: 0.30, blue: 0.13))
        // Trail surface markings
        let offset = (frame / 2) % 16
        for x in stride(from: -offset, to: vW, by: 16) {
            px_fill(context: &context, px: px, x: x, y: 129, w: 6, h: 2,
                    color: Color(red: 0.60, green: 0.43, blue: 0.23))
        }
        // Ground
        px_fill(context: &context, px: px, x: 0, y: 135, w: vW, h: 18,
                color: Color(red: 0.0, green: 0.23, blue: 0.0))
        // Grass tufts
        for i in 0..<20 {
            let gx = ((currentTrailIndex + 1) * 23 + i * 8 + 2) % vW
            px_fill(context: &context, px: px, x: gx, y: 135, w: 2, h: 1,
                    color: Color(red: 0.10, green: 0.40, blue: 0.05))
        }
    }

    // MARK: - Collectibles (trail markers)

    private func drawCollectibles(context: inout GraphicsContext, px: CGFloat) {
        let idx = currentTrailIndex
        // Place trail markers at deterministic positions
        let markerPositions = [
            ((idx * 17 + 23) % (vW - 20)) + 10,
            ((idx * 31 + 67) % (vW - 20)) + 10,
            ((idx * 7 + 109) % (vW - 20)) + 10,
        ]

        let blink = (frame / 8) % 2 == 0

        for mx in markerPositions {
            // Diamond/star shape
            let starColor = blink
                ? Color(red: 0.93, green: 0.80, blue: 0.13)
                : Color(red: 0.80, green: 0.67, blue: 0.07)

            px_fill(context: &context, px: px, x: mx + 1, y: 122, w: 2, h: 1, color: starColor)
            px_fill(context: &context, px: px, x: mx, y: 123, w: 4, h: 1, color: starColor)
            px_fill(context: &context, px: px, x: mx + 1, y: 124, w: 2, h: 1, color: starColor)

            // Post below
            px_fill(context: &context, px: px, x: mx + 1, y: 125, w: 2, h: 2,
                    color: Color(red: 0.53, green: 0.33, blue: 0.13))
        }
    }

    // MARK: - Hiker Sprite

    private func drawHiker(context: inout GraphicsContext, px: CGFloat) {
        let walkFrame = (frame / 5) % 2
        let sprite = walkFrame == 0 ? hikerFrame1 : hikerFrame2
        let y = 119

        // Body
        for (row, line) in sprite.enumerated() {
            for (col, pixel) in line.enumerated() {
                if pixel > 0 {
                    let color: Color = pixel == 1
                        ? Color(red: 0.87, green: 0.37, blue: 0.07) // body orange
                        : Color(red: 0.93, green: 0.67, blue: 0.40) // skin/pack tan
                    px_fill(context: &context, px: px, x: hikerX + col, y: y + row, w: 1, h: 1, color: color)
                }
            }
        }
    }

    // 6 wide x 8 tall, 0=transparent, 1=body, 2=skin/pack
    private let hikerFrame1: [[Int]] = [
        [0, 0, 2, 2, 0, 0],
        [0, 0, 2, 2, 0, 0],
        [0, 1, 1, 1, 1, 0],
        [2, 1, 1, 1, 1, 2],
        [0, 0, 1, 1, 0, 0],
        [0, 0, 1, 1, 0, 0],
        [0, 1, 0, 0, 1, 0],
        [0, 1, 0, 0, 1, 0],
    ]

    private let hikerFrame2: [[Int]] = [
        [0, 0, 2, 2, 0, 0],
        [0, 0, 2, 2, 0, 0],
        [0, 1, 1, 1, 1, 0],
        [2, 1, 1, 1, 1, 2],
        [0, 0, 1, 1, 0, 0],
        [0, 1, 0, 1, 0, 0],
        [0, 0, 0, 0, 1, 0],
        [0, 1, 0, 1, 0, 0],
    ]

    // MARK: - Score Bar

    private func drawScoreBar(context: inout GraphicsContext, px: CGFloat) {
        // Black background
        px_fill(context: &context, px: px, x: 0, y: 0, w: vW, h: 15, color: .black)

        // Separator line
        px_fill(context: &context, px: px, x: 0, y: 15, w: vW, h: 1,
                color: Color(red: 0.80, green: 0.80, blue: 0.13))

        let hikeCount = store.hikes.count
        let totalMiles = Int(store.hikes.reduce(0) { $0 + $1.distanceMiles })
        let streak = store.streakInfo.currentWeeks

        let text1 = "HIKES:\(hikeCount)  MI:\(totalMiles)"
        let text2 = "STREAK:\(streak)WK  TRAILS:\(trailsVisited.count)"

        drawText(context: &context, px: px, text: text1, x: 3, y: 1,
                 color: Color(red: 0.80, green: 0.80, blue: 0.13))
        drawText(context: &context, px: px, text: text2, x: 3, y: 8,
                 color: Color(red: 0.60, green: 0.80, blue: 0.60))
    }

    // MARK: - Trail Info Bar

    private func drawTrailInfo(context: inout GraphicsContext, px: CGFloat) {
        // Black background
        px_fill(context: &context, px: px, x: 0, y: 153, w: vW, h: 39, color: .black)

        // Separator
        px_fill(context: &context, px: px, x: 0, y: 153, w: vW, h: 1,
                color: Color(red: 0.80, green: 0.80, blue: 0.13))

        if let trail = currentTrail {
            let name = String(trail.name.uppercased().prefix(26))
            let info = String(format: "%.1fMI  %dFT  HIKED %dX", trail.avgMiles, trail.avgElevation, trail.count)
            let region = trail.region.uppercased()

            drawText(context: &context, px: px, text: name, x: 3, y: 156, color: .white)
            drawText(context: &context, px: px, text: info, x: 3, y: 163,
                     color: Color(red: 0.47, green: 0.80, blue: 0.47))
            drawText(context: &context, px: px, text: String(region.prefix(26)), x: 3, y: 170,
                     color: Color(red: 0.47, green: 0.47, blue: 0.80))
        }

        // Arrow hint
        let hint = (frame / 15) % 2 == 0 ? "< ARROW KEYS TO EXPLORE >" : "  ARROW KEYS TO EXPLORE  "
        drawText(context: &context, px: px, text: hint, x: 3, y: 182,
                 color: Color(red: 0.40, green: 0.40, blue: 0.40))
    }

    // MARK: - Drawing Helpers

    private func px_fill(context: inout GraphicsContext, px: CGFloat,
                         x: Int, y: Int, w: Int, h: Int, color: Color) {
        let rect = CGRect(
            x: CGFloat(x) * px,
            y: CGFloat(y) * px,
            width: CGFloat(w) * px,
            height: CGFloat(h) * px
        )
        context.fill(Path(rect), with: .color(color))
    }

    private func drawText(context: inout GraphicsContext, px: CGFloat,
                          text: String, x: Int, y: Int, color: Color) {
        let fontSize = max(8, px * 4.5)
        let resolved = context.resolve(
            Text(text)
                .font(.system(size: fontSize, weight: .heavy, design: .monospaced))
                .foregroundColor(color)
        )
        context.draw(resolved, at: CGPoint(x: CGFloat(x) * px, y: CGFloat(y) * px), anchor: .topLeading)
    }
}

#endif
