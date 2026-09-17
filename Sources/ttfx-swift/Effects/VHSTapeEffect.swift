import TTFXCore

public struct VHSTapeEffect: Effect {
    public struct Configuration: Sendable {
        public var glitchLineColors: [Color]
        public var glitchWaveColors: [Color]
        public var noiseColors: [Color]
        public var glitchLineChance: Double
        public var noiseChance: Double
        public var totalGlitchTime: Int
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            glitchLineColors: [Color] = [Color(hex: "ffffff"), Color(hex: "ff0000"), Color(hex: "00ff00"), Color(hex: "0000ff"), Color(hex: "ffffff")],
            glitchWaveColors: [Color] = [Color(hex: "ffffff"), Color(hex: "ff0000"), Color(hex: "00ff00"), Color(hex: "0000ff"), Color(hex: "ffffff")],
            noiseColors: [Color] = [Color(hex: "1e1e1f"), Color(hex: "3c3b3d"), Color(hex: "6d6c70"), Color(hex: "a2a1a6"), Color(hex: "cbc9cf"), Color(hex: "ffffff")],
            glitchLineChance: Double = 0.05,
            noiseChance: Double = 0.004,
            totalGlitchTime: Int = 600,
            finalGradientStops: [Color] = [Color(hex: "ab48ff"), Color(hex: "e7b2b2"), Color(hex: "fffebd")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(!glitchLineColors.isEmpty, "glitch line colors must not be empty")
            precondition(!glitchWaveColors.isEmpty, "glitch wave colors must not be empty")
            precondition(!noiseColors.isEmpty, "noise colors must not be empty")
            precondition(totalGlitchTime > 0, "total glitch time must be positive")
            precondition(!finalGradientStops.isEmpty, "final gradient stops must not be empty")
            self.glitchLineColors = glitchLineColors
            self.glitchWaveColors = glitchWaveColors
            self.noiseColors = noiseColors
            self.glitchLineChance = glitchLineChance
            self.noiseChance = noiseChance
            self.totalGlitchTime = totalGlitchTime
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum Phase { case glitching, noise, redraw, complete }
    private enum Scene: Int { case base, forward, backward, snow, finalSnow, redraw }
    private enum Path { case glitch, restore, mid, end }
    private struct Motion {
        let kind: Path
        let origin: Coordinate
        let target: Coordinate
        let distance: Double
        let steps: Int
        var step = 0
        var hold: Int
        init(kind: Path, origin: Coordinate, target: Coordinate, speed: Double, hold: Int) {
            self.kind = kind; self.origin = origin; self.target = target
            self.distance = Geometry.lineLength(from: origin, to: target)
            self.steps = PyCompat.roundHalfEven(distance / speed); self.hold = hold
        }
        mutating func advance() -> (Coordinate, Bool) {
            var coordinate = target
            if steps > 0, step < steps, distance > 0 {
                step += 1
                let t = (Double(step) / Double(steps) * distance) / distance
                coordinate = Geometry.coordinateOnLine(from: origin, to: target, t: t)
            }
            if step == steps {
                if hold != 0 { hold -= 1; return (coordinate, false) }
                return (coordinate, true)
            }
            return (coordinate, false)
        }
    }
    private struct Glyph {
        let source: Coordinate
        let target: Coordinate
        var coordinate: Coordinate
        var visual: Cell
        var frames: [[Cell]]
        var cursors = Array(repeating: 0, count: 6)
        var scene: Scene? = .base
        var motion: Motion?
        var hold: Int
        var glitchSpeed = 2.0
        var restoreSpeed = 2.0
        var active = false
    }
    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var lines: [[Int]] = []
    private var glitchLines: [Int] = []
    private var wave: [Int] = []
    private var waveTop: Int?
    private var bottom = 1
    private var top = 1
    private var elapsed = 0
    private var phase = Phase.glitching
    private var redrawing = false
    private var redrawRows: [Int] = []

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, vhsTapeConfiguration: .init())
    }
    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64, vhsTapeConfiguration: Configuration) {
        self.canvas = canvas; self.options = vhsTapeConfiguration; self.rng = .init(seed: seed)
        guard !input.scalars.isEmpty else { phase = .complete; return }
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        bottom = coordinates.map(\.row).min()!; top = coordinates.map(\.row).max()!
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(minRow: bottom, maxRow: top,
            minColumn: coordinates.map(\.column).min()!, maxColumn: coordinates.map(\.column).max()!,
            direction: options.finalGradientDirection)).entries.map { ($0.coordinate, $0.color) })
        glyphs = coordinates.indices.map { .init(source: coordinates[$0], target: coordinates[$0], coordinate: coordinates[$0],
            visual: Self.cell(input.scalars[$0], mapping[coordinates[$0]]!), frames: [], hold: 0) }
        let symbols: [UInt32] = [35, 42, 46, 58]
        for row in Set(coordinates.map(\.row)).sorted() {
            let ids = coordinates.indices.filter { coordinates[$0].row == row }.sorted { coordinates[$0].column < coordinates[$1].column }
            lines.append(ids)
            let offset = rng.integer(in: 4...25)
            let direction = [-1, 1][rng.integer(in: 0...1)]
            let hold = rng.integer(in: 1...50)
            for id in ids {
                let stable = glyphs[id].visual
                let forward = options.glitchLineColors.map { Self.cell(input.scalars[id], $0) }
                var snow: [Cell] = []
                var finalSnow: [Cell] = []
                for _ in 0..<25 {
                    let symbol = symbols[rng.integer(in: symbols.indices)]
                    let color = options.noiseColors[rng.integer(in: options.noiseColors.indices)]
                    snow += Array(repeating: Self.cell(symbol, color), count: 2)
                }
                for _ in 0..<30 {
                    let symbol = symbols[rng.integer(in: symbols.indices)]
                    let color = options.noiseColors[rng.integer(in: options.noiseColors.indices)]
                    finalSnow += Array(repeating: Self.cell(symbol, color), count: 2)
                }
                glyphs[id] = .init(source: coordinates[id], target: .init(column: coordinates[id].column + offset * direction, row: row),
                    coordinate: coordinates[id], visual: stable,
                    frames: [[stable], forward, Array(forward.reversed()), snow + [stable], finalSnow,
                        Array(repeating: Self.cell(0x2588, Color(hex: "ffffff")), count: 6) + [stable]], hold: hold)
            }
        }
        redrawRows = Array(lines.indices)
    }
    private mutating func activateScene(_ id: Int, _ scene: Scene) {
        glyphs[id].scene = scene
        glyphs[id].visual = glyphs[id].frames[scene.rawValue][glyphs[id].cursors[scene.rawValue]]
    }
    private mutating func activatePath(_ id: Int, _ kind: Path) {
        let target: Coordinate
        let speed: Double
        switch kind {
        case .glitch: target = glyphs[id].target; speed = glyphs[id].glitchSpeed
        case .restore: target = glyphs[id].source; speed = glyphs[id].restoreSpeed
        case .mid: target = .init(column: glyphs[id].source.column + 8, row: glyphs[id].source.row); speed = 2
        case .end: target = .init(column: glyphs[id].source.column + 14, row: glyphs[id].source.row); speed = 2
        }
        glyphs[id].motion = .init(kind: kind, origin: glyphs[id].coordinate, target: target, speed: speed,
            hold: kind == .glitch ? glyphs[id].hold : 0)
        activateScene(id, kind == .restore ? .backward : .forward)
    }
    private mutating func restore(_ line: Int, activate: Bool) {
        for id in lines[line] {
            glyphs[id].restoreSpeed = 40 / Double(rng.integer(in: 20...40))
            activatePath(id, .restore)
            if activate { glyphs[id].active = true }
        }
    }
    private mutating func glitchWave() {
        if waveTop == nil {
            let height = top - bottom + 1
            guard height >= 3 else { return }
            waveTop = bottom + rng.integer(in: max(3, PyCompat.roundHalfEven(Double(height) * 0.5))...height)
        }
        if !wave.isEmpty, wave.allSatisfy({ lines[$0].allSatisfy { glyphs[$0].motion == nil } }) {
            if rng.random() < 0.3 {
                waveTop! += rng.random() < 0.3 ? 1 : -1
            }
            waveTop = max(2, min(waveTop!, top))
        }
        let next = ((waveTop! - 2)...waveTop!).map { $0 - (bottom - 1) }.filter { lines.indices.contains($0) }
        for line in wave where !next.contains(line) { restore(line, activate: true) }
        wave = next
        if waveTop! < bottom + 2 {
            for line in wave { restore(line, activate: true) }
            wave.removeAll(); waveTop = nil
        } else {
            for (line, kind) in zip(wave, [Path.mid, .end, .mid]) {
                for id in lines[line] { activatePath(id, kind); glyphs[id].active = true }
            }
        }
    }
    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard phase != .complete || glyphs.contains(where: \.active) else { return .complete }
        switch phase {
        case .glitching:
            if wave.isEmpty || wave.allSatisfy({ lines[$0].allSatisfy { glyphs[$0].motion == nil } }) { glitchWave() }
            glitchLines.removeAll { line in lines[line].allSatisfy { glyphs[$0].motion == nil } }
            if rng.random() < options.glitchLineChance, glitchLines.count < 3 {
                let line = rng.integer(in: lines.indices)
                if !wave.contains(line), !glitchLines.contains(line) {
                    let hold = rng.integer(in: 20...75)
                    glitchLines.append(line)
                    for id in lines[line] {
                        glyphs[id].hold = hold
                        glyphs[id].glitchSpeed = 40 / Double(rng.integer(in: 20...40))
                        glyphs[id].restoreSpeed = 40 / Double(rng.integer(in: 20...40))
                        activatePath(id, .glitch); glyphs[id].active = true
                    }
                }
            }
            if rng.random() < options.noiseChance {
                for line in lines.indices {
                    for id in lines[line] {
                        activateScene(id, .snow)
                        if !wave.contains(line), !glitchLines.contains(line) { glyphs[id].active = true }
                    }
                }
            }
            elapsed += 1
            if elapsed >= options.totalGlitchTime {
                for line in wave { restore(line, activate: false) }
                for line in glitchLines { restore(line, activate: false) }
                phase = .noise
            }
        case .noise:
            if !glyphs.contains(where: \.active) {
                for id in glyphs.indices { activateScene(id, .finalSnow); glyphs[id].active = true }
                phase = .redraw
            }
        case .redraw:
            if !glyphs.contains(where: \.active) { redrawing = true }
            if redrawing {
                if let row = redrawRows.popLast() {
                    for id in lines[row] { activateScene(id, .redraw); glyphs[id].active = true }
                } else { phase = .complete }
            }
        case .complete: break
        }
        for id in glyphs.indices where glyphs[id].active {
            if var motion = glyphs[id].motion {
                let (coordinate, complete) = motion.advance()
                glyphs[id].coordinate = coordinate
                glyphs[id].motion = complete ? nil : motion
                if complete, motion.kind == .glitch { activatePath(id, .restore) }
            }
            if let scene = glyphs[id].scene {
                let index = scene.rawValue
                let frames = glyphs[id].frames[index]
                var complete = false
                if scene == .forward || scene == .backward {
                    if let path = glyphs[id].motion {
                        let progress = Double(max(path.step, 1)) / Double(max(path.steps, 1))
                        let selected = min(frames.count - 1, max(0, PyCompat.roundHalfEven(Double(frames.count - 1) * progress)))
                        glyphs[id].visual = frames[selected]
                    } else { glyphs[id].visual = frames.last!; complete = true }
                } else {
                    glyphs[id].visual = frames[glyphs[id].cursors[index]]
                    glyphs[id].cursors[index] += 1
                    complete = glyphs[id].cursors[index] == frames.count
                }
                if complete {
                    glyphs[id].cursors[index] = 0; glyphs[id].scene = nil
                    if scene == .backward { activateScene(id, .base) }
                }
            }
            glyphs[id].active = glyphs[id].motion != nil || glyphs[id].scene != nil
        }
        for glyph in glyphs {
            if (1...canvas.columns).contains(glyph.coordinate.column), (1...canvas.rows).contains(glyph.coordinate.row) {
                frame[column: glyph.coordinate.column, row: glyph.coordinate.row] = glyph.visual
            }
        }
        return phase == .complete && !glyphs.contains(where: \.active) ? .complete : .running
    }
    private static func cell(_ symbol: UInt32, _ color: Color) -> Cell {
        let rgb = UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
        return .init(codepoint: symbol, foreground: rgb, background: rgb == 0 ? 0xFFFF_FFFE : 0)
    }
}
