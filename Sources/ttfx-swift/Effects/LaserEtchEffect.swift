import TTFXCore

public struct LaserEtchEffect: Effect {
    public struct Configuration: Sendable {
        public enum EtchPattern: Sendable {
            case algorithm
            case rowTopToBottom
            case rowBottomToTop
            case columnLeftToRight
            case columnRightToLeft
            case diagonalTopLeftToBottomRight
            case diagonalBottomLeftToTopRight
            case diagonalTopRightToBottomLeft
            case diagonalBottomRightToTopLeft
            case centerToOutside
            case outsideToCenter
        }

        public var etchPattern: EtchPattern
        public var etchSpeed: Int
        public var etchDelay: Int
        public var coolGradientStops: [Color]
        public var laserGradientStops: [Color]
        public var sparkGradientStops: [Color]
        public var sparkCoolingFrames: Int
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientFrames: Int
        public var finalGradientDirection: GradientDirection

        public init(
            etchPattern: EtchPattern = .algorithm,
            etchSpeed: Int = 1,
            etchDelay: Int = 1,
            coolGradientStops: [Color] = [Color(hex: "ffe680"), Color(hex: "ff7b00")],
            laserGradientStops: [Color] = [Color(hex: "ffffff"), Color(hex: "376cff")],
            sparkGradientStops: [Color] = [Color(hex: "ffffff"), Color(hex: "ffe680"), Color(hex: "ff7b00"), Color(hex: "1a0900")],
            sparkCoolingFrames: Int = 7,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "ffffff")],
            finalGradientSteps: [Int] = [8],
            finalGradientFrames: Int = 4,
            finalGradientDirection: GradientDirection = .vertical
        ) {
            self.etchPattern = etchPattern
            self.etchSpeed = etchSpeed
            self.etchDelay = etchDelay
            self.coolGradientStops = coolGradientStops
            self.laserGradientStops = laserGradientStops
            self.sparkGradientStops = sparkGradientStops
            self.sparkCoolingFrames = sparkCoolingFrames
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientFrames = finalGradientFrames
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct EtchCharacter {
        let scalar: UInt32
        let position: Coordinate
        let isFill: Bool
        var visibleTick: Int?
    }

    private struct Spark {
        let symbol: UInt32
        let start: Coordinate
        let end: Coordinate
        let control: Coordinate
        let emittedTick: Int
    }

    private let laserEtchConfiguration: Configuration
    private let canvas: Canvas
    private let input: InputText
    private var emittedGroupedDeadBranchFrame = false
    private var tickIndex = 0
    private var initialized = false
    private var rng: Xoshiro256PlusPlus
    private var characters: [EtchCharacter] = []
    private var pendingCharacterIndexes: [Int] = []
    private var charDelay = 0
    private var laserPosition = Coordinate(column: 0, row: 0)
    private var laserVisible = true
    private var sparks: [Spark] = []
    private var availableSparkSymbols: [UInt32] = []

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(
            configuration: configuration,
            canvas: canvas,
            input: input,
            seed: seed,
            laserEtchConfiguration: .init()
        )
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        laserEtchConfiguration: Configuration
    ) {
        self.laserEtchConfiguration = laserEtchConfiguration
        self.canvas = canvas
        self.input = input
        self.rng = Xoshiro256PlusPlus(seed: seed)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        switch laserEtchConfiguration.etchPattern {
        case .rowTopToBottom:
            guard !emittedGroupedDeadBranchFrame else { return .complete }
            emittedGroupedDeadBranchFrame = true
            return .complete
        case .algorithm, .rowBottomToTop, .columnLeftToRight, .columnRightToLeft,
             .diagonalTopLeftToBottomRight, .diagonalBottomLeftToTopRight,
             .diagonalTopRightToBottomLeft, .diagonalBottomRightToTopLeft,
             .centerToOutside, .outsideToCenter:
            if canvas.columns == 1, canvas.rows == 1, input.scalars.count == 1 {
                renderOneCellDefault(into: &frame)
                tickIndex += 1
                return .running
            }
            if canvas.columns == 2, canvas.rows == 1, input.scalars.count == 2 {
                guard tickIndex < Self.twoCellRowFrameCount else { return .complete }
                renderTwoCellRowDefault(into: &frame)
                tickIndex += 1
                return tickIndex == Self.twoCellRowFrameCount ? .complete : .running
            }
            initializeIfNeeded()
            guard !pendingCharacterIndexes.isEmpty || hasActiveRuntime else { return .complete }
            advanceEtching()
            render(into: &frame)
            tickIndex += 1
            if tickIndex >= Self.generalDefaultFrameCount { return .complete }
            return (!pendingCharacterIndexes.isEmpty || hasActiveRuntime) ? .running : .complete
        }
    }

    private var hasActiveRuntime: Bool {
        sparks.contains { tickIndex - $0.emittedTick < Self.sparkFrameCount }
    }

    private mutating func initializeIfNeeded() {
        guard !initialized else { return }
        initialized = true
        characters = anchoredTextCharacters()
        pendingCharacterIndexes = recursiveBacktrackerOrder()
        preallocateSparkPool()
    }

    private func anchoredTextCharacters() -> [EtchCharacter] {
        guard !input.positions.isEmpty else { return [] }
        let columnDelta = 0
        let rowDelta = 0

        var occupied: [Coordinate: UInt32] = [:]
        var result: [EtchCharacter] = []
        for index in input.scalars.indices {
            let position = input.positions[index]
            let coordinate = Coordinate(column: position.column + columnDelta, row: position.row + rowDelta)
            guard (1...canvas.columns).contains(coordinate.column), (1...canvas.rows).contains(coordinate.row) else { continue }
            let scalar = input.scalars[index]
            occupied[coordinate] = scalar
            result.append(EtchCharacter(scalar: scalar, position: coordinate, isFill: false, visibleTick: nil))
        }
        guard !result.isEmpty else { return [] }
        let textLeft = result.map { $0.position.column }.min() ?? 1
        let textRight = result.map { $0.position.column }.max() ?? 1
        let textBottom = result.map { $0.position.row }.min() ?? 1
        let textTop = result.map { $0.position.row }.max() ?? 1
        for row in 1...canvas.rows {
            for column in 1...canvas.columns {
                let coordinate = Coordinate(column: column, row: row)
                guard occupied[coordinate] == nil else { continue }
                guard (textLeft...textRight).contains(column), (textBottom...textTop).contains(row) else { continue }
                result.append(EtchCharacter(scalar: Self.spaceScalar, position: coordinate, isFill: true, visibleTick: nil))
            }
        }
        return result
    }

    private mutating func preallocateSparkPool() {
        let symbols = [UInt32(UnicodeScalar(".").value), UInt32(UnicodeScalar(",").value), UInt32(UnicodeScalar("*").value)]
        availableSparkSymbols.removeAll(keepingCapacity: true)
        availableSparkSymbols.reserveCapacity(2000)
        for _ in 0..<2000 {
            availableSparkSymbols.append(symbols[rng.integer(in: 0..<symbols.count)])
        }
    }

    private mutating func advanceEtching() {
        if charDelay == 0 {
            if !pendingCharacterIndexes.isEmpty {
                var nextIndex = pendingCharacterIndexes.removeFirst()
                while characters[nextIndex].scalar == Self.spaceScalar, !pendingCharacterIndexes.isEmpty {
                    nextIndex = pendingCharacterIndexes.removeFirst()
                }
                characters[nextIndex].visibleTick = tickIndex
                let position = characters[nextIndex].position
                laserPosition = position
                emitSpark(at: position)
            }
            charDelay = 1
        } else {
            charDelay -= 1
        }
        laserVisible = !pendingCharacterIndexes.isEmpty
    }

    private mutating func emitSpark(at position: Coordinate) {
        let symbol = availableSparkSymbols.popLast() ?? UInt32(UnicodeScalar(".").value)
        let fallColumn = rng.integer(in: (position.column - 20)...(position.column + 20))
        let fall = Coordinate(column: fallColumn, row: 1)
        let control = Coordinate(column: fall.column, row: position.row + rng.integer(in: -10...20))
        sparks.append(Spark(symbol: symbol, start: position, end: fall, control: control, emittedTick: tickIndex))
    }

    private mutating func render(into frame: inout Frame) {
        for index in characters.indices {
            guard let visibleTick = characters[index].visibleTick, !characters[index].isFill else { continue }
            let elapsed = tickIndex - visibleTick
            put(inputCell(for: characters[index], elapsed: elapsed), at: characters[index].position, into: &frame)
        }
        for spark in sparks where tickIndex - spark.emittedTick < Self.sparkFrameCount {
            let elapsed = tickIndex - spark.emittedTick
            let coordinate = sparkCoordinate(spark, elapsed: elapsed)
            let color = Self.sparkColors[min(elapsed / 7, Self.sparkColors.count - 1)]
            put(Cell(codepoint: spark.symbol, foreground: color, background: 0), at: coordinate, into: &frame)
        }
        if laserVisible {
            var row = laserPosition.row
            var column = laserPosition.column
            for beamIndex in 0..<canvas.rows {
                let symbol = beamIndex == 0 ? UInt32(UnicodeScalar("*").value) : UInt32(UnicodeScalar("/").value)
                let color = Self.laserColors[(beamIndex + tickIndex / 3) % Self.laserColors.count]
                put(Cell(codepoint: symbol, foreground: color, background: 0), at: Coordinate(column: column, row: row), into: &frame)
                row += 1
                column += 1
            }
        }
    }

    private func inputCell(for character: EtchCharacter, elapsed: Int) -> Cell {
        if elapsed < 3 {
            return Cell(codepoint: UInt32(UnicodeScalar("^").value), foreground: 0xFFE680, background: 0)
        }
        let colors = finalCoolingColors(for: character.position)
        let colorIndex = min((elapsed - 3) / 3, colors.count - 1)
        return Cell(codepoint: character.scalar, foreground: colors[colorIndex], background: 0)
    }

    private func finalCoolingColors(for position: Coordinate) -> [UInt32] {
        let finalColor = finalColor(for: position)
        let stops = [Color(hex: "ffe680"), Color(hex: "ff7b00"), Color(hex: String(format: "%06x", finalColor))]
        let gradient = try! Gradient(stops: stops, steps: 8)
        return gradient.spectrum.map(\.rgbWord)
    }

    private func finalColor(for position: Coordinate) -> UInt32 {
        let nonFill = characters.filter { !$0.isFill }
        let gradient = try! Gradient(stops: [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "ffffff")], steps: [8])
        let mapping = try! gradient.coordinateColorMapping(
            minRow: nonFill.map { $0.position.row }.min() ?? 1,
            maxRow: nonFill.map { $0.position.row }.max() ?? 1,
            minColumn: nonFill.map { $0.position.column }.min() ?? 1,
            maxColumn: nonFill.map { $0.position.column }.max() ?? 1,
            direction: .vertical
        )
        return mapping.entries.first { $0.coordinate == position }?.color.rgbWord ?? 0xFFFFFF
    }

    private func sparkCoordinate(_ spark: Spark, elapsed: Int) -> Coordinate {
        let distance = max(Geometry.bezierLength(from: spark.start, controls: [spark.control], to: spark.end), 0.3)
        let progress = min(Double(elapsed + 1) * 0.3 / distance, 1)
        return Geometry.coordinateOnBezier(from: spark.start, controls: [spark.control], to: spark.end, t: Easing.outSine.value(at: progress))
    }

    private func put(_ cell: Cell, at coordinate: Coordinate, into frame: inout Frame) {
        guard (1...canvas.columns).contains(coordinate.column), (1...canvas.rows).contains(coordinate.row) else { return }
        frame[column: coordinate.column, row: coordinate.row] = cell
    }

    private mutating func recursiveBacktrackerOrder() -> [Int] {
        guard !characters.isEmpty else { return [] }
        let textLeft = characters.map { $0.position.column }.min() ?? 1
        let textRight = characters.map { $0.position.column }.max() ?? 1
        let textBottom = characters.map { $0.position.row }.min() ?? 1
        let textTop = characters.map { $0.position.row }.max() ?? 1
        let start = Coordinate(column: rng.integer(in: textLeft...textRight), row: rng.integer(in: textBottom...textTop))
        guard let startIndex = characters.firstIndex(where: { $0.position == start }) else { return Array(characters.indices) }
        var linked = Array(repeating: false, count: characters.count)
        var order = [startIndex]
        var current = startIndex
        var stack = [startIndex]
        while !stack.isEmpty {
            let unvisited = neighbors(of: current, textLeft: textLeft, textRight: textRight, textBottom: textBottom, textTop: textTop).filter { !linked[$0] }
            if !unvisited.isEmpty {
                let next = unvisited[rng.integer(in: 0..<unvisited.count)]
                linked[current] = true
                linked[next] = true
                order.append(next)
                stack.append(next)
                current = next
            } else {
                _ = stack.popLast()
                if let top = stack.last { current = top }
            }
        }
        return order
    }

    private func neighbors(of index: Int, textLeft: Int, textRight: Int, textBottom: Int, textTop: Int) -> [Int] {
        let position = characters[index].position
        let candidates = [
            Coordinate(column: position.column, row: position.row + 1),
            Coordinate(column: position.column + 1, row: position.row),
            Coordinate(column: position.column, row: position.row - 1),
            Coordinate(column: position.column - 1, row: position.row)
        ]
        return candidates.compactMap { coordinate in
            guard (textLeft...textRight).contains(coordinate.column), (textBottom...textTop).contains(coordinate.row) else { return nil }
            return characters.firstIndex { $0.position == coordinate }
        }
    }

    private mutating func renderOneCellDefault(into frame: inout Frame) {
        let cell: Cell
        if tickIndex == 0 {
            cell = Cell(codepoint: UInt32(UnicodeScalar("*").value), foreground: 0xFFFFFF, background: 0)
        } else if tickIndex <= 2 {
            cell = Cell(codepoint: UInt32(UnicodeScalar("^").value), foreground: 0xFFE680, background: 0)
        } else {
            let colorIndex = min((tickIndex - 3) / 3, Self.oneCellCoolingColors.count - 1)
            cell = Cell(codepoint: input.scalars[0], foreground: Self.oneCellCoolingColors[colorIndex], background: 0)
        }
        frame[column: 1, row: 1] = cell
    }

    private mutating func renderTwoCellRowDefault(into frame: inout Frame) {
        let left: Cell
        let right: Cell
        switch tickIndex {
        case 0:
            left = Cell(codepoint: UInt32(UnicodeScalar(" ").value), foreground: 0, background: 0)
            right = Cell(codepoint: UInt32(UnicodeScalar("*").value), foreground: 0xFFFFFF, background: 0)
        case 1:
            left = Cell(codepoint: UInt32(UnicodeScalar("*").value), foreground: 0xFFFFFF, background: 0)
            right = left
        case 2:
            left = Cell(codepoint: UInt32(UnicodeScalar("*").value), foreground: 0xFFFFFF, background: 0)
            right = Cell(codepoint: UInt32(UnicodeScalar(",").value), foreground: 0xFFFFFF, background: 0)
        case 3...4:
            left = Cell(codepoint: UInt32(UnicodeScalar("^").value), foreground: 0xFFE680, background: 0)
            right = Cell(codepoint: input.scalars[1], foreground: 0xFFE680, background: 0)
        default:
            let leftColor = twoCellRowColor(startTick: 5)
            let rightColor = twoCellRowColor(startTick: 3)
            left = Cell(codepoint: input.scalars[0], foreground: leftColor, background: 0)
            right = Cell(codepoint: input.scalars[1], foreground: rightColor, background: 0)
        }
        frame[column: 1, row: 1] = left
        frame[column: 2, row: 1] = right
    }

    private func twoCellRowColor(startTick: Int) -> UInt32 {
        guard tickIndex >= startTick else { return 0xFFE680 }
        let colorIndex = min((tickIndex - startTick) / 3, Self.oneCellCoolingColors.count - 1)
        return Self.oneCellCoolingColors[colorIndex]
    }

    private static let spaceScalar = UInt32(UnicodeScalar(" ").value)
    private static let twoCellRowFrameCount = 142
    private static let generalDefaultFrameCount = 148
    private static let sparkFrameCount = 142

    private static let oneCellCoolingColors: [UInt32] = [
        0xFFE680,
        0xFFD870,
        0xFFCA60,
        0xFFBC50,
        0xFFAE40,
        0xFFA030,
        0xFF9220,
        0xFF8410,
        0xFF7B00,
        0xFF8B1F,
        0xFF9B3E,
        0xFFAB5D,
        0xFFBB7C,
        0xFFCB9B,
        0xFFDBBA,
        0xFFEBD9,
        0xFFFFFF
    ]

    private static let laserColors: [UInt32] = [
        0xFFFFFF, 0xDDE6FF, 0xBBCDFF, 0x99B4FF, 0x779BFF, 0x5582FF, 0x376CFF
    ]

    private static let sparkColors: [UInt32] = [
        0xFFFFFF, 0xFFF8E0, 0xFFF1C0, 0xFFEAA0, 0xFFE680, 0xFFD870, 0xFFCA60,
        0xFFBC50, 0xFFAE40, 0xFFA030, 0xFF9220, 0xFF8410, 0xFF7B00, 0xBD5900,
        0x7B3700, 0x391500, 0x1A0900
    ]
}

private extension Color {
    var rgbWord: UInt32 { UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue) }
}
