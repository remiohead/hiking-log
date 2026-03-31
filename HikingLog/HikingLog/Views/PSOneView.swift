import SwiftUI
import AVFoundation

#if os(macOS)

// MARK: - PS1 Startup Sound Player

final class PS1AudioPlayer {
    private var player: AVAudioPlayer?

    func play() {
        // Look for the MP3 in the resource bundle
        guard let url = resourceBundle.url(forResource: "ps1_startup", withExtension: "mp3") else { return }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 0.7
            player?.play()
        } catch {}
    }

    func stop() {
        player?.stop()
        player = nil
    }
}

// MARK: - PlayStation 1 Boot Sequence & Memory Card Browser

struct PSOneView: View {
    @Environment(HikeStore.self) private var store
    @Environment(TrailStore.self) private var trailStore

    let onExit: () -> Void

    enum BootPhase {
        case black, sceText, psLogo, shimmer, browser
    }

    @State private var bootPhase: BootPhase = .black
    @State private var selectedSlot: Int = 0
    @State private var frame: Int = 0
    @State private var animTimer: Timer?
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: CGFloat = 0
    @State private var sceOpacity: CGFloat = 0
    @State private var shimmerX: CGFloat = -100
    @State private var audioPlayer: PS1AudioPlayer?
    @FocusState private var isFocused: Bool

    // PS1 colors
    static let ps1Black = Color(red: 0.0, green: 0.0, blue: 0.0)
    static let ps1DarkGrey = Color(red: 0.15, green: 0.15, blue: 0.18)
    static let ps1MidGrey = Color(red: 0.25, green: 0.25, blue: 0.30)
    static let ps1LightGrey = Color(red: 0.55, green: 0.55, blue: 0.60)
    static let ps1White = Color(red: 0.90, green: 0.90, blue: 0.93)
    static let ps1Blue = Color(red: 0.20, green: 0.35, blue: 0.70)
    static let ps1Red = Color(red: 0.80, green: 0.15, blue: 0.20)
    static let ps1Yellow = Color(red: 0.90, green: 0.80, blue: 0.15)
    static let ps1Green = Color(red: 0.15, green: 0.65, blue: 0.30)
    static let ps1Highlight = Color(red: 0.30, green: 0.45, blue: 0.80)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                switch bootPhase {
                case .black:
                    Color.black

                case .sceText:
                    VStack(spacing: 8) {
                        Text("Sony Computer Entertainment")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(.white)
                            .opacity(sceOpacity)
                        Text("presents")
                            .font(.system(size: 14, weight: .ultraLight))
                            .foregroundStyle(Color(white: 0.6))
                            .opacity(sceOpacity)
                    }

                case .psLogo:
                    psLogoView(size: geo.size)

                case .shimmer:
                    psLogoView(size: geo.size)
                        .overlay {
                            // Shimmer effect
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.3), .clear],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: 100)
                                .offset(x: shimmerX)
                                .allowsHitTesting(false)
                        }

                case .browser:
                    memoryCardBrowser(size: geo.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.black)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(keys: [.upArrow], phases: [.down, .repeat]) { _ in
            if bootPhase == .browser { selectedSlot = max(0, selectedSlot - 1) }
            return .handled
        }
        .onKeyPress(keys: [.downArrow], phases: [.down, .repeat]) { _ in
            if bootPhase == .browser { selectedSlot = min(14, selectedSlot + 1) }
            return .handled
        }
        .onKeyPress(.escape) {
            onExit(); return .handled
        }
        .onKeyPress(.return) {
            if bootPhase != .browser { bootPhase = .browser }
            return .handled
        }
        .onAppear {
            isFocused = true
            startBootSequence()
            animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { _ in
                frame += 1
            }
        }
        .onDisappear {
            animTimer?.invalidate()
            animTimer = nil
            audioPlayer?.stop()
            audioPlayer = nil
        }
    }

    // MARK: - Boot Sequence

    private func startBootSequence() {
        bootPhase = .black
        // Play the iconic PS1 startup sound
        let player = PS1AudioPlayer()
        player.play()
        audioPlayer = player

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            bootPhase = .sceText
            withAnimation(.easeIn(duration: 1.0)) { sceOpacity = 1.0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.5)) { sceOpacity = 0.0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            bootPhase = .psLogo
            withAnimation(.spring(duration: 1.2, bounce: 0.2)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            bootPhase = .shimmer
            withAnimation(.easeInOut(duration: 1.5)) { shimmerX = 400 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
            withAnimation(.easeIn(duration: 0.5)) { bootPhase = .browser }
        }
    }

    // MARK: - PS Logo

    @ViewBuilder
    private func psLogoView(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let cx = canvasSize.width / 2
            let cy = canvasSize.height / 2 - 30
            let s: CGFloat = 40 * logoScale

            // The PS1 logo: a stylized "PS" made of colored geometric shapes
            // We'll approximate with the iconic colored diamond/star

            // Red section (top-left)
            var red = Path()
            red.move(to: CGPoint(x: cx, y: cy - s * 2))
            red.addLine(to: CGPoint(x: cx - s * 1.5, y: cy))
            red.addLine(to: CGPoint(x: cx, y: cy))
            red.closeSubpath()
            context.fill(red, with: .color(Self.ps1Red))

            // Yellow section (top-right)
            var yellow = Path()
            yellow.move(to: CGPoint(x: cx, y: cy - s * 2))
            yellow.addLine(to: CGPoint(x: cx + s * 1.5, y: cy))
            yellow.addLine(to: CGPoint(x: cx, y: cy))
            yellow.closeSubpath()
            context.fill(yellow, with: .color(Self.ps1Yellow))

            // Blue section (bottom-left)
            var blue = Path()
            blue.move(to: CGPoint(x: cx - s * 1.5, y: cy))
            blue.addLine(to: CGPoint(x: cx, y: cy + s * 2))
            blue.addLine(to: CGPoint(x: cx, y: cy))
            blue.closeSubpath()
            context.fill(blue, with: .color(Self.ps1Blue))

            // Green section (bottom-right)
            var green = Path()
            green.move(to: CGPoint(x: cx + s * 1.5, y: cy))
            green.addLine(to: CGPoint(x: cx, y: cy + s * 2))
            green.addLine(to: CGPoint(x: cx, y: cy))
            green.closeSubpath()
            context.fill(green, with: .color(Self.ps1Green))

            // Inner highlight
            let inner = Path(ellipseIn: CGRect(x: cx - s * 0.4, y: cy - s * 0.4, width: s * 0.8, height: s * 0.8))
            context.fill(inner, with: .color(.white.opacity(0.15)))

            // "PlayStation" text below
            let text = context.resolve(
                Text("PlayStation")
                    .font(.system(size: 24, weight: .light, design: .default))
                    .foregroundColor(.white)
            )
            context.draw(text, at: CGPoint(x: cx, y: cy + s * 2.8), anchor: .center)

            // Small TM
            let tm = context.resolve(
                Text("®")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            )
            context.draw(tm, at: CGPoint(x: cx + 68, y: cy + s * 2.5), anchor: .center)
        }
        .opacity(logoOpacity)
    }

    // MARK: - Memory Card Browser

    @ViewBuilder
    private func memoryCardBrowser(size: CGSize) -> some View {
        let saves = generateSaves()

        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Memory Card Slot 1")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Self.ps1White)
                Spacer()
                Text("\(saves.filter { !$0.isEmpty }.count)/15 Blocks Used")
                    .font(.system(size: 13))
                    .foregroundStyle(Self.ps1LightGrey)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
            .background(Self.ps1DarkGrey)

            Divider().background(Self.ps1LightGrey)

            // Save slots
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(0..<15, id: \.self) { i in
                            saveSlotRow(index: i, save: saves[i], isSelected: selectedSlot == i)
                                .id(i)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: selectedSlot) { _, newVal in
                    proxy.scrollTo(newVal, anchor: .center)
                }
            }

            Divider().background(Self.ps1LightGrey)

            // Bottom bar
            HStack(spacing: 30) {
                controlHint(button: "▲▼", label: "Select")
                controlHint(button: "ESC", label: "Exit")
                Spacer()
                Text("Trail Computing Inc.")
                    .font(.system(size: 11))
                    .foregroundStyle(Self.ps1LightGrey.opacity(0.6))
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 10)
            .background(Self.ps1DarkGrey)
        }
        .background(
            LinearGradient(
                colors: [Self.ps1DarkGrey, Color(red: 0.10, green: 0.10, blue: 0.14)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private func saveSlotRow(index: Int, save: SaveSlot, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            // Slot number
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Self.ps1LightGrey)
                .frame(width: 24)

            if save.isEmpty {
                Text("- Empty -")
                    .font(.system(size: 14))
                    .foregroundStyle(Self.ps1LightGrey.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Save icon
                Canvas { context, size in
                    drawSaveIcon(context: &context, size: size, hue: save.iconHue)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(save.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Self.ps1White)
                        .lineLimit(1)
                    HStack(spacing: 16) {
                        Text(save.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(Self.ps1LightGrey)
                        Text(save.date)
                            .font(.system(size: 11))
                            .foregroundStyle(Self.ps1LightGrey.opacity(0.7))
                        Text("\(save.blocks) Block\(save.blocks == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundStyle(Self.ps1LightGrey.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Completion indicator
                if let pct = save.completion {
                    ZStack {
                        Circle()
                            .stroke(Self.ps1MidGrey, lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: CGFloat(pct) / 100)
                            .stroke(pct >= 100 ? Self.ps1Green : Self.ps1Blue, lineWidth: 2)
                            .rotationEffect(.degrees(-90))
                        Text("\(pct)%")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Self.ps1LightGrey)
                    }
                    .frame(width: 30, height: 30)
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 8)
        .background(isSelected ? Self.ps1Highlight.opacity(0.3) : Color.clear)
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle().fill(Self.ps1Highlight).frame(width: 3)
            }
        }
    }

    @ViewBuilder
    private func controlHint(button: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(button)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Self.ps1White)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 3).fill(Self.ps1MidGrey))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Self.ps1LightGrey)
        }
    }

    private func drawSaveIcon(context: inout GraphicsContext, size: CGSize, hue: Double) {
        // Little mountain/trail icon for each save
        let bgColor = Color(hue: hue, saturation: 0.5, brightness: 0.4)
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bgColor))

        // Mountain
        var mtn = Path()
        mtn.move(to: CGPoint(x: size.width * 0.15, y: size.height * 0.85))
        mtn.addLine(to: CGPoint(x: size.width * 0.45, y: size.height * 0.2))
        mtn.addLine(to: CGPoint(x: size.width * 0.75, y: size.height * 0.85))
        mtn.closeSubpath()
        context.fill(mtn, with: .color(Color(hue: hue, saturation: 0.3, brightness: 0.6)))

        // Snow cap
        var snow = Path()
        snow.move(to: CGPoint(x: size.width * 0.35, y: size.height * 0.35))
        snow.addLine(to: CGPoint(x: size.width * 0.45, y: size.height * 0.2))
        snow.addLine(to: CGPoint(x: size.width * 0.55, y: size.height * 0.35))
        snow.closeSubpath()
        context.fill(snow, with: .color(.white.opacity(0.7)))

        // Border
        context.stroke(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.2)), lineWidth: 0.5)
    }

    // MARK: - Save Data

    struct SaveSlot {
        let isEmpty: Bool
        let title: String
        let subtitle: String
        let date: String
        let blocks: Int
        let iconHue: Double
        let completion: Int?
    }

    private func generateSaves() -> [SaveSlot] {
        let summaries = store.trailSummaries()
        var saves: [SaveSlot] = []

        // First slot: overall save
        let totalMiles = Int(store.hikes.reduce(0) { $0 + $1.distanceMiles })
        saves.append(SaveSlot(
            isEmpty: false,
            title: "HIKING QUEST - Main Save",
            subtitle: "\(store.hikes.count) hikes, \(totalMiles)mi total",
            date: store.hikes.first?.date ?? "",
            blocks: 3,
            iconHue: 0.35,
            completion: min(100, store.hikes.count / 3)
        ))

        // Fill remaining with top trails
        for (i, trail) in summaries.prefix(10).enumerated() {
            let pct = min(100, trail.count * 15)
            saves.append(SaveSlot(
                isEmpty: false,
                title: trail.name,
                subtitle: "\(trail.region) - \(String(format: "%.1f", trail.avgMiles))mi avg",
                date: trail.lastHiked,
                blocks: max(1, trail.count / 3),
                iconHue: Double(i) * 0.08 + 0.1,
                completion: pct
            ))
        }

        // Fill rest as empty
        while saves.count < 15 {
            saves.append(SaveSlot(isEmpty: true, title: "", subtitle: "", date: "",
                                  blocks: 0, iconHue: 0, completion: nil))
        }

        return saves
    }
}

#endif
