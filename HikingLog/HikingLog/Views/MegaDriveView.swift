import SwiftUI
import AVFoundation

#if os(macOS)

// MARK: - Sega Mega Drive / Genesis - Sonic-Inspired Trail Runner

struct MegaDriveView: View {
    @Environment(HikeStore.self) private var store
    @Environment(TrailStore.self) private var trailStore

    let onExit: () -> Void

    @State private var showSega: Bool = true
    @State private var segaTimer: Int = 0
    @State private var scrollX: CGFloat = 0
    @State private var playerY: CGFloat = 0
    @State private var playerVY: CGFloat = 0
    @State private var isJumping: Bool = false
    @State private var rings: Int = 0
    @State private var speed: CGFloat = 3
    @State private var frame: Int = 0
    @State private var gameTimer: Timer?
    @State private var currentTrailIndex: Int = 0
    @State private var trailsRun: Int = 0
    @State private var segaPlayer: AVAudioPlayer?
    @FocusState private var isFocused: Bool

    private let vW = 320
    private let vH = 224
    private let groundY = 160

    // Sonic/MD palette
    static let skyTop = Color(red: 0.20, green: 0.50, blue: 0.95)
    static let skyBottom = Color(red: 0.45, green: 0.70, blue: 1.0)
    static let hillGreen1 = Color(red: 0.10, green: 0.60, blue: 0.15)
    static let hillGreen2 = Color(red: 0.15, green: 0.70, blue: 0.20)
    static let groundBrown = Color(red: 0.55, green: 0.30, blue: 0.10)
    static let groundOrange = Color(red: 0.70, green: 0.40, blue: 0.15)
    static let grassGreen = Color(red: 0.20, green: 0.75, blue: 0.15)
    static let ringGold = Color(red: 1.0, green: 0.80, blue: 0.10)
    static let ringShine = Color(red: 1.0, green: 1.0, blue: 0.60)
    static let segaBlue = Color(red: 0.06, green: 0.22, blue: 0.65)
    static let playerBlue = Color(red: 0.10, green: 0.30, blue: 0.90)
    static let playerSkin = Color(red: 0.95, green: 0.75, blue: 0.55)
    static let playerRed = Color(red: 0.85, green: 0.15, blue: 0.10)

    var body: some View {
        GeometryReader { geo in
            let px = floor(min(geo.size.width / CGFloat(vW), geo.size.height / CGFloat(vH)))
            let screenW = px * CGFloat(vW)
            let screenH = px * CGFloat(vH)

            ZStack {
                Color.black

                if showSega {
                    segaScreen(px: px, screenW: screenW, screenH: screenH)
                } else {
                    Canvas { context, size in
                        drawSky(context: &context, px: px)
                        drawHills(context: &context, px: px)
                        drawGround(context: &context, px: px)
                        drawRings(context: &context, px: px)
                        drawPlayer(context: &context, px: px)
                        drawHUD(context: &context, px: px)
                    }
                    .frame(width: screenW, height: screenH)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.black)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(keys: [.rightArrow], phases: [.down, .repeat]) { _ in
            if showSega { showSega = false; return .handled }
            speed = min(12, speed + 0.5)
            return .handled
        }
        .onKeyPress(keys: [.leftArrow], phases: [.down, .repeat]) { _ in
            speed = max(1, speed - 0.5)
            return .handled
        }
        .onKeyPress(keys: [.upArrow, .space]) { _ in
            if showSega { showSega = false; return .handled }
            if !isJumping { isJumping = true; playerVY = -12 }
            return .handled
        }
        .onKeyPress(.escape) { onExit(); return .handled }
        .onKeyPress(.return) {
            if showSega { showSega = false }
            return .handled
        }
        .onAppear {
            isFocused = true
            rings = Int(store.hikes.reduce(0) { $0 + $1.distanceMiles })
            // Play the SEGA sound
            if let url = resourceBundle.url(forResource: "sega", withExtension: "mp3") {
                segaPlayer = try? AVAudioPlayer(contentsOf: url)
                segaPlayer?.volume = 0.8
                segaPlayer?.play()
            }
            gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { _ in
                frame += 1
                if showSega {
                    segaTimer += 1
                    if segaTimer > 90 { showSega = false }
                    return
                }
                updateGame()
            }
        }
        .onDisappear {
            gameTimer?.invalidate()
            segaPlayer?.stop()
            segaPlayer = nil
        }
    }

    // MARK: - SEGA Splash

    @ViewBuilder
    private func segaScreen(px: CGFloat, screenW: CGFloat, screenH: CGFloat) -> some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Self.segaBlue))

            let letters = "SEGA"
            let letterWidth: CGFloat = 50
            let totalW = letterWidth * 4
            let startX = (CGFloat(vW) - totalW) / 2

            for (i, ch) in letters.enumerated() {
                let x = startX + CGFloat(i) * letterWidth
                let progress = min(1.0, CGFloat(segaTimer - i * 5) / 15.0)
                if progress > 0 {
                    let resolved = context.resolve(
                        Text(String(ch))
                            .font(.system(size: px * 40, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    )
                    context.draw(resolved, at: CGPoint(x: (x + letterWidth / 2) * px, y: 90 * px), anchor: .center)
                }
            }

            // Trademark
            if segaTimer > 40 {
                let tm = context.resolve(
                    Text("TM")
                        .font(.system(size: px * 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                )
                context.draw(tm, at: CGPoint(x: 240 * px, y: 78 * px), anchor: .center)
            }
        }
        .frame(width: screenW, height: screenH)
    }

    // MARK: - Game Update

    private func updateGame() {
        scrollX += speed

        // Trail transitions
        let trailLength: CGFloat = 3000
        if scrollX > trailLength {
            scrollX = 0
            let summaries = store.trailSummaries()
            currentTrailIndex = (currentTrailIndex + 1) % max(1, summaries.count)
            trailsRun += 1
        }

        // Physics
        if isJumping {
            playerVY += 0.7 // gravity
            playerY += playerVY
            if playerY >= 0 {
                playerY = 0
                playerVY = 0
                isJumping = false
            }
        }

        // Auto-collect rings near player
        let playerWorldX = scrollX + 60
        if Int(playerWorldX) % 120 < Int(speed) + 5 {
            rings += 1
        }
    }

    // MARK: - Drawing

    private func drawSky(context: inout GraphicsContext, px: CGFloat) {
        // Gradient sky in bands
        for row in 0..<(groundY / 4) {
            let t = CGFloat(row) / CGFloat(groundY / 4)
            let color = Color(
                red: 0.20 + t * 0.25,
                green: 0.50 + t * 0.20,
                blue: 0.95 + t * 0.05
            )
            pxFill(context: &context, px: px, x: 0, y: row * 4, w: vW, h: 4, color: color)
        }

        // Clouds (parallax)
        let cloudX1 = Int(-scrollX * 0.1) % vW + vW
        let cloudX2 = Int(-scrollX * 0.1 + 180) % vW + vW
        for cx in [cloudX1 % vW, cloudX2 % vW] {
            pxFill(context: &context, px: px, x: cx, y: 20, w: 40, h: 8, color: .white.opacity(0.7))
            pxFill(context: &context, px: px, x: cx + 5, y: 16, w: 30, h: 6, color: .white.opacity(0.6))
        }
    }

    private func drawHills(context: inout GraphicsContext, px: CGFloat) {
        let elevation = Double(store.trailSummaries().isEmpty ? 1000 :
            store.trailSummaries()[currentTrailIndex % store.trailSummaries().count].avgElevation)
        let hillScale = min(50, max(20, elevation / 50))

        // Back hills (slower parallax)
        for x in 0..<vW {
            let wx = CGFloat(x) + scrollX * 0.2
            let h = Int(sin(wx * 0.015) * hillScale * 0.6 + hillScale)
            pxFill(context: &context, px: px, x: x, y: groundY - h - 20, w: 1, h: h + 20, color: Self.hillGreen1)
        }

        // Front hills
        for x in 0..<vW {
            let wx = CGFloat(x) + scrollX * 0.5
            let h = Int(sin(wx * 0.02 + 1.5) * hillScale * 0.4 + hillScale * 0.7)
            pxFill(context: &context, px: px, x: x, y: groundY - h, w: 1, h: h, color: Self.hillGreen2)
        }

        // Checkered pattern on front hills (iconic Sonic look)
        for x in stride(from: 0, to: vW, by: 8) {
            let wx = CGFloat(x) + scrollX * 0.5
            let h = Int(sin(wx * 0.02 + 1.5) * hillScale * 0.4 + hillScale * 0.7)
            let topY = groundY - h
            let checker = (Int(wx / 8) % 2 == 0)
            if checker {
                pxFill(context: &context, px: px, x: x, y: topY, w: 8, h: min(8, h), color: Self.hillGreen1.opacity(0.5))
            }
        }
    }

    private func drawGround(context: inout GraphicsContext, px: CGFloat) {
        // Main ground
        pxFill(context: &context, px: px, x: 0, y: groundY, w: vW, h: vH - groundY, color: Self.groundBrown)

        // Grass edge
        pxFill(context: &context, px: px, x: 0, y: groundY, w: vW, h: 4, color: Self.grassGreen)

        // Ground stripe pattern (scrolling)
        let stripeOffset = Int(scrollX) % 16
        for x in stride(from: -stripeOffset, to: vW, by: 16) {
            pxFill(context: &context, px: px, x: x, y: groundY + 8, w: 8, h: 4, color: Self.groundOrange)
            pxFill(context: &context, px: px, x: x + 8, y: groundY + 16, w: 8, h: 4, color: Self.groundOrange)
        }

        // Trail name on ground
        let summaries = store.trailSummaries()
        if !summaries.isEmpty {
            let trail = summaries[currentTrailIndex % summaries.count]
            let nameX = vW / 2 - 60
            drawMDText(context: &context, px: px, text: "~ \(trail.name.uppercased().prefix(24)) ~",
                       x: nameX, y: groundY + 30, color: Self.grassGreen.opacity(0.6))
        }
    }

    private func drawRings(context: inout GraphicsContext, px: CGFloat) {
        // Rings floating in the air
        let ringSpacing = 120
        for i in 0..<5 {
            let worldX = Int(scrollX) / ringSpacing * ringSpacing + i * ringSpacing + 80
            let screenX = worldX - Int(scrollX)
            guard screenX > -10, screenX < vW + 10 else { continue }
            let bobY = sin(Double(frame + i * 8) * 0.15) * 4
            let ry = groundY - 40 + Int(bobY)
            let ringFrame = (frame + i * 3) % 12

            // Ring (rotating ellipse)
            let rw = max(2, 8 - abs(ringFrame - 6))
            pxFill(context: &context, px: px, x: screenX - rw / 2, y: ry, w: rw, h: 10, color: Self.ringGold)
            if rw > 4 {
                pxFill(context: &context, px: px, x: screenX - rw / 2 + 2, y: ry + 2, w: rw - 4, h: 6, color: Self.ringShine)
            }
        }
    }

    private func drawPlayer(context: inout GraphicsContext, px: CGFloat) {
        let x = 60
        let y = groundY - 24 + Int(playerY)
        let runFrame = (frame / 3) % 4

        // Body (running hiker in Sonic-style proportions)
        // Head
        pxFill(context: &context, px: px, x: x + 4, y: y, w: 12, h: 10, color: Self.playerSkin)
        // Hair / hat
        pxFill(context: &context, px: px, x: x + 3, y: y - 2, w: 14, h: 6, color: Self.playerRed)
        // Eyes
        pxFill(context: &context, px: px, x: x + 10, y: y + 3, w: 4, h: 4, color: .white)
        pxFill(context: &context, px: px, x: x + 12, y: y + 4, w: 2, h: 2, color: .black)
        // Body
        pxFill(context: &context, px: px, x: x + 4, y: y + 10, w: 12, h: 8, color: Self.playerBlue)
        // Backpack
        pxFill(context: &context, px: px, x: x, y: y + 8, w: 6, h: 8, color: Self.playerRed)

        // Legs (animated)
        if isJumping {
            // Curled up
            pxFill(context: &context, px: px, x: x + 4, y: y + 18, w: 6, h: 4, color: Self.playerRed)
            pxFill(context: &context, px: px, x: x + 10, y: y + 18, w: 6, h: 4, color: Self.playerRed)
        } else {
            let legOffsets: [(Int, Int)] = [(0, 0), (2, -2), (0, 0), (-2, 2)]
            let (l1, l2) = legOffsets[runFrame]
            pxFill(context: &context, px: px, x: x + 4 + l1, y: y + 18, w: 4, h: 6, color: Self.playerRed)
            pxFill(context: &context, px: px, x: x + 12 + l2, y: y + 18, w: 4, h: 6, color: Self.playerRed)
        }

        // Speed lines when fast
        if speed > 6 {
            for i in 0..<Int(speed - 5) {
                let lx = x - 10 - i * 8
                let ly = y + 6 + (i * 7) % 12
                if lx > 0 {
                    pxFill(context: &context, px: px, x: lx, y: ly, w: 6, h: 2, color: .white.opacity(0.4))
                }
            }
        }
    }

    private func drawHUD(context: inout GraphicsContext, px: CGFloat) {
        // Score
        drawMDText(context: &context, px: px, text: "SCORE", x: 8, y: 4, color: Self.ringGold)
        drawMDText(context: &context, px: px, text: "\(trailsRun * 1000 + Int(scrollX / 10))", x: 8, y: 16, color: .white)

        // Time
        let seconds = frame / 30
        let mins = seconds / 60
        let secs = seconds % 60
        drawMDText(context: &context, px: px, text: "TIME", x: 130, y: 4, color: Self.ringGold)
        drawMDText(context: &context, px: px, text: String(format: "%d:%02d", mins, secs), x: 130, y: 16, color: .white)

        // Rings
        drawMDText(context: &context, px: px, text: "MILES", x: 240, y: 4, color: Self.ringGold)
        drawMDText(context: &context, px: px, text: "\(rings)", x: 240, y: 16, color: .white)

        // Speed indicator
        let speedBar = Int(speed)
        for i in 0..<speedBar {
            let barColor: Color = i < 4 ? Self.grassGreen : (i < 8 ? Self.ringGold : Self.playerRed)
            pxFill(context: &context, px: px, x: 8 + i * 6, y: vH - 12, w: 5, h: 6, color: barColor)
        }
        drawMDText(context: &context, px: px, text: "SPEED", x: 8, y: vH - 22, color: .white.opacity(0.6), size: 4)
    }

    // MARK: - Helpers

    private func pxFill(context: inout GraphicsContext, px: CGFloat, x: Int, y: Int, w: Int, h: Int, color: Color) {
        context.fill(Path(CGRect(x: CGFloat(x) * px, y: CGFloat(y) * px, width: CGFloat(w) * px, height: CGFloat(h) * px)), with: .color(color))
    }

    private func drawMDText(context: inout GraphicsContext, px: CGFloat, text: String, x: Int, y: Int, color: Color, size: CGFloat = 7) {
        let resolved = context.resolve(
            Text(text).font(.system(size: px * size, weight: .heavy, design: .monospaced)).foregroundColor(color)
        )
        context.draw(resolved, at: CGPoint(x: CGFloat(x) * px, y: CGFloat(y) * px), anchor: .topLeading)
    }
}

#endif
