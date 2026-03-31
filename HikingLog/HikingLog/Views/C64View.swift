import SwiftUI

#if os(macOS)

// MARK: - Commodore 64 BASIC Terminal

struct C64View: View {
    @Environment(HikeStore.self) private var store
    @Environment(TrailStore.self) private var trailStore

    let onExit: () -> Void

    @State private var lines: [C64Line] = []
    @State private var inputLine: String = ""
    @State private var cursorVisible: Bool = true
    @State private var cursorTimer: Timer?
    @State private var borderColorIdx: Int = 14
    @State private var bgColorIdx: Int = 6
    @State private var currentProgram: String = "stats"
    @FocusState private var isFocused: Bool

    private let cols = 40
    private let maxRows = 25

    struct C64Line {
        let text: String
        let color: Color
    }

    static let palette: [Color] = [
        Color(red: 0.00, green: 0.00, blue: 0.00), // 0  Black
        Color(red: 1.00, green: 1.00, blue: 1.00), // 1  White
        Color(red: 0.53, green: 0.00, blue: 0.00), // 2  Red
        Color(red: 0.67, green: 1.00, blue: 0.93), // 3  Cyan
        Color(red: 0.80, green: 0.27, blue: 0.80), // 4  Purple
        Color(red: 0.00, green: 0.80, blue: 0.33), // 5  Green
        Color(red: 0.00, green: 0.00, blue: 0.67), // 6  Blue
        Color(red: 0.93, green: 0.93, blue: 0.47), // 7  Yellow
        Color(red: 0.87, green: 0.53, blue: 0.33), // 8  Orange
        Color(red: 0.40, green: 0.27, blue: 0.00), // 9  Brown
        Color(red: 1.00, green: 0.47, blue: 0.47), // 10 Light Red
        Color(red: 0.20, green: 0.20, blue: 0.20), // 11 Dark Grey
        Color(red: 0.47, green: 0.47, blue: 0.47), // 12 Grey
        Color(red: 0.67, green: 1.00, blue: 0.40), // 13 Light Green
        Color(red: 0.00, green: 0.53, blue: 1.00), // 14 Light Blue
        Color(red: 0.73, green: 0.73, blue: 0.73), // 15 Light Grey
    ]

    private var borderColor: Color { Self.palette[borderColorIdx % 16] }
    private var bgColor: Color { Self.palette[bgColorIdx % 16] }
    private var textColor: Color { Self.palette[14] }

    var body: some View {
        GeometryReader { geo in
            let charW = floor(geo.size.width / CGFloat(cols + 8))
            let charH = charW * 1.2
            let screenW = charW * CGFloat(cols)
            let screenH = charH * CGFloat(maxRows)

            ZStack {
                // Border color fills everything
                borderColor.ignoresSafeArea()

                // Screen background
                Rectangle()
                    .fill(bgColor)
                    .frame(width: screenW, height: screenH)

                // Text content
                Canvas { context, size in
                    let visibleLines = Array(lines.suffix(maxRows - 1))
                    for (i, line) in visibleLines.enumerated() {
                        let text = String(line.text.prefix(cols))
                        let resolved = context.resolve(
                            Text(text)
                                .font(.system(size: charH * 0.8, weight: .regular, design: .monospaced))
                                .foregroundColor(line.color)
                        )
                        context.draw(resolved, at: CGPoint(x: 2, y: CGFloat(i) * charH), anchor: .topLeading)
                    }

                    // Input line with cursor
                    let inputY = CGFloat(visibleLines.count) * charH
                    let displayInput = inputLine + (cursorVisible ? "\u{2588}" : " ")
                    let resolved = context.resolve(
                        Text(displayInput)
                            .font(.system(size: charH * 0.8, weight: .regular, design: .monospaced))
                            .foregroundColor(textColor)
                    )
                    context.draw(resolved, at: CGPoint(x: 2, y: inputY), anchor: .topLeading)
                }
                .frame(width: screenW, height: screenH)
            }
        }
        .background(borderColor)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(phases: [.down, .repeat]) { press in
            if press.key == .return {
                processCommand(inputLine)
                inputLine = ""
                return .handled
            } else if press.key == .delete {
                if !inputLine.isEmpty { inputLine.removeLast() }
                return .handled
            } else if press.key == .escape {
                onExit()
                return .handled
            } else {
                let chars = press.characters.uppercased()
                let printable = chars.filter { c in
                    c.asciiValue.map { $0 >= 32 && $0 < 127 } ?? false
                }
                if !printable.isEmpty && inputLine.count < cols - 1 {
                    inputLine += printable
                    return .handled
                }
                return .handled
            }
        }
        .onAppear {
            isFocused = true
            showBootMessage()
            cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                cursorVisible.toggle()
            }
        }
        .onDisappear {
            cursorTimer?.invalidate()
            cursorTimer = nil
        }
    }

    // MARK: - Boot

    private func showBootMessage() {
        lines = []
        addLine("")
        addLine("    **** COMMODORE 64 BASIC V2 ****", color: textColor)
        addLine("")
        addLine(" 64K RAM SYSTEM  38911 BASIC BYTES FREE", color: textColor)
        addLine("")
        addLine("READY.", color: textColor)
    }

    private func addLine(_ text: String, color: Color? = nil) {
        let c = color ?? textColor
        // Wrap long lines
        var remaining = text
        while !remaining.isEmpty {
            let chunk = String(remaining.prefix(cols))
            lines.append(C64Line(text: chunk, color: c))
            remaining = String(remaining.dropFirst(cols))
        }
        if text.isEmpty {
            lines.append(C64Line(text: "", color: c))
        }
    }

    // MARK: - Command Processing

    private func processCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        addLine(trimmed, color: textColor)

        let upper = trimmed.uppercased()
        let parts = upper.split(separator: " ", maxSplits: 1)
        let cmd = String(parts.first ?? "")
        let arg = parts.count > 1 ? String(parts[1]) : ""

        switch cmd {
        case "LIST":
            listProgram()
        case "RUN":
            runProgram()
        case "LOAD":
            loadProgram(arg)
        case "DIR":
            showDirectory()
        case "PRINT", "?":
            let output = trimmed.dropFirst(cmd.count).trimmingCharacters(in: .whitespaces)
            addLine(output.replacingOccurrences(of: "\"", with: ""), color: textColor)
        case "POKE":
            handlePoke(arg)
        case "SYS":
            handleSys(arg)
        case "HELP":
            showHelp()
        case "NEW":
            lines.removeAll()
        case "CLR":
            lines.removeAll()
        case "":
            break
        default:
            addLine("?SYNTAX  ERROR", color: textColor)
        }

        addLine("READY.", color: textColor)
    }

    private func listProgram() {
        switch currentProgram {
        case "stats":
            let count = store.hikes.count
            let miles = String(format: "%.1f", store.hikes.reduce(0) { $0 + $1.distanceMiles })
            let elev = Int(store.hikes.reduce(0) { $0 + $1.elevationGainFt })
            let streak = store.streakInfo.currentWeeks
            let top = store.trailSummaries().first

            addLine("10 REM *** HIKING LOG ***", color: .white)
            addLine("20 PRINT \"TOTAL HIKES: \(count)\"", color: .white)
            addLine("30 PRINT \"TOTAL MILES: \(miles)\"", color: .white)
            addLine("40 PRINT \"ELEVATION: \(elev) FT\"", color: .white)
            addLine("50 PRINT \"STREAK: \(streak) WEEKS\"", color: .white)
            if let t = top {
                addLine("60 PRINT \"TOP TRAIL:\"", color: .white)
                addLine("70 PRINT \" \(t.name.uppercased().prefix(30))\"", color: .white)
                addLine("80 PRINT \" (HIKED \(t.count)X)\"", color: .white)
            }
            addLine("90 END", color: .white)

        case "trails":
            let loved = trailStore.trails.filter { $0.lovedByShaun == true || $0.lovedByJulie == true }
            let trails = loved.isEmpty ? Array(trailStore.trails.prefix(10)) : Array(loved.prefix(10))
            for (i, t) in trails.enumerated() {
                let n = (i + 1) * 10
                let mi = t.distanceMiles.map { String(format: "%.1f", $0) } ?? "?"
                addLine("\(n) DATA \"\(t.name.uppercased().prefix(22))\",\(mi)", color: .white)
            }

        case "hikes":
            for (i, h) in store.hikes.prefix(12).enumerated() {
                let n = (i + 1) * 10
                let mi = String(format: "%.1f", h.distanceMiles)
                addLine("\(n) DATA \"\(h.trailName.uppercased().prefix(20))\",\(mi),\"\(h.date)\"", color: .white)
            }

        default:
            break
        }
    }

    private func runProgram() {
        switch currentProgram {
        case "stats":
            addLine("")
            addLine("*** HIKING LOG ***", color: Self.palette[13])
            addLine("")
            let count = store.hikes.count
            let miles = String(format: "%.1f", store.hikes.reduce(0) { $0 + $1.distanceMiles })
            let elev = Int(store.hikes.reduce(0) { $0 + $1.elevationGainFt })
            let streak = store.streakInfo.currentWeeks
            addLine("TOTAL HIKES: \(count)", color: .white)
            addLine("TOTAL MILES: \(miles)", color: .white)
            addLine("ELEVATION:   \(elev) FT", color: .white)
            addLine("STREAK:      \(streak) WEEKS", color: .white)
            addLine("")
            addLine("TOP 5 TRAILS:", color: Self.palette[7])
            for (i, t) in store.trailSummaries().prefix(5).enumerated() {
                addLine(" \(i+1). \(t.name.uppercased().prefix(28)) (\(t.count)X)", color: .white)
            }
            addLine("")
            let regions = Dictionary(grouping: store.hikes, by: \.region)
            addLine("REGIONS EXPLORED: \(regions.count)", color: Self.palette[3])

        case "trails":
            addLine("")
            addLine("*** TRAIL GUIDE ***", color: Self.palette[13])
            let loved = trailStore.trails.filter { $0.lovedByShaun == true || $0.lovedByJulie == true }
            let trails = loved.isEmpty ? Array(trailStore.trails.prefix(10)) : Array(loved.prefix(10))
            for t in trails {
                let mi = t.distanceMiles.map { String(format: "%.1fMI", $0) } ?? "  ?MI"
                addLine(" \(t.name.uppercased().prefix(28)) \(mi)", color: .white)
            }

        case "hikes":
            addLine("")
            addLine("*** RECENT HIKES ***", color: Self.palette[13])
            for h in store.hikes.prefix(10) {
                let mi = String(format: "%5.1fMI", h.distanceMiles)
                addLine(" \(h.date) \(mi) \(h.trailName.uppercased().prefix(18))", color: .white)
            }

        default:
            break
        }
    }

    private func loadProgram(_ arg: String) {
        let cleaned = arg.replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: ",8,1", with: "")
            .replacingOccurrences(of: ",8", with: "")
            .trimmingCharacters(in: .whitespaces)
            .uppercased()

        addLine("")
        addLine("SEARCHING FOR \(cleaned)", color: textColor)
        addLine("LOADING", color: textColor)

        switch cleaned {
        case "TRAILS":
            currentProgram = "trails"
        case "HIKES", "HIKE LOG":
            currentProgram = "hikes"
        case "STATS", "*":
            currentProgram = "stats"
        default:
            addLine("?FILE NOT FOUND  ERROR", color: textColor)
            return
        }

        addLine("READY.", color: textColor)
    }

    private func showDirectory() {
        addLine("")
        addLine("0 \"HIKING DISK    \" HK 2A", color: Self.palette[7])
        addLine("5   \"STATS\"           PRG", color: .white)
        addLine("12  \"HIKE LOG\"        PRG", color: .white)
        addLine("3   \"TRAILS\"          PRG", color: .white)
        addLine("1   \"README\"          SEQ", color: .white)
        addLine("639 BLOCKS FREE.", color: .white)
    }

    private func handlePoke(_ arg: String) {
        let parts = arg.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let addr = Int(parts[0]), let val = Int(parts[1]) else {
            addLine("?SYNTAX  ERROR", color: textColor)
            return
        }
        if addr == 53280 { borderColorIdx = val % 16 }
        else if addr == 53281 { bgColorIdx = val % 16 }
    }

    private func handleSys(_ arg: String) {
        let val = Int(arg.trimmingCharacters(in: .whitespaces)) ?? 0
        if val == 64738 {
            showBootMessage()
        } else {
            addLine("?ILLEGAL QUANTITY  ERROR", color: textColor)
        }
    }

    private func showHelp() {
        addLine("")
        addLine("COMMANDS:", color: Self.palette[7])
        addLine(" LIST         - SHOW PROGRAM", color: .white)
        addLine(" RUN          - RUN PROGRAM", color: .white)
        addLine(" LOAD \"X\",8   - LOAD PROGRAM", color: .white)
        addLine("   (STATS, TRAILS, HIKES)", color: Self.palette[12])
        addLine(" DIR          - DISK DIRECTORY", color: .white)
        addLine(" POKE A,V     - POKE MEMORY", color: .white)
        addLine("   (53280=BORDER, 53281=BG)", color: Self.palette[12])
        addLine(" SYS 64738    - RESET", color: .white)
        addLine(" PRINT \"X\"    - PRINT TEXT", color: .white)
        addLine(" CLR          - CLEAR SCREEN", color: .white)
        addLine(" ESC          - EXIT TO 2026", color: .white)
    }
}

#endif
