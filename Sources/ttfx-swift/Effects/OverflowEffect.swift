import Foundation
import TTFXCore

public struct OverflowEffect: Effect {
    public struct Configuration: Sendable {
        public var overflowGradientStops: [Color]
        public var overflowCyclesRange: ClosedRange<Int>
        public var overflowSpeed: Int
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            overflowGradientStops: [Color] = [Color(hex: "f2ebc0"), Color(hex: "8dbfb3"), Color(hex: "f2ebc0")],
            overflowCyclesRange: ClosedRange<Int> = 2...4,
            overflowSpeed: Int = 3,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(!overflowGradientStops.isEmpty, "overflow gradient must not be empty")
            precondition(overflowCyclesRange.lowerBound > 0 && overflowCyclesRange.upperBound >= overflowCyclesRange.lowerBound, "overflow cycles range must be positive")
            precondition(overflowSpeed > 0, "overflow speed must be positive")
            self.overflowGradientStops = overflowGradientStops
            self.overflowCyclesRange = overflowCyclesRange
            self.overflowSpeed = overflowSpeed
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Glyph {
        let characterID: Int
        let inputCoordinate: Coordinate
        let symbol: UInt32
        var coordinate: Coordinate
        var foreground: UInt32
        var visible: Bool
    }

    private struct Row {
        var glyphs: [Int]
        let final: Bool
    }

    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var pendingRows: [Row] = []
    private var activeRows: [Row] = []
    private var delay = 0
    private var overflowSpectrum: [Color] = []
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, overflowConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        overflowConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = overflowConfiguration
        self.rng = Xoshiro256PlusPlus(seed: seed)
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard !pendingRows.isEmpty else {
            isComplete = true
            return .complete
        }

        if delay == 0 {
            for _ in 0..<rng.integer(in: 1...options.overflowSpeed) {
                guard !pendingRows.isEmpty else { break }
                for row in activeRows {
                    moveUp(row)
                    if !row.final { colorOverflow(row) }
                }

                var next = pendingRows.removeFirst()
                setup(&next)
                moveUp(next)
                if !next.final { setColor(next, rgb(overflowSpectrum[0])) }
                for index in next.glyphs { glyphs[index].visible = true }
                activeRows.append(next)
            }
            delay = rng.integer(in: 0...3)
        } else {
            delay -= 1
        }

        activeRows.removeAll { row in
            guard let first = row.glyphs.first else { return true }
            return glyphs[first].coordinate.row > canvas.rows
        }
        render(into: &frame)
        if pendingRows.isEmpty {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText) {
        var sources: [(characterID: Int, symbol: UInt32, coordinate: Coordinate)] = []
        sources.reserveCapacity(input.scalars.count)
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

        let sortedRows = groupedRows(from: sources)
        let cycles = rng.integer(in: options.overflowCyclesRange)
        for _ in 0..<cycles {
            var rows = sortedRows
            rng.shuffle(&rows)
            for row in rows {
                var copied: [Int] = []
                for source in row {
                    let index = glyphs.count
                    glyphs.append(Glyph(
                        characterID: source.characterID,
                        inputCoordinate: source.coordinate,
                        symbol: source.symbol,
                        coordinate: source.coordinate,
                        foreground: 0,
                        visible: false
                    ))
                    copied.append(index)
                }
                pendingRows.append(Row(glyphs: copied, final: false))
            }
        }

        for row in sortedRows {
            var originals: [Int] = []
            for source in row {
                let index = glyphs.count
                glyphs.append(Glyph(
                    characterID: source.characterID,
                    inputCoordinate: source.coordinate,
                    symbol: source.symbol,
                    coordinate: source.coordinate,
                    foreground: finalColors[source.coordinate] ?? 0,
                    visible: false
                ))
                originals.append(index)
            }
            pendingRows.append(Row(glyphs: originals, final: true))
        }

        let steps = max(PyCompat.floorDivide(canvas.rows, max(options.overflowGradientStops.count - 1, 1)), 1)
        overflowSpectrum = (try! Gradient(stops: options.overflowGradientStops, steps: [steps])).spectrum
    }

    private func groupedRows(from sources: [(characterID: Int, symbol: UInt32, coordinate: Coordinate)]) -> [[(characterID: Int, symbol: UInt32, coordinate: Coordinate)]] {
        let sorted = sources.sorted { lhs, rhs in
            if lhs.coordinate.row != rhs.coordinate.row { return lhs.coordinate.row > rhs.coordinate.row }
            if lhs.coordinate.column != rhs.coordinate.column { return lhs.coordinate.column < rhs.coordinate.column }
            return lhs.characterID < rhs.characterID
        }
        return Array(Set(sources.map { $0.coordinate.row })).sorted(by: >).map { row in
            sorted.filter { $0.coordinate.row == row }
        }
    }

    private mutating func setup(_ row: inout Row) {
        for index in row.glyphs {
            glyphs[index].coordinate = Coordinate(column: glyphs[index].inputCoordinate.column, row: 0)
        }
    }

    private mutating func moveUp(_ row: Row) {
        for index in row.glyphs {
            glyphs[index].coordinate = Coordinate(column: glyphs[index].coordinate.column, row: glyphs[index].coordinate.row + 1)
        }
    }

    private mutating func colorOverflow(_ row: Row) {
        guard let first = row.glyphs.first else { return }
        let spectrumIndex = min(max(glyphs[first].coordinate.row, 0), overflowSpectrum.count - 1)
        setColor(row, rgb(overflowSpectrum[spectrumIndex]))
    }

    private mutating func setColor(_ row: Row, _ color: UInt32) {
        for index in row.glyphs { glyphs[index].foreground = color }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            for glyph in glyphs where glyph.visible {
                guard (1...canvas.columns).contains(glyph.coordinate.column),
                      (1...canvas.rows).contains(glyph.coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
                cells[cellIndex] = Cell(codepoint: glyph.symbol, foreground: glyph.foreground, background: 0)
            }
        }
    }
}

private func rgb(_ color: Color) -> UInt32 {
    UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
}
