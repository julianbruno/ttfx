import TTFXCore

public struct WavesEffect: Effect {
    public enum Direction: Sendable {
        case columnLeftToRight
        case columnRightToLeft
        case rowTopToBottom
        case rowBottomToTop
        case centerToOutside
        case outsideToCenter
    }

    public struct Configuration: Sendable {
        public var waveSymbols: [String]
        public var waveGradientStops: [Color]
        public var waveGradientSteps: [Int]
        public var waveCount: Int
        public var waveLength: Int
        public var waveDirection: Direction
        public var waveEasing: Easing
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            waveSymbols: [String] = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃", "▂", "▁"],
            waveGradientStops: [Color] = [Color(hex: "f0ff65"), Color(hex: "ffb102"), Color(hex: "31a0d4"), Color(hex: "ffb102"), Color(hex: "f0ff65")],
            waveGradientSteps: [Int] = [6],
            waveCount: Int = 7,
            waveLength: Int = 2,
            waveDirection: Direction = .columnLeftToRight,
            waveEasing: Easing = .inOutSine,
            finalGradientStops: [Color] = [Color(hex: "ffb102"), Color(hex: "31a0d4"), Color(hex: "f0ff65")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .diagonal
        ) {
            precondition(!waveSymbols.isEmpty, "wave symbols must not be empty")
            precondition(!waveGradientStops.isEmpty, "wave gradient stops must not be empty")
            precondition(waveCount > 0, "wave count must be positive")
            precondition(waveLength > 0, "wave length must be positive")
            self.waveSymbols = waveSymbols
            self.waveGradientStops = waveGradientStops
            self.waveGradientSteps = waveGradientSteps
            self.waveCount = waveCount
            self.waveLength = waveLength
            self.waveDirection = waveDirection
            self.waveEasing = waveEasing
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum Phase { case wave, final, done }

    private struct FrameVisual {
        let symbol: UInt32
        let foreground: UInt32
        let duration: Int
    }

    private struct Glyph {
        let characterID: Int
        let coordinate: Coordinate
        let inputSymbol: UInt32
        let waveFrames: [FrameVisual]
        let finalFrames: [FrameVisual]
        var visible = false
        var phase: Phase = .wave
        var frameIndex = 0
        var ticksElapsed = 0
        var renderedVisual: FrameVisual?

        var active: Bool { visible && phase != .done }

        var visual: FrameVisual? {
            switch phase {
            case .wave: return waveFrames[frameIndex]
            case .final: return finalFrames[frameIndex]
            case .done: return finalFrames.last
            }
        }
    }

    private let canvas: Canvas
    private let options: Configuration
    private var glyphs: [Glyph] = []
    private var pendingGroups: [[Int]] = []
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, wavesConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        wavesConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = wavesConfiguration
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard hasPendingWork else {
            isComplete = true
            return .complete
        }

        if !pendingGroups.isEmpty {
            for index in pendingGroups.removeFirst() { glyphs[index].visible = true }
        }

        advanceScenes()
        render(into: &frame)

        if !hasPendingWork {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText) {
        var created: [(characterID: Int, symbol: UInt32, coordinate: Coordinate)] = []
        created.reserveCapacity(input.scalars.count)
        for (index, pair) in zip(input.scalars, input.positions).enumerated() {
            created.append((index, pair.0, Coordinate(column: pair.1.column, row: pair.1.row)))
        }
        guard !created.isEmpty else {
            isComplete = true
            return
        }

        let coordinates = created.map(\.coordinate)
        let bottom = coordinates.map(\.row).min()!
        let top = coordinates.map(\.row).max()!
        let left = coordinates.map(\.column).min()!
        let right = coordinates.map(\.column).max()!
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let finalMapping = try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )
        let finalColors = Dictionary(uniqueKeysWithValues: finalMapping.entries.map { ($0.coordinate, $0.color) })
        let waveGradient = try! Gradient(stops: options.waveGradientStops, steps: options.waveGradientSteps)
        let waveFrames = makeWaveFrames(waveGradient: waveGradient)

        glyphs = created.map { source in
            let finalColor = finalColors[source.coordinate] ?? finalGradient.spectrum[0]
            let finalSceneGradient = try! Gradient(stops: [waveGradient.spectrum.last!, finalColor], steps: options.finalGradientSteps)
            let finalFrames = finalSceneGradient.spectrum.map {
                FrameVisual(symbol: source.symbol, foreground: rgb($0), duration: 10)
            }
            return Glyph(
                characterID: source.characterID,
                coordinate: source.coordinate,
                inputSymbol: source.symbol,
                waveFrames: waveFrames,
                finalFrames: finalFrames
            )
        }
        pendingGroups = groupedGlyphs()
    }

    private func makeWaveFrames(waveGradient: Gradient) -> [FrameVisual] {
        let symbols = options.waveSymbols.map { $0.unicodeScalars.first?.value ?? Cell.blank.codepoint }
        let colors = waveGradient.spectrum.map(rgb)
        let distributed: [(UInt32, UInt32)]
        if symbols.count >= colors.count {
            distributed = cyclicDistribution(larger: symbols, smaller: colors).map { ($0.0, $0.1) }
        } else {
            distributed = cyclicDistribution(larger: colors, smaller: symbols).map { ($0.1, $0.0) }
        }
        return Array(repeating: distributed, count: options.waveCount)
            .flatMap { $0 }
            .map { FrameVisual(symbol: $0.0, foreground: $0.1, duration: options.waveLength) }
    }

    private func groupedGlyphs() -> [[Int]] {
        let ordered = glyphs.indices.sorted {
            let lhs = glyphs[$0].coordinate
            let rhs = glyphs[$1].coordinate
            if lhs.row != rhs.row { return lhs.row > rhs.row }
            return lhs.column < rhs.column
        }
        let key: (Glyph) -> Int
        let reverse: Bool
        switch options.waveDirection {
        case .columnLeftToRight:
            key = { $0.coordinate.column }
            reverse = false
        case .columnRightToLeft:
            key = { $0.coordinate.column }
            reverse = true
        case .rowTopToBottom:
            key = { $0.coordinate.row }
            reverse = true
        case .rowBottomToTop:
            key = { $0.coordinate.row }
            reverse = false
        case .centerToOutside, .outsideToCenter:
            let columns = glyphs.map(\.coordinate.column)
            let rows = glyphs.map(\.coordinate.row)
            let center = Coordinate(
                column: columns.min()! + (columns.max()! - columns.min()!) / 2,
                row: rows.min()! + (rows.max()! - rows.min()!) / 2
            )
            key = { abs($0.coordinate.column - center.column) + abs($0.coordinate.row - center.row) }
            reverse = options.waveDirection == .outsideToCenter
        }
        var buckets: [Int: [Int]] = [:]
        for index in ordered { buckets[key(glyphs[index]), default: []].append(index) }
        var groups = buckets.keys.sorted().compactMap { buckets[$0] }
        if reverse { groups.reverse() }
        return groups
    }

    private mutating func advanceScenes() {
        for index in glyphs.indices where glyphs[index].active {
            guard let displayed = glyphs[index].visual else { continue }
            glyphs[index].renderedVisual = displayed
            glyphs[index].ticksElapsed += 1
            guard glyphs[index].ticksElapsed >= displayed.duration else { continue }
            glyphs[index].ticksElapsed = 0
            switch glyphs[index].phase {
            case .wave:
                if glyphs[index].frameIndex + 1 < glyphs[index].waveFrames.count {
                    glyphs[index].frameIndex += 1
                } else {
                    glyphs[index].phase = .final
                    glyphs[index].frameIndex = 0
                    glyphs[index].renderedVisual = glyphs[index].finalFrames[0]
                }
            case .final:
                if glyphs[index].frameIndex + 1 < glyphs[index].finalFrames.count {
                    glyphs[index].frameIndex += 1
                } else {
                    glyphs[index].phase = .done
                }
            case .done:
                break
            }
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            var winners: [Int: (characterID: Int, visual: FrameVisual)] = [:]
            for glyph in glyphs where glyph.visible {
                guard let visual = glyph.renderedVisual ?? glyph.visual,
                      (1...canvas.columns).contains(glyph.coordinate.column),
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

    private var hasPendingWork: Bool {
        !pendingGroups.isEmpty || glyphs.contains(where: \.active)
    }

    private func cyclicDistribution<T, U>(larger: [T], smaller: [U]) -> [(T, U)] {
        let repeatFactor = larger.count / smaller.count
        var overflowCount = larger.count % smaller.count
        var overflowUsed = false
        var smallerIndex = 0
        var currentRepeatFactor = 0
        var output: [(T, U)] = []
        output.reserveCapacity(larger.count)
        for element in larger {
            if currentRepeatFactor >= repeatFactor {
                if overflowCount > 0 {
                    if overflowUsed {
                        smallerIndex += 1
                        currentRepeatFactor = 0
                        overflowUsed = false
                    } else {
                        overflowUsed = true
                        overflowCount -= 1
                    }
                } else {
                    smallerIndex += 1
                    currentRepeatFactor = 0
                }
            }
            currentRepeatFactor += 1
            output.append((element, smaller[smallerIndex]))
        }
        return output
    }

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
