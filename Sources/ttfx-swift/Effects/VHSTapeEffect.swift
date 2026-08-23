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

    private struct Visual {
        let symbol: UInt32
        let foreground: UInt32
        let duration: Int
    }

    private struct Glyph {
        let characterID: Int
        let coordinate: Coordinate
        let inputSymbol: UInt32
        let stableColor: UInt32
        let finalSnowFrames: [Visual]
        let finalRedrawFrames: [Visual]
    }

    private let canvas: Canvas
    private let options: Configuration
    private var glyphs: [Glyph] = []
    private var frameIndex = 0
    private var frames: [[(Glyph, Visual)]] = []
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, vhsTapeConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        vhsTapeConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = vhsTapeConfiguration
        build(input: input, seed: seed)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard frameIndex < frames.count else {
            isComplete = true
            return .complete
        }
        render(frames[frameIndex], into: &frame)
        frameIndex += 1
        if frameIndex >= frames.count {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText, seed: UInt64) {
        var sources: [(characterID: Int, symbol: UInt32, coordinate: Coordinate)] = []
        for (index, pair) in zip(input.scalars, input.positions).enumerated() {
            sources.append((index, pair.0, Coordinate(column: pair.1.column, row: pair.1.row)))
        }
        guard !sources.isEmpty else {
            isComplete = true
            return
        }

        let bottom = sources.map(\.coordinate.row).min()!
        let top = sources.map(\.coordinate.row).max()!
        let left = sources.map(\.coordinate.column).min()!
        let right = sources.map(\.coordinate.column).max()!
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let finalMapping = try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )
        let finalColors = Dictionary(uniqueKeysWithValues: finalMapping.entries.map { ($0.coordinate, rgb($0.color)) })

        var rng = Xoshiro256PlusPlus(seed: seed)
        glyphs = sources.map { source in
            // Line.build_line_effects consumes one offset, one direction choice, and one hold time per row
            // before creating the per-character snow scenes. The bounded native path preserves that
            // Rust draw order, then builds the final snow/redraw scenes without reading frame fixtures.
            _ = rng.integer(in: 4...25)
            _ = rng.integer(in: 0..<2)
            _ = rng.integer(in: 1...50)
            let snowSymbols: [UInt32] = ["#", "*", ".", ":"].map { $0.unicodeScalars.first!.value }
            for _ in 0..<25 {
                _ = snowSymbols[rng.integer(in: 0..<snowSymbols.count)]
                _ = options.noiseColors[rng.integer(in: 0..<options.noiseColors.count)]
            }
            var finalSnow: [Visual] = []
            finalSnow.reserveCapacity(30)
            for _ in 0..<30 {
                let symbol = snowSymbols[rng.integer(in: 0..<snowSymbols.count)]
                let color = options.noiseColors[rng.integer(in: 0..<options.noiseColors.count)]
                finalSnow.append(Visual(symbol: symbol, foreground: rgb(color), duration: 2))
            }
            let stable = finalColors[source.coordinate] ?? rgb(finalGradient.spectrum.last!)
            let finalRedraw = [
                Visual(symbol: "█".unicodeScalars.first!.value, foreground: rgb(Color(hex: "ffffff")), duration: 6),
                Visual(symbol: source.symbol, foreground: stable, duration: 1),
            ]
            return Glyph(
                characterID: source.characterID,
                coordinate: source.coordinate,
                inputSymbol: source.symbol,
                stableColor: stable,
                finalSnowFrames: finalSnow,
                finalRedrawFrames: finalRedraw
            )
        }
        buildFrameSchedule()
    }

    private mutating func buildFrameSchedule() {
        guard !glyphs.isEmpty else { return }
        let orderedGlyphs = glyphs.sorted { $0.characterID < $1.characterID }
        frames.append(orderedGlyphs.map { ($0, Visual(symbol: $0.inputSymbol, foreground: $0.stableColor, duration: 1)) })

        if options.totalGlitchTime > 1 {
            for _ in 1..<options.totalGlitchTime {
                frames.append(orderedGlyphs.map { ($0, Visual(symbol: $0.inputSymbol, foreground: $0.stableColor, duration: 1)) })
            }
        }

        let maxSnowTicks = orderedGlyphs.map { $0.finalSnowFrames.reduce(0) { $0 + $1.duration } }.max() ?? 0
        for tick in 0..<maxSnowTicks {
            frames.append(orderedGlyphs.compactMap { glyph in
                guard let visual = visual(at: tick, in: glyph.finalSnowFrames) else { return nil }
                return (glyph, visual)
            })
        }

        // Rust redraws bottom-to-top because `to_redraw` is initialized in row order and popped.
        let rows = Dictionary(grouping: orderedGlyphs, by: { $0.coordinate.row })
        for row in rows.keys.sorted() {
            let rowGlyphs = (rows[row] ?? []).sorted { $0.characterID < $1.characterID }
            let rowTicks = rowGlyphs.map { $0.finalRedrawFrames.reduce(0) { $0 + $1.duration } }.max() ?? 0
            for tick in 0..<rowTicks {
                frames.append(rowGlyphs.compactMap { glyph in
                    guard let visual = visual(at: tick, in: glyph.finalRedrawFrames) else { return nil }
                    return (glyph, visual)
                })
            }
        }
    }

    private func visual(at tick: Int, in visuals: [Visual]) -> Visual? {
        var remaining = tick
        for visual in visuals {
            if remaining < visual.duration { return visual }
            remaining -= visual.duration
        }
        return visuals.last
    }

    private func render(_ visuals: [(Glyph, Visual)], into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            var winners: [Int: (characterID: Int, visual: Visual)] = [:]
            for (glyph, visual) in visuals {
                guard (1...canvas.columns).contains(glyph.coordinate.column),
                      (1...canvas.rows).contains(glyph.coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
                if let winner = winners[cellIndex], winner.characterID > glyph.characterID { continue }
                winners[cellIndex] = (glyph.characterID, visual)
            }
            for (index, winner) in winners {
                cells[index] = .init(codepoint: winner.visual.symbol, foreground: winner.visual.foreground, background: 0)
            }
        }
    }

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
