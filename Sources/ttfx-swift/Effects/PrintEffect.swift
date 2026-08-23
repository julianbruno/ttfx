import TTFXCore

public struct PrintEffect: Effect {
    private static let printSpeed = 2
    private static let printHeadReturnSpeed = 1.5
    private static let printHeadColor: UInt32 = 0xFFFFFF

    private struct Glyph {
        let originalCoordinate: Coordinate
        var coordinate: Coordinate
        let frames: [(symbol: UInt32, foreground: UInt32)]
        var visible = false
        var sceneTick = 0
        var sceneActive = false

        var visual: (symbol: UInt32, foreground: UInt32) {
            frames[min(sceneTick / 3, frames.count - 1)]
        }
    }

    private struct CarriageReturn {
        let startColumn: Int
        let targetColumn: Int
        let steps: Int
        var currentStep = 0
    }

    private let canvas: Canvas
    private var rows: [[Int]] = []
    private var glyphs: [Glyph] = []
    private var currentRow = 0
    private var currentGlyph = 0
    private var processedRows: [Int] = []
    private var headColumn = 1
    private var headVisible = true
    private var headForeground = Self.printHeadColor
    private var carriageReturn: CarriageReturn?
    private var didBuild = false
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.canvas = canvas
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }

        schedulePrintWork()
        advanceCarriageReturn()
        render(into: &frame)
        advanceGlyphScenes()

        if !hasPendingWork {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText) {
        guard !didBuild else { return }
        didBuild = true

        let positions = Dictionary(uniqueKeysWithValues: zip(input.positions, input.scalars).map {
            (Coordinate(column: $0.0.column, row: $0.0.row), $0.1)
        })
        let textCoordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let textLeft = textCoordinates.map(\.column).min() ?? 1
        let textRight = textCoordinates.map(\.column).max() ?? 1
        let textBottom = textCoordinates.map(\.row).min() ?? 1
        let textTop = textCoordinates.map(\.row).max() ?? 1
        let finalColors = finalColorMap(
            bottom: textBottom,
            top: textTop,
            left: textLeft,
            right: textRight
        )

        // QUIRK(src/effects/print_effect.rs:112-125; plan.md): all-fill rows retain one cell,
        // while other rows stop at the last non-fill column before printing.
        for row in stride(from: canvas.rows, through: 1, by: -1) {
            let lastColumn = (1...canvas.columns)
                .filter { positions[.init(column: $0, row: row)] != nil }
                .max() ?? 1
            var identifiers: [Int] = []
            for column in 1...lastColumn {
                let coordinate = Coordinate(column: column, row: row)
                let symbol = positions[coordinate] ?? Cell.blank.codepoint
                let finalForeground = finalColors[coordinate] ?? Self.printHeadColor
                let frames = fadeFrames(symbol: symbol, finalForeground: finalForeground)
                identifiers.append(glyphs.count)
                glyphs.append(.init(
                    originalCoordinate: coordinate,
                    coordinate: .init(column: column, row: 1),
                    frames: frames
                ))
            }
            rows.append(identifiers)
        }
    }

    private func finalColorMap(bottom: Int, top: Int, left: Int, right: Int) -> [Coordinate: UInt32] {
        let gradient = try! Gradient(
            stops: [.init(hex: "02b8bd"), .init(hex: "c1f0e3"), .init(hex: "00ffa0")],
            steps: [12]
        )
        let mapping = try! gradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: .diagonal
        )
        return Dictionary(uniqueKeysWithValues: mapping.entries.map { entry in
            (entry.coordinate, rgb(entry.color))
        })
    }

    private func fadeFrames(symbol: UInt32, finalForeground: UInt32) -> [(symbol: UInt32, foreground: UInt32)] {
        let white = Color(hex: "ffffff")
        let final = Color(hex: String(format: "%06x", finalForeground))
        let colors = (try! Gradient(stops: [white, final], steps: 5)).spectrum
        let symbols = ["█", "▓", "▒", "░"].map { $0.unicodeScalars.first!.value } + [symbol]
        return cyclicPairing(larger: colors, smaller: symbols).map { color, glyph in
            (glyph, rgb(color))
        }
    }

    private func cyclicPairing<T, U>(larger: [T], smaller: [U]) -> [(T, U)] {
        let repeatFactor = larger.count / smaller.count
        var overflowCount = larger.count % smaller.count
        var overflowUsed = false
        var smallerIndex = 0
        var currentRepeatFactor = 0
        return larger.map { value in
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
            return (value, smaller[smallerIndex])
        }
    }

    private mutating func schedulePrintWork() {
        guard carriageReturn == nil else { return }
        guard currentRow < rows.count else { return }

        if currentGlyph < rows[currentRow].count {
            let end = min(currentGlyph + Self.printSpeed, rows[currentRow].count)
            for index in currentGlyph..<end {
                let glyph = rows[currentRow][index]
                glyphs[glyph].visible = true
                glyphs[glyph].sceneActive = true
                headColumn = glyphs[glyph].originalCoordinate.column
            }
            currentGlyph = end
            return
        }

        processedRows.append(currentRow)
        if currentRow + 1 == rows.count {
            currentRow += 1
            return
        }

        for row in processedRows {
            for glyph in rows[row] {
                var moved = glyphs[glyph]
                moved.coordinate = .init(column: moved.coordinate.column, row: moved.coordinate.row + 1)
                glyphs[glyph] = moved
            }
        }

        currentRow += 1
        currentGlyph = 0
        headVisible = true
        headForeground = 0
        let targetColumn = glyphs[rows[currentRow][0]].originalCoordinate.column
        let distance = abs(headColumn - targetColumn)
        carriageReturn = .init(
            startColumn: headColumn,
            targetColumn: targetColumn,
            steps: PyCompat.roundHalfEven(Double(distance) / Self.printHeadReturnSpeed)
        )
    }

    private mutating func advanceCarriageReturn() {
        guard var carriageReturn else { return }
        guard carriageReturn.steps > 0 else {
            headColumn = carriageReturn.targetColumn
            headVisible = false
            self.carriageReturn = nil
            return
        }

        carriageReturn.currentStep += 1
        let fraction = Double(carriageReturn.currentStep) / Double(carriageReturn.steps)
        let easing = Easing.inOutQuad.value(at: fraction)
        headColumn = PyCompat.roundHalfEven(
            Double(carriageReturn.startColumn) + Double(carriageReturn.targetColumn - carriageReturn.startColumn) * easing
        )
        if carriageReturn.currentStep == carriageReturn.steps {
            headVisible = false
            self.carriageReturn = nil
        } else {
            self.carriageReturn = carriageReturn
        }
    }

    private mutating func advanceGlyphScenes() {
        for index in glyphs.indices where glyphs[index].sceneActive {
            glyphs[index].sceneTick += 1
            if glyphs[index].sceneTick == glyphs[index].frames.count * 3 {
                glyphs[index].sceneActive = false
                glyphs[index].sceneTick -= 1
            }
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            for glyph in glyphs where glyph.visible {
                write(glyph.visual, at: glyph.coordinate, into: &cells)
            }
            if headVisible {
                write(("█".unicodeScalars.first!.value, headForeground), at: .init(column: headColumn, row: 1), into: &cells)
            }
        }
    }

    private func write(
        _ visual: (symbol: UInt32, foreground: UInt32),
        at coordinate: Coordinate,
        into cells: inout ContiguousArray<Cell>
    ) {
        guard (1...canvas.columns).contains(coordinate.column), (1...canvas.rows).contains(coordinate.row) else { return }
        let index = (canvas.rows - coordinate.row) * canvas.columns + (coordinate.column - 1)
        cells[index] = .init(codepoint: visual.symbol, foreground: visual.foreground, background: 0)
    }

    private var hasPendingWork: Bool {
        currentRow < rows.count || carriageReturn != nil || glyphs.contains { $0.sceneActive }
    }

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
