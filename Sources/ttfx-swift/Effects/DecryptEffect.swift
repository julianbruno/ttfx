import TTFXCore

public struct DecryptEffect: Effect {
    public struct Configuration: Sendable {
        public var typingSpeed: Int
        public var ciphertextColors: [Color]
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            typingSpeed: Int = 2,
            ciphertextColors: [Color] = [Color(hex: "008000"), Color(hex: "00cb00"), Color(hex: "00ff00")],
            finalGradientStops: [Color] = [Color(hex: "eda000")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(typingSpeed > 0, "typing speed must be positive")
            precondition(!ciphertextColors.isEmpty, "ciphertext colors must not be empty")
            precondition(!finalGradientStops.isEmpty, "final gradient stops must not be empty")
            self.typingSpeed = typingSpeed
            self.ciphertextColors = ciphertextColors
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum Phase { case typing, decrypting, done }
    private enum SceneKind { case typing, fast, slow, discovered }

    private struct Visual {
        let codepoint: UInt32
        let foreground: UInt32
        let duration: Int
    }

    private struct Glyph {
        let id: Int
        let coordinate: Coordinate
        let inputSymbol: UInt32
        let typingFrames: [Visual]
        var fastFrames: [Visual]
        var slowFrames: [Visual]
        var discoveredFrames: [Visual]
        var visible = false
        var active = false
        var scene: SceneKind = .typing
        var frameIndex = 0
        var ticksElapsed = 0
        var rendered: Visual?

        var frames: [Visual] {
            switch scene {
            case .typing: return typingFrames
            case .fast: return fastFrames
            case .slow: return slowFrames
            case .discovered: return discoveredFrames
            }
        }
    }

    private let canvas: Canvas
    private let input: InputText
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var typingPending: [Int] = []
    private var decryptingPending: [Int] = []
    private var phase: Phase = .typing
    private var tickIndex = 0
    private var isBuilt = false
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, decryptConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        decryptConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.input = input
        self.options = decryptConfiguration
        self.rng = Xoshiro256PlusPlus(seed: seed)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        defer { tickIndex += 1 }
        if !isBuilt { build() }
        guard !glyphs.isEmpty else {
            isComplete = true
            return .complete
        }

        switch phase {
        case .typing:
            if !typingPending.isEmpty || glyphs.contains(where: { $0.active }) {
                if !typingPending.isEmpty && rng.integer(in: 0...100) <= 75 {
                    for _ in 0..<options.typingSpeed where !typingPending.isEmpty {
                        let index = typingPending.removeFirst()
                        glyphs[index].visible = true
                        activate(index, scene: .typing)
                    }
                }
                advanceActiveScenes()
                render(into: &frame)
                return .running
            }

            for index in decryptingPending {
                activate(index, scene: .fast)
            }
            phase = .decrypting
            fallthrough

        case .decrypting:
            if glyphs.contains(where: { $0.active }) {
                advanceActiveScenes()
                render(into: &frame)
                if !glyphs.contains(where: { $0.active }) {
                    isComplete = true
                    return .complete
                }
                return .running
            }
            isComplete = true
            return .complete

        case .done:
            isComplete = true
            return .complete
        }
    }

    private mutating func build() {
        isBuilt = true
        let encryptedSymbols = Self.encryptedSymbols
        let finalColors = finalColorMapping()
        var builtGlyphs: [Glyph] = []
        builtGlyphs.reserveCapacity(input.scalars.count)

        for (id, pair) in zip(input.scalars, input.positions).enumerated() {
            let coordinate = Coordinate(column: pair.1.column, row: pair.1.row)
            var typingFrames: [Visual] = []
            typingFrames.reserveCapacity(5)
            for block in ["▉", "▓", "▒", "░"] {
                typingFrames.append(Visual(
                    codepoint: block.unicodeScalars.first!.value,
                    foreground: rgb(choice(options.ciphertextColors)),
                    duration: 2
                ))
            }
            typingFrames.append(Visual(
                codepoint: choice(encryptedSymbols),
                foreground: rgb(choice(options.ciphertextColors)),
                duration: 1
            ))

            builtGlyphs.append(Glyph(id: id, coordinate: coordinate, inputSymbol: pair.0,
                typingFrames: typingFrames, fastFrames: [], slowFrames: [], discoveredFrames: []))
        }
        // Rust constructs all typing scenes before consuming randomness for
        // any decrypt scene; interleaving changes every later RNG draw.
        for index in builtGlyphs.indices {
            let decryptColor = rgb(choice(options.ciphertextColors))
            builtGlyphs[index].fastFrames = (0..<80).map { _ in
                Visual(codepoint: choice(encryptedSymbols), foreground: decryptColor, duration: 2)
            }
            let slowCount = rng.integer(in: 1...15)
            builtGlyphs[index].slowFrames = (0..<slowCount).map { _ in
                let symbol = choice(encryptedSymbols)
                let duration = rng.integer(in: 0...100) <= 30 ? rng.integer(in: 35..<60) : rng.integer(in: 3..<6)
                return Visual(codepoint: symbol, foreground: decryptColor, duration: duration)
            }
            let final = finalColors[builtGlyphs[index].coordinate] ?? rgb(options.finalGradientStops[0])
            builtGlyphs[index].discoveredFrames = (try! Gradient(stops: [Color(hex: "ffffff"), color(fromRGB: final)], steps: [10])).spectrum.map {
                Visual(codepoint: builtGlyphs[index].inputSymbol, foreground: rgb($0), duration: 5)
            }
        }
        glyphs = builtGlyphs
        typingPending = Array(glyphs.indices)
        decryptingPending = Array(glyphs.indices)
    }

    private func finalColorMapping() -> [Coordinate: UInt32] {
        guard !input.positions.isEmpty else { return [:] }
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = try! gradient.coordinateColorMapping(
            minRow: coordinates.map(\.row).min()!,
            maxRow: coordinates.map(\.row).max()!,
            minColumn: coordinates.map(\.column).min()!,
            maxColumn: coordinates.map(\.column).max()!,
            direction: options.finalGradientDirection
        )
        return Dictionary(uniqueKeysWithValues: mapping.entries.map { ($0.coordinate, rgb($0.color)) })
    }

    private mutating func activate(_ index: Int, scene: SceneKind) {
        glyphs[index].active = true
        glyphs[index].scene = scene
        glyphs[index].frameIndex = 0
        glyphs[index].ticksElapsed = 0
        glyphs[index].rendered = glyphs[index].frames.first
    }

    private mutating func advanceActiveScenes() {
        for index in glyphs.indices where glyphs[index].active {
            if glyphs[index].ticksElapsed < 0 {
                glyphs[index].ticksElapsed = 0
                continue
            }
            let frames = glyphs[index].frames
            guard !frames.isEmpty else {
                glyphs[index].active = false
                continue
            }
            let visual = frames[glyphs[index].frameIndex]
            glyphs[index].rendered = visual
            glyphs[index].ticksElapsed += 1
            guard glyphs[index].ticksElapsed >= visual.duration else { continue }
            glyphs[index].ticksElapsed = 0
            if glyphs[index].frameIndex + 1 < frames.count {
                glyphs[index].frameIndex += 1
            } else {
                switch glyphs[index].scene {
                case .typing:
                    glyphs[index].active = false
                case .fast:
                    activate(index, scene: .slow)
                case .slow:
                    activate(index, scene: .discovered)
                case .discovered:
                    glyphs[index].active = false
                }
            }
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            var winners: [Int: (id: Int, visual: Visual)] = [:]
            for glyph in glyphs where glyph.visible {
                guard let visual = glyph.rendered,
                      (1...canvas.columns).contains(glyph.coordinate.column),
                      (1...canvas.rows).contains(glyph.coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
                if let winner = winners[cellIndex], winner.id > glyph.id { continue }
                winners[cellIndex] = (glyph.id, visual)
            }
            for (index, winner) in winners {
                cells[index] = Cell(codepoint: winner.visual.codepoint, foreground: winner.visual.foreground, background: 0)
            }
        }
    }

    private mutating func choice<T>(_ values: [T]) -> T {
        values[rng.integer(in: 0..<values.count)]
    }

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }

    private func color(fromRGB value: UInt32) -> Color {
        Color(hex: String(format: "%02x%02x%02x", (value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff))
    }

    private static let encryptedSymbols: [UInt32] = {
        var symbols: [UInt32] = []
        symbols.append(contentsOf: 33..<127)
        symbols.append(contentsOf: 9608..<9632)
        symbols.append(contentsOf: 9472..<9599)
        symbols.append(contentsOf: 174..<452)
        return symbols
    }()
}
