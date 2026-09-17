import TTFXCore

public struct SmokeEffect: Effect {
    public struct Configuration: Sendable {
        public var startingColor: Color
        public var smokeSymbols: [String]
        public var smokeGradientStops: [Color]
        public var useWholeCanvas: Bool
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            startingColor: Color = Color(hex: "7A7A7A"),
            smokeSymbols: [String] = ["░", "▒", "▓", "▒", "░"],
            smokeGradientStops: [Color] = [Color(hex: "242424"), Color(hex: "FFFFFF")],
            useWholeCanvas: Bool = false,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(!smokeSymbols.isEmpty, "smoke symbols must not be empty")
            precondition(!smokeGradientStops.isEmpty, "smoke gradient stops must not be empty")
            precondition(!finalGradientStops.isEmpty, "final gradient stops must not be empty")
            self.startingColor = startingColor
            self.smokeSymbols = smokeSymbols
            self.smokeGradientStops = smokeGradientStops
            self.useWholeCanvas = useWholeCanvas
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum Phase { case idle, smoke, paint, done }

    private struct Visual {
        let symbol: UInt32
        let foreground: UInt32
        let duration: Int
    }

    private struct Glyph {
        let characterID: Int
        let coordinate: Coordinate
        let inputSymbol: UInt32
        let smokeFrames: [Visual]
        let paintFrames: [Visual]
        var visible = true
        var phase: Phase = .idle
        var frameIndex = 0
        var ticksElapsed = 0
        var renderedVisual: Visual?

        var active: Bool { visible && phase != .done && phase != .idle }

        var visual: Visual? {
            switch phase {
            case .idle: renderedVisual
            case .smoke: smokeFrames[frameIndex]
            case .paint: paintFrames[frameIndex]
            case .done: paintFrames.last
            }
        }
    }

    private let canvas: Canvas
    private let options: Configuration
    private var glyphs: [Glyph] = []
    private var releaseOrder: [[Int]] = []
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, smokeConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        smokeConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = smokeConfiguration
        build(input: input, seed: seed)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard hasPendingWork else {
            isComplete = true
            return .complete
        }

        if !releaseOrder.isEmpty {
            for next in releaseOrder.removeFirst() { glyphs[next].phase = .smoke }
        }
        advanceScenes()
        render(into: &frame)

        if !hasPendingWork {
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
        let finalColors = Dictionary(uniqueKeysWithValues: finalMapping.entries.map { ($0.coordinate, $0.color) })

        let smokeStops = options.smokeGradientStops + options.finalGradientStops.reversed()
        let smokeGradient = try! Gradient(stops: smokeStops, steps: [3, 4])
        let smokeSymbols = options.smokeSymbols.map { $0.unicodeScalars.first?.value ?? Cell.blank.codepoint }

        let occupied = Dictionary(uniqueKeysWithValues: sources.map { ($0.coordinate, $0) })
        sources = []
        for row in stride(from: canvas.rows, through: 1, by: -1) {
            for column in 1...canvas.columns {
                let coordinate = Coordinate(column: column, row: row)
                sources.append(occupied[coordinate] ?? (sources.count + input.scalars.count, 32, coordinate))
            }
        }
        glyphs = sources.map { source in
            let finalColor = finalColors[source.coordinate] ?? Color(hex: "000000")
            let paintGradient = try! Gradient(stops: options.finalGradientStops + [finalColor], steps: 5)
            return Glyph(
                characterID: source.characterID,
                coordinate: source.coordinate,
                inputSymbol: source.symbol,
                smokeFrames: distributedSmokeFrames(symbols: smokeSymbols, colors: smokeGradient.spectrum),
                paintFrames: paintGradient.spectrum.map { Visual(symbol: source.symbol, foreground: rgb($0), duration: 5) },
                renderedVisual: Visual(symbol: source.symbol, foreground: rgb(options.startingColor), duration: 1)
            )
        }
        releaseOrder = breadthFirstGroups(seed: seed, bounds: (left, right, bottom, top))
    }

    private func distributedSmokeFrames(symbols: [UInt32], colors: [Color]) -> [Visual] {
        let pairs: [(UInt32, Color)]
        if symbols.count >= colors.count {
            pairs = cyclicDistribution(larger: symbols, smaller: colors).map { ($0.0, $0.1) }
        } else {
            pairs = cyclicDistribution(larger: colors, smaller: symbols).map { ($0.1, $0.0) }
        }
        return pairs.map { Visual(symbol: $0.0, foreground: rgb($0.1), duration: 3) }
    }

    private func breadthFirstGroups(seed: UInt64, bounds: (Int, Int, Int, Int)) -> [[Int]] {
        var rng = Xoshiro256PlusPlus(seed: seed)
        let left = options.useWholeCanvas ? 1 : bounds.0
        let right = options.useWholeCanvas ? canvas.columns : bounds.1
        let bottom = options.useWholeCanvas ? 1 : bounds.2
        let top = options.useWholeCanvas ? canvas.rows : bounds.3
        let ids = Dictionary(uniqueKeysWithValues: glyphs.indices.map { (glyphs[$0].coordinate, $0) })
        let start = ids[Coordinate(column: rng.integer(in: left...right), row: rng.integer(in: bottom...top))]!
        let weights = glyphs.map { _ in rng.integer(in: 0...99) }
        let fillStart = ids[Coordinate(column: rng.integer(in: left...right), row: rng.integer(in: bottom...top))]!
        var links = Array(repeating: Set<Int>(), count: glyphs.count)
        var pending: [Int: [(Int, Int)]] = [:]
        func addNeighbors(_ index: Int) {
            let coordinate = glyphs[index].coordinate
            for (dx, dy) in [(0, 1), (1, 0), (0, -1), (-1, 0)] {
                let neighbor = Coordinate(column: coordinate.column + dx, row: coordinate.row + dy)
                guard (left...right).contains(neighbor.column), (bottom...top).contains(neighbor.row),
                      let id = ids[neighbor], links[id].isEmpty else { continue }
                pending[weights[id], default: []].append((index, id))
            }
        }
        addNeighbors(start)
        while let weight = pending.keys.min() {
            let index = rng.integer(in: pending[weight]!.indices)
            let (source, target) = pending[weight]!.remove(at: index)
            if pending[weight]!.isEmpty { pending.removeValue(forKey: weight) }
            guard links[target].isEmpty else { continue }
            links[source].insert(target)
            links[target].insert(source)
            addNeighbors(target)
        }
        var frontier = [fillStart]
        var explored: Set<Int> = [fillStart]
        var groups: [[Int]] = []
        while !frontier.isEmpty {
            var next: [Int] = []
            for current in frontier {
                for neighbor in links[current].sorted() where !explored.contains(neighbor) {
                    explored.insert(neighbor)
                    next.append(neighbor)
                }
            }
            groups.append(groups.isEmpty ? [fillStart] + next : next)
            frontier = next
        }
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
            case .idle: break
            case .smoke:
                if glyphs[index].frameIndex + 1 < glyphs[index].smokeFrames.count {
                    glyphs[index].frameIndex += 1
                } else {
                    glyphs[index].phase = .paint
                    glyphs[index].frameIndex = 0
                    glyphs[index].renderedVisual = glyphs[index].paintFrames[0]
                }
            case .paint:
                if glyphs[index].frameIndex + 1 < glyphs[index].paintFrames.count {
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
            var winners: [Int: (characterID: Int, visual: Visual)] = [:]
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
                cells[index] = .init(codepoint: winner.visual.symbol, foreground: winner.visual.foreground, background: winner.visual.foreground == 0 ? 0xFFFF_FFFE : 0)
            }
        }
    }

    private var hasPendingWork: Bool {
        !releaseOrder.isEmpty || glyphs.contains(where: \.active)
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
