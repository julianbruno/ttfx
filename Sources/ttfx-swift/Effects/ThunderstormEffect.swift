import Foundation
import TTFXCore

public struct ThunderstormEffect: Effect {
    public struct Configuration: Sendable {
        public var lightningColor: Color
        public var glowingTextColor: Color
        public var textGlowTime: Int
        public var raindropSymbols: [String]
        public var sparkSymbols: [String]
        public var sparkGlowColor: Color
        public var sparkGlowTime: Int
        public var stormTime: Int
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientFrames: Int
        public var finalGradientDirection: GradientDirection

        public init(
            lightningColor: Color = Color(hex: "68A3E8"),
            glowingTextColor: Color = Color(hex: "EF5411"),
            textGlowTime: Int = 6,
            raindropSymbols: [String] = ["\\", ".", ","],
            sparkSymbols: [String] = ["*", ".", "'"],
            sparkGlowColor: Color = Color(hex: "ff4d00"),
            sparkGlowTime: Int = 18,
            stormTime: Int = 12,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientFrames: Int = 3,
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(textGlowTime > 0, "text glow time must be positive")
            precondition(!raindropSymbols.isEmpty, "raindrop symbols must not be empty")
            precondition(!sparkSymbols.isEmpty, "spark symbols must not be empty")
            precondition(sparkGlowTime > 0, "spark glow time must be positive")
            precondition(stormTime > 0, "storm time must be positive")
            precondition(!finalGradientStops.isEmpty, "final gradient stops must not be empty")
            precondition(finalGradientFrames > 0, "final gradient frames must be positive")
            self.lightningColor = lightningColor
            self.glowingTextColor = glowingTextColor
            self.textGlowTime = textGlowTime
            self.raindropSymbols = raindropSymbols
            self.sparkSymbols = sparkSymbols
            self.sparkGlowColor = sparkGlowColor
            self.sparkGlowTime = sparkGlowTime
            self.stormTime = stormTime
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientFrames = finalGradientFrames
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum Phase { case preStorm, waiting, storm, complete }
    private enum Kind { case text, rain, spark, strike }
    private struct Scene {
        var colors: [UInt32]
        var age = 0
        var easing: Easing?
    }
    private struct Motion {
        let origin: Coordinate
        let target: Coordinate
        let control: Coordinate?
        let distance: Double
        let steps: Int
        let easing: Easing
        var step = 0
        var hold: Int
        init(origin: Coordinate, target: Coordinate, control: Coordinate? = nil, speed: Double, easing: Easing = .linear, hold: Int = 0) {
            self.origin = origin; self.target = target; self.control = control
            self.distance = control.map { Geometry.bezierLength(from: origin, controls: [$0], to: target) }
                ?? Geometry.lineLength(from: origin, to: target)
            self.steps = PyCompat.roundHalfEven(distance / speed); self.easing = easing; self.hold = hold
        }
        mutating func advance() -> (Coordinate, Bool) {
            var coordinate = target
            if steps > 0, step < steps, distance > 0 {
                step += 1
                let t = (easing.value(at: Double(step) / Double(steps)) * distance) / distance
                coordinate = control.map { Geometry.coordinateOnBezier(from: origin, controls: [$0], to: target, t: t) }
                    ?? Geometry.coordinateOnLine(from: origin, to: target, t: t)
            }
            if step == steps {
                if hold != 0 { hold -= 1; return (coordinate, false) }
                return (coordinate, true)
            }
            return (coordinate, false)
        }
    }
    private struct Glyph {
        let kind: Kind
        let symbol: UInt32
        var displaySymbol: UInt32
        var coordinate: Coordinate
        var foreground: UInt32
        var layer: Int
        var visible = false
        var active = false
        var motion: Motion?
        var scenes: [String: Scene] = [:]
        var scene: String?
        var lastStrike = false
    }
    private let canvas: Canvas
    private let options: Configuration
    private let frameDuration: Double
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var inputCount = 0
    private var rainPool: [Int] = []
    private var sparkPool: [Int] = []
    private var strikePool: [Int] = []
    private var sparkCount = 0
    private var pendingStrikes: [Int] = []
    private var revealedStrikes: [Int] = []
    private var pendingGlow: [Int] = []
    private var strikeInProgress = false
    private var branchChance = 0.05
    private var strikeDelay = 0
    private var rainDelay = 0
    private var phase = Phase.preStorm
    private var elapsed = 0.0
    private let clock: EffectClock?
    private let clockStart: Double
    private var stormStart = 0.0
    private var sparkColors: [UInt32] = []

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, thunderstormConfiguration: .init())
    }
    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64, thunderstormConfiguration: Configuration) {
        self.clock = configuration.clock
        self.clockStart = configuration.clock?.now() ?? 0
        self.canvas = canvas; self.options = thunderstormConfiguration; self.rng = configuration.makeRNG(seed: seed)
        self.frameDuration = 1 / Double(configuration.frameRate)
        guard !input.scalars.isEmpty else { phase = .complete; return }
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        inputCount = input.scalars.count
        glyphs = coordinates.indices.map { .init(kind: .text, symbol: input.scalars[$0], displaySymbol: input.scalars[$0],
            coordinate: coordinates[$0], foreground: 0, layer: 0, visible: true) }
        for _ in 0..<50 { rainPool.append(makeParticle(.rain)) }
        sparkColors = Self.gradient(options.sparkGlowColor, Color(hex: "000000"), steps: 7, duration: options.sparkGlowTime)
        for _ in 0..<200 { sparkPool.append(makeParticle(.spark)) }
        for _ in 0..<200 { strikePool.append(makeParticle(.strike)) }
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: coordinates.map(\.row).min()!, maxRow: coordinates.map(\.row).max()!,
            minColumn: coordinates.map(\.column).min()!, maxColumn: coordinates.map(\.column).max()!,
            direction: options.finalGradientDirection)).entries.map { ($0.coordinate, $0.color) })
        for id in 0..<inputCount {
            let visible = mapping[coordinates[id]]!
            let storm = rustAdjustedBrightness(visible, factor: 0.5)
            let fade = Self.gradient(visible, storm, steps: 7, duration: 12)
            glyphs[id].scenes = [
                "fade": .init(colors: fade), "unfade": .init(colors: Array(fade.reversed())),
                "glow": .init(colors: Self.gradient(options.glowingTextColor, storm, steps: 7, duration: options.textGlowTime)),
                "flash": .init(colors: Self.gradient(storm, rustAdjustedBrightness(visible, factor: 1.7), steps: 7, duration: 6, loop: true))]
        }
    }
    private mutating func makeParticle(_ kind: Kind) -> Int {
        let symbols: [String]
        let layer: Int
        switch kind {
        case .rain: symbols = options.raindropSymbols; layer = 1
        case .spark: symbols = options.sparkSymbols; layer = 2
        default: symbols = ["|"]; layer = 0
        }
        let symbol = kind == .strike ? UInt32(124) : symbols[rng.integer(in: symbols.indices)].unicodeScalars.first!.value
        let id = glyphs.count
        var glyph = Glyph(kind: kind, symbol: symbol, displaySymbol: symbol, coordinate: .init(column: 0, row: 0),
            foreground: kind == .rain ? 0xaaaaff : 0, layer: layer)
        if kind == .spark { glyph.scenes["glow"] = .init(colors: sparkColors, easing: .inCirc); sparkCount += 1 }
        glyphs.append(glyph)
        return id
    }
    private mutating func activateScene(_ id: Int, _ name: String) {
        glyphs[id].scene = name
        let scene = glyphs[id].scenes[name]!
        // Eased scenes retain their source frames; activation shows the first one.
        glyphs[id].foreground = scene.colors[scene.easing == nil ? scene.age : 0]
    }
    private mutating func rain() {
        if rainDelay != 0 { rainDelay -= 1; return }
        let count = rng.integer(in: 1...6)
        for _ in 0..<count {
            let column = rng.integer(in: (1 - canvas.rows)...canvas.columns)
            let origin = Coordinate(column: column - 1, row: canvas.rows + 1)
            let id = rainPool.popLast() ?? makeParticle(.rain)
            let speed = rng.uniform(0.5, 1.5)
            glyphs[id].coordinate = origin; glyphs[id].visible = true; glyphs[id].active = true
            glyphs[id].motion = .init(origin: origin, target: .init(column: origin.column + canvas.rows + 1, row: 0), speed: speed)
            glyphs[id].scene = nil
        }
        rainDelay = rng.integer(in: 1...7)
    }
    private mutating func setupStrike(neighbor: Int? = nil) {
        var neighbor = neighbor
        var column = neighbor.map { glyphs[$0].coordinate.column } ?? rng.integer(in: 1...canvas.columns)
        var row = neighbor.map { glyphs[$0].coordinate.row } ?? canvas.rows
        while row >= 1 {
            let symbol: UInt32
            if neighbor != nil {
                let delta = [-1, 1][rng.integer(in: 0...1)]
                column += delta; symbol = delta == 1 ? 92 : 47
            } else { symbol = [UInt32(92), 47, 124][rng.integer(in: 0...2)] }
            if strikePool.isEmpty { for _ in 0..<20 { strikePool.append(makeParticle(.strike)) } }
            let id = strikePool.removeLast()
            glyphs[id].scenes.removeAll(); glyphs[id].scene = nil; glyphs[id].lastStrike = false
            glyphs[id].coordinate = .init(column: column, row: row)
            glyphs[id].displaySymbol = symbol; glyphs[id].foreground = Self.rgb(options.lightningColor)
            row -= 1
            if symbol == 92 { column += 1 } else if symbol == 47 { column -= 1 }
            pendingStrikes.append(id)
            if rng.random() < branchChance, neighbor == nil {
                branchChance -= 0.01; setupStrike(neighbor: id)
            }
            neighbor = nil
        }
        branchChance = 0.05
    }
    private mutating func lightning() {
        setupStrike()
        let flash = Self.gradient(options.lightningColor, rustAdjustedBrightness(options.lightningColor, factor: 1.7),
            steps: 7, duration: 6, loop: true)
        let fade = Self.gradient(options.lightningColor, Color(hex: "000000"), steps: 6, duration: 2)
        let easing = Easing.cubicBezier(0, 1.6, 1, rng.uniform(-0.6, 0.4))
        for id in pendingStrikes {
            glyphs[id].scenes["flash"] = .init(colors: flash, easing: easing)
            glyphs[id].scenes["fade"] = .init(colors: fade)
            glyphs[id].layer = 1
        }
        for id in 0..<inputCount { glyphs[id].scenes["flash"]!.easing = easing }
    }
    private mutating func emitSparks(at origin: Coordinate) {
        let count = rng.integer(in: 12...18)
        for _ in 0..<count {
            if sparkPool.isEmpty, sparkCount >= 2000 { continue }
            let id = sparkPool.popLast() ?? makeParticle(.spark)
            let speed = rng.uniform(0.1, 0.25)
            let offset = rng.integer(in: 4...20) * [1, -1][rng.integer(in: 0...1)]
            let target = Coordinate(column: origin.column + offset, row: 1)
            let control = Coordinate(column: origin.column - Int(floor(Double(origin.column - target.column) / 2)),
                row: rng.integer(in: 1...canvas.rows))
            glyphs[id].coordinate = origin
            glyphs[id].motion = .init(origin: origin, target: target, control: control, speed: speed, easing: .outQuint, hold: 30)
            activateScene(id, "glow")
            glyphs[id].visible = true; glyphs[id].active = true
        }
    }
    private mutating func stepStrike() {
        if strikeDelay != 0 { strikeDelay -= 1; return }
        if !pendingStrikes.isEmpty {
            let count = rng.integer(in: 1...3)
            for _ in 0..<count where !pendingStrikes.isEmpty {
                let id = pendingStrikes.removeFirst()
                revealedStrikes.append(id); glyphs[id].visible = true; strikeDelay = 1
                if pendingStrikes.isEmpty {
                    emitSparks(at: glyphs[id].coordinate)
                    glyphs[id].lastStrike = true
                    for strike in revealedStrikes { activateScene(strike, "flash"); glyphs[strike].active = true }
                    revealedStrikes.removeAll()
                    for text in 0..<inputCount { activateScene(text, "flash"); glyphs[text].active = true }
                }
            }
        }
    }
    private mutating func sceneComplete(_ id: Int, _ name: String) {
        switch glyphs[id].kind {
        case .text:
            if id == 0, name == "fade" { phase = .storm; stormStart = elapsed }
        case .rain: break
        case .spark:
            glyphs[id].visible = false; glyphs[id].motion = nil; glyphs[id].scene = nil; glyphs[id].active = false
            sparkPool.append(id)
        case .strike:
            if name == "flash" { activateScene(id, "fade") }
            else if name == "fade" {
                glyphs[id].visible = false
                if let text = (0..<inputCount).first(where: { glyphs[$0].coordinate == glyphs[id].coordinate }) {
                    activateScene(text, "glow"); pendingGlow.append(text)
                }
                strikePool.append(id)
                if glyphs[id].lastStrike { strikeInProgress = false }
            }
        }
    }
    public mutating func tick(into frame: inout Frame) -> TickStatus {
        if let clock { elapsed = clock.now() - clockStart }
        guard phase != .complete || glyphs.contains(where: \.active) else { return .complete }
        switch phase {
        case .preStorm:
            for id in 0..<inputCount { activateScene(id, "fade"); glyphs[id].active = true }
            phase = .waiting
        case .storm:
            rain()
            if !strikeInProgress, rng.random() < 0.008 { strikeInProgress = true; lightning() }
            if strikeInProgress { stepStrike() }
            for id in pendingGlow { glyphs[id].active = true }; pendingGlow.removeAll()
            if elapsed - stormStart >= Double(options.stormTime), !strikeInProgress {
                for id in 0..<inputCount { activateScene(id, "unfade"); glyphs[id].active = true }
                phase = .complete
            }
        case .waiting, .complete: break
        }
        let active = glyphs.indices.filter { glyphs[$0].active }
        for id in active {
            if var motion = glyphs[id].motion {
                let (coordinate, complete) = motion.advance()
                glyphs[id].coordinate = coordinate; glyphs[id].motion = complete ? nil : motion
                if complete, glyphs[id].kind == .rain {
                    glyphs[id].visible = false; glyphs[id].active = false; rainPool.append(id)
                }
            }
            if let name = glyphs[id].scene {
                var scene = glyphs[id].scenes[name]!
                let index: Int
                if let easing = scene.easing {
                    index = min(scene.colors.count - 1, max(0, PyCompat.roundHalfEven(
                        easing.value(at: Double(scene.age) / Double(scene.colors.count)) * Double(scene.colors.count - 1))))
                } else { index = scene.age }
                glyphs[id].foreground = scene.colors[index]
                scene.age += 1
                let complete = scene.age == scene.colors.count
                if complete { scene.age = 0; glyphs[id].scene = nil }
                glyphs[id].scenes[name] = scene
                if complete { sceneComplete(id, name) }
            }
            glyphs[id].active = glyphs[id].motion != nil || glyphs[id].scene != nil
        }
        let ordered = glyphs.indices.filter { glyphs[$0].visible }.sorted {
            glyphs[$0].layer == glyphs[$1].layer ? $0 < $1 : glyphs[$0].layer < glyphs[$1].layer
        }
        for id in ordered {
            let glyph = glyphs[id]
            if (1...canvas.columns).contains(glyph.coordinate.column), (1...canvas.rows).contains(glyph.coordinate.row) {
                frame[column: glyph.coordinate.column, row: glyph.coordinate.row] = .init(codepoint: glyph.displaySymbol,
                    foreground: glyph.foreground, background: glyph.foreground == 0 ? 0xFFFF_FFFE : 0)
            }
        }
        if clock == nil { elapsed += frameDuration }
        return phase == .complete && !glyphs.contains(where: \.active) ? .complete : .running
    }
    private static func rgb(_ color: Color) -> UInt32 { UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue) }
    private static func gradient(_ from: Color, _ to: Color, steps: Int, duration: Int, loop: Bool = false) -> [UInt32] {
        (try! Gradient(stops: [from, to], steps: steps, loop: loop)).spectrum.flatMap { Array(repeating: rgb($0), count: duration) }
    }
}
