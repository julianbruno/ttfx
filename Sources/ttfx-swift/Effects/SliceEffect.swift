import TTFXCore

public struct SliceEffect: Effect {
    public enum Direction: Sendable {
        case vertical
        case horizontal
        case diagonal
    }

    public struct Configuration: Sendable {
        public var direction: Direction
        public var movementSpeed: Double
        public var movementEasing: Easing
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            direction: Direction = .vertical,
            movementSpeed: Double = 0.25,
            movementEasing: Easing = .inOutExpo,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .diagonal
        ) {
            precondition(movementSpeed > 0, "movement speed must be positive")
            self.direction = direction
            self.movementSpeed = movementSpeed
            self.movementEasing = movementEasing
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Glyph {
        let characterID: Int
        let target: Coordinate
        let symbol: UInt32
        let foreground: UInt32
        let start: Coordinate
        let totalDistance: Double
        let maxSteps: Int
        var coordinate: Coordinate
        var currentStep = 0
        var pathActive = true
    }

    private let canvas: Canvas
    private let options: Configuration
    private var glyphs: [Glyph] = []
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, sliceConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        sliceConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = sliceConfiguration
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard !glyphs.isEmpty else {
            isComplete = true
            return .complete
        }

        advancePaths()
        render(into: &frame)
        if !glyphs.contains(where: \.pathActive) {
            isComplete = true
            return .complete
        }
        return .running
    }

    private typealias Source = (characterID: Int, symbol: UInt32, coordinate: Coordinate)

    private mutating func build(input: InputText) {
        let sources: [Source] = zip(input.scalars, input.positions).enumerated().map { index, pair in
            (characterID: index, symbol: pair.0, coordinate: Coordinate(column: pair.1.column, row: pair.1.row))
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
        let mapping = try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )
        let colorByCoordinate = Dictionary(uniqueKeysWithValues: mapping.entries.map { ($0.coordinate, rgb($0.color)) })
        let sourceByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.characterID, $0) })

        let origins = pathOrigins(for: sources, bounds: (bottom: bottom, top: top, left: left, right: right))
        glyphs = origins.compactMap { characterID, origin in
            guard let source = sourceByID[characterID] else { return nil }
            let distance = Geometry.lineLength(from: origin, to: source.coordinate)
            return Glyph(
                characterID: characterID,
                target: source.coordinate,
                symbol: source.symbol,
                foreground: colorByCoordinate[source.coordinate]!,
                start: origin,
                totalDistance: distance,
                maxSteps: PyCompat.roundHalfEven(distance / movementSpeed(for: options.direction)),
                coordinate: origin
            )
        }
    }

    private func pathOrigins(
        for sources: [(characterID: Int, symbol: UInt32, coordinate: Coordinate)],
        bounds: (bottom: Int, top: Int, left: Int, right: Int)
    ) -> [(Int, Coordinate)] {
        let centerColumn = bounds.left + (bounds.right - bounds.left) / 2
        let centerRow = bounds.bottom + (bounds.top - bounds.bottom) / 2

        switch options.direction {
        case .vertical:
            let rows = grouped(sources, key: { $0.coordinate.row }, sortedKeys: { $0 < $1 })
            var result: [(Int, Coordinate)] = []
            for rowIndex in rows.indices {
                let row = rows[rowIndex]
                let leftHalf = row.filter { $0.coordinate.column <= centerColumn }
                result += leftHalf.map { ($0.characterID, Coordinate(column: $0.coordinate.column, row: canvas.rows + 1)) }

                let opposite = rows[rows.count - (rowIndex + 1)]
                let rightHalf = opposite.filter { $0.coordinate.column > centerColumn }
                result += rightHalf.map { ($0.characterID, Coordinate(column: $0.coordinate.column, row: 0)) }
            }
            return result

        case .horizontal:
            let columns = grouped(sources, key: { $0.coordinate.column }, sortedKeys: { $0 > $1 })
            var result: [(Int, Coordinate)] = []
            for columnIndex in columns.indices {
                let column = columns[columnIndex]
                let bottomHalf = column.filter { $0.coordinate.row <= centerRow }
                result += bottomHalf.map { ($0.characterID, Coordinate(column: 0, row: $0.coordinate.row)) }

                let opposite = columns[columns.count - (columnIndex + 1)]
                let topHalf = opposite.filter { $0.coordinate.row > centerRow }
                result += topHalf.map { ($0.characterID, Coordinate(column: canvas.columns + 1, row: $0.coordinate.row)) }
            }
            return result

        case .diagonal:
            let diagonals = grouped(sources, key: { $0.coordinate.column + $0.coordinate.row }, sortedKeys: { $0 < $1 })
            var leftGroups = Array(diagonals[..<(diagonals.count / 2)])
            var rightGroups = Array(diagonals[(diagonals.count / 2)...])
            var result: [(Int, Coordinate)] = []
            while !leftGroups.isEmpty || !rightGroups.isEmpty {
                if !leftGroups.isEmpty {
                    let group = leftGroups.removeFirst()
                    let origin = Coordinate(column: group[0].coordinate.column, row: 0)
                    result += group.map { ($0.characterID, origin) }
                }
                if !rightGroups.isEmpty {
                    let group = rightGroups.removeFirst()
                    let origin = Coordinate(column: group[group.count - 1].coordinate.column, row: canvas.rows + 1)
                    result += group.map { ($0.characterID, origin) }
                }
            }
            return result
        }
    }

    private func grouped<T>(
        _ values: [T],
        key: (T) -> Int,
        sortedKeys: (Int, Int) -> Bool
    ) -> [[T]] {
        var buckets: [Int: [T]] = [:]
        for value in values { buckets[key(value), default: []].append(value) }
        return buckets.keys.sorted(by: sortedKeys).map { bucketKey in buckets[bucketKey]! }
    }

    private func movementSpeed(for direction: Direction) -> Double {
        direction == .horizontal ? options.movementSpeed * 2 : options.movementSpeed
    }

    private mutating func advancePaths() {
        for index in glyphs.indices where glyphs[index].pathActive {
            guard glyphs[index].maxSteps > 0, glyphs[index].totalDistance != 0 else {
                glyphs[index].coordinate = glyphs[index].target
                glyphs[index].pathActive = false
                continue
            }
            glyphs[index].currentStep += 1
            let ratio = Double(glyphs[index].currentStep) / Double(glyphs[index].maxSteps)
            let eased = options.movementEasing.value(at: ratio)
            glyphs[index].coordinate = Geometry.coordinateOnLine(
                from: glyphs[index].start,
                to: glyphs[index].target,
                t: eased
            )
            if glyphs[index].currentStep == glyphs[index].maxSteps {
                glyphs[index].pathActive = false
            }
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            var winners: [Int: Glyph] = [:]
            for glyph in glyphs.sorted(by: { $0.characterID < $1.characterID }) {
                guard (1...canvas.columns).contains(glyph.coordinate.column),
                      (1...canvas.rows).contains(glyph.coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
                winners[cellIndex] = glyph
            }
            for (index, glyph) in winners {
                cells[index] = Cell(codepoint: glyph.symbol, foreground: glyph.foreground, background: 0)
            }
        }
    }

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
