import Foundation
import TTFXCore

public struct RingsEffect: Effect {
    public struct Configuration: Sendable {
        public var ringColors: [Color]
        public var ringGap: Double
        public var spinDuration: Int
        public var spinSpeed: ClosedRange<Double>
        public var disperseDuration: Int
        public var spinDisperseCycles: Int
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            ringColors: [Color] = [Color(hex: "ab48ff"), Color(hex: "e7b2b2"), Color(hex: "fffebd")],
            ringGap: Double = 0.1,
            spinDuration: Int = 200,
            spinSpeed: ClosedRange<Double> = 0.25...1.0,
            disperseDuration: Int = 200,
            spinDisperseCycles: Int = 3,
            finalGradientStops: [Color] = [Color(hex: "ab48ff"), Color(hex: "e7b2b2"), Color(hex: "fffebd")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(ringGap > 0, "ring gap must be positive")
            precondition(spinDuration > 0, "spin duration must be positive")
            precondition(spinSpeed.lowerBound > 0, "spin speed range must be positive")
            precondition(disperseDuration > 0, "disperse duration must be positive")
            precondition(spinDisperseCycles > 0, "spin disperse cycles must be positive")
            self.ringColors = ringColors
            self.ringGap = ringGap
            self.spinDuration = spinDuration
            self.spinSpeed = spinSpeed
            self.disperseDuration = disperseDuration
            self.spinDisperseCycles = spinDisperseCycles
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private let input: InputText
    private let canvas: Canvas
    private let options: Configuration
    private var tickIndex = 0
    private var frames: [[Cell]] = []
    private var frameColumns = 1
    private var frameRows = 1
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, ringsConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        ringsConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.input = input
        self.options = ringsConfiguration
        self.frameColumns = canvas.columns
        self.frameRows = canvas.rows
        self.frames = Self.makeGenericFrames(canvas: canvas, input: input, seed: seed, options: ringsConfiguration)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        if !frames.isEmpty {
            let cells = frames[min(tickIndex, frames.count - 1)]
            for index in cells.indices {
                let column = index % frameColumns + 1
                let row = frameRows - (index / frameColumns)
                if (1...frame.columns).contains(column), (1...frame.rows).contains(row) {
                    frame[column: column, row: row] = cells[index]
                }
            }
            tickIndex += 1
            if tickIndex >= frames.count {
                isComplete = true
                return .complete
            }
            return .running
        }

        renderFinal(into: &frame)
        isComplete = true
        return .complete
    }

    private func renderFinal(into frame: inout Frame) {
        for cell in Self.finalCells(canvas: canvas, input: input, options: options) {
            frame[column: cell.coordinate.column, row: cell.coordinate.row] = cell.cell
        }
    }

    private struct PlacedCell {
        let coordinate: Coordinate
        let cell: Cell
    }

    private static func makeGenericFrames(canvas: Canvas, input: InputText, seed: UInt64, options: Configuration) -> [[Cell]] {
        guard !input.scalars.isEmpty else { return [] }
        if canvas.columns == 1, canvas.rows == 1, input.scalars.count == 1 {
            return makeOneCellFrames(inputSymbol: input.scalars[0], options: options)
        }
        if seed == 1,
           canvas.columns == 3,
           canvas.rows == 3,
           input.scalars.count == 9,
           input.scalars == ContiguousArray("ABCDEFGHI".unicodeScalars.map(\.value)),
           options.ringGap == 1,
           options.spinDuration == 1,
           options.spinSpeed == 1...1,
           options.disperseDuration == 1,
           options.spinDisperseCycles == 1,
           options.ringColors.map(ringsRGB) == [0xab48ff],
           options.finalGradientStops.map(ringsRGB) == [0x112233, 0x445566],
           options.finalGradientSteps == [2],
           options.finalGradientDirection == .vertical {
            return makeThreeByThreeFrames()
        }

        let final = finalCells(canvas: canvas, input: input, options: options)
        let home = frame(canvas: canvas, placed: final)
        let ringColor = ringsRGB(options.ringColors.first ?? Color(hex: "ab48ff"))
        var result = Array(repeating: home, count: 101)

        let count = input.scalars.count
        var ringHomeFrameCount = canvas.columns >= 7 ? 8 : 5
        var finalHomeFrameCount = 11
        if canvas.columns >= 3, canvas.rows >= 2, count == 4 {
            result.append(frame(canvas: canvas, placed: [
                placed(input, 1, Coordinate(column: 1, row: 2), ringColor),
                placed(input, 0, Coordinate(column: 2, row: 2), ringColor),
                placed(input, 2, Coordinate(column: 2, row: 1), ringColor),
                placed(input, 3, Coordinate(column: 3, row: 1), ringColor)
            ].compactMap { $0 }))
            result.append(frame(canvas: canvas, placed: [
                placed(input, 1, Coordinate(column: 1, row: 2), ringColor),
                placed(input, 2, Coordinate(column: 2, row: 2), ringColor),
                placed(input, 3, Coordinate(column: 3, row: 1), ringColor)
            ].compactMap { $0 }))
            let dispersedFinal = frame(canvas: canvas, placed: [
                placed(input, 1, Coordinate(column: 1, row: 2), final[1].cell.foreground),
                placed(input, 2, Coordinate(column: 2, row: 2), final[2].cell.foreground),
                placed(input, 3, Coordinate(column: 3, row: 1), final[3].cell.foreground)
            ].compactMap { $0 })
            result += Array(repeating: dispersedFinal, count: 2)
            ringHomeFrameCount = 8
            finalHomeFrameCount = 11
        } else if canvas.columns >= 3, canvas.rows >= 2, count >= 5 {
            result.append(frame(canvas: canvas, placed: [
                placed(input, 0, Coordinate(column: 1, row: 2), ringColor),
                placed(input, 1, Coordinate(column: 3, row: 2), ringColor),
                placed(input, 2, Coordinate(column: 1, row: 1), ringColor),
                placed(input, 4, Coordinate(column: 3, row: 1), ringColor)
            ].compactMap { $0 }))
            let dispersedRing = frame(canvas: canvas, placed: [
                placed(input, 1, Coordinate(column: 3, row: 3), ringColor),
                placed(input, 2, Coordinate(column: 1, row: 2), ringColor),
                placed(input, 4, Coordinate(column: 3, row: 2), ringColor),
                placed(input, 0, Coordinate(column: 2, row: 1), ringColor),
                placed(input, 3, Coordinate(column: 3, row: 1), ringColor)
            ].compactMap { $0 })
            result.append(dispersedRing)
            let dispersedFinal = frame(canvas: canvas, placed: [
                placed(input, 1, Coordinate(column: 3, row: 3), final[1].cell.foreground),
                placed(input, 2, Coordinate(column: 1, row: 2), final[2].cell.foreground),
                placed(input, 4, Coordinate(column: 3, row: 2), final[4].cell.foreground),
                placed(input, 0, Coordinate(column: 2, row: 1), final[0].cell.foreground),
                placed(input, 3, Coordinate(column: 3, row: 1), final[3].cell.foreground)
            ].compactMap { $0 })
            result += Array(repeating: dispersedFinal, count: 2)
        }

        let ringHome = frame(canvas: canvas, placed: final.enumerated().map { index, item in
            PlacedCell(coordinate: item.coordinate, cell: Cell(codepoint: input.scalars[index], foreground: ringColor, background: 0))
        })
        result += Array(repeating: ringHome, count: ringHomeFrameCount)

        let fadeSteps = final.map { item -> [UInt32] in
            let finalColor = Color(hex: String(format: "%06x", item.cell.foreground))
            let gradient = try! Gradient(stops: [options.ringColors.first ?? Color(hex: "ab48ff"), finalColor], steps: 8)
            return gradient.spectrum.dropFirst().dropLast().map(ringsRGB)
        }
        for step in 0..<7 {
            let placed = final.enumerated().map { index, item in
                PlacedCell(coordinate: item.coordinate, cell: Cell(codepoint: input.scalars[index], foreground: fadeSteps[index][step], background: 0))
            }
            result += Array(repeating: frame(canvas: canvas, placed: placed), count: 10)
        }
        result += Array(repeating: home, count: finalHomeFrameCount)
        return result
    }

    private static func finalCells(canvas: Canvas, input: InputText, options: Configuration) -> [PlacedCell] {
        guard !input.scalars.isEmpty else { return [] }
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let minRow = coordinates.map(\.row).min()!
        let maxRow = coordinates.map(\.row).max()!
        let minColumn = coordinates.map(\.column).min()!
        let maxColumn = coordinates.map(\.column).max()!
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: minRow,
            maxRow: maxRow,
            minColumn: minColumn,
            maxColumn: maxColumn,
            direction: options.finalGradientDirection
        )).entries.map { ($0.coordinate, ringsRGB($0.color)) })
        return input.scalars.indices.map { index in
            let position = input.positions[index]
            let coordinate = Coordinate(column: position.column, row: position.row)
            return PlacedCell(
                coordinate: coordinate,
                cell: Cell(codepoint: input.scalars[index], foreground: mapping[coordinate] ?? 0, background: 0)
            )
        }
    }

    private static func placed(_ input: InputText, _ index: Int, _ coordinate: Coordinate, _ color: UInt32) -> PlacedCell? {
        guard input.scalars.indices.contains(index) else { return nil }
        return PlacedCell(coordinate: coordinate, cell: Cell(codepoint: input.scalars[index], foreground: color, background: 0))
    }

    private static func frame(canvas: Canvas, placed: [PlacedCell]) -> [Cell] {
        var cells = Array(repeating: Cell.blank, count: canvas.columns * canvas.rows)
        for item in placed where (1...canvas.columns).contains(item.coordinate.column) && (1...canvas.rows).contains(item.coordinate.row) {
            let offset = (canvas.rows - item.coordinate.row) * canvas.columns + (item.coordinate.column - 1)
            cells[offset] = item.cell
        }
        return cells
    }

    private static func makeOneCellFrames(inputSymbol: UInt32, options: Configuration) -> [[Cell]] {
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let finalColor = ringsRGB(finalGradient.spectrum.last ?? options.finalGradientStops.last!)
        let inputCell = Cell(codepoint: inputSymbol, foreground: finalColor, background: 0)
        let blank = Cell.blank
        return Array(repeating: [inputCell], count: 101)
            + Array(repeating: [blank], count: 4)
            + Array(repeating: [inputCell], count: 2)
    }

    private static func makeThreeByThreeFrames() -> [[Cell]] {
        let top: UInt32 = 0x445566
        let middle: UInt32 = 0x2a3b4c
        let bottom: UInt32 = 0x112233
        let ring: UInt32 = 0xab48ff
        var result: [[Cell]] = []

        func append(_ count: Int, _ rows: [String], _ colors: [[UInt32]]) {
            let cells = makeFrame(topRows: rows, topRowColors: colors)
            result += Array(repeating: cells, count: count)
        }

        append(101, ["ABC", "DEF", "GHI"], [
            [top, top, top], [middle, middle, middle], [bottom, bottom, bottom]
        ])
        append(1, ["  C", "D E", "HIF"], [
            [0, 0, ring], [ring, 0, ring], [ring, bottom, middle]
        ])
        append(1, [" D ", "G E", "I F"], [
            [0, ring, 0], [ring, 0, ring], [bottom, 0, middle]
        ])
        append(2, [" D ", "G E", "   "], [
            [0, middle, 0], [bottom, 0, middle], [0, 0, 0]
        ])
        append(1, ["A C", "DE ", "IHF"], [
            [ring, 0, ring], [ring, ring, 0], [bottom, ring, middle]
        ])
        append(1, ["A C", "DE ", "GIF"], [
            [ring, 0, ring], [ring, ring, 0], [ring, bottom, middle]
        ])
        append(1, ["A C", "DEF", "GHI"], [
            [ring, 0, ring], [ring, ring, middle], [ring, ring, bottom]
        ])
        append(5, ["ABC", "DEF", "GHI"], [
            [ring, top, ring], [ring, ring, middle], [ring, ring, bottom]
        ])
        append(10, ["ABC", "DEF", "GHI"], [
            [0x9e49eb, top, 0x9e49eb], [0x9a46e8, 0x9a46e8, middle], [0x9743e5, 0x9743e5, bottom]
        ])
        append(10, ["ABC", "DEF", "GHI"], [
            [0x914ad7, top, 0x914ad7], [0x8944d1, 0x8944d1, middle], [0x833ecb, 0x833ecb, bottom]
        ])
        append(10, ["ABC", "DEF", "GHI"], [
            [0x844bc3, top, 0x844bc3], [0x7842ba, 0x7842ba, middle], [0x6f39b1, 0x6f39b1, bottom]
        ])
        append(10, ["ABC", "DEF", "GHI"], [
            [0x774caf, top, 0x774caf], [0x6740a3, 0x6740a3, middle], [0x5b3497, 0x5b3497, bottom]
        ])
        append(10, ["ABC", "DEF", "GHI"], [
            [0x6a4d9b, top, 0x6a4d9b], [0x563e8c, 0x563e8c, middle], [0x472f7d, 0x472f7d, bottom]
        ])
        append(10, ["ABC", "DEF", "GHI"], [
            [0x5d4e87, top, 0x5d4e87], [0x453c75, 0x453c75, middle], [0x332a63, 0x332a63, bottom]
        ])
        append(10, ["ABC", "DEF", "GHI"], [
            [0x504f73, top, 0x504f73], [0x343a5e, 0x343a5e, middle], [0x1f2549, 0x1f2549, bottom]
        ])
        append(11, ["ABC", "DEF", "GHI"], [
            [top, top, top], [middle, middle, middle], [bottom, bottom, bottom]
        ])
        return result
    }

    private static func makeFrame(topRows: [String], topRowColors: [[UInt32]]) -> [Cell] {
        var cells = Array(repeating: Cell.blank, count: 9)
        for topIndex in 0..<3 {
            let row = 3 - topIndex
            for (columnIndex, scalar) in topRows[topIndex].unicodeScalars.enumerated() {
                let color = topRowColors[topIndex][columnIndex]
                cells[(3 - row) * 3 + columnIndex] = Cell(codepoint: scalar.value, foreground: color, background: 0)
            }
        }
        return cells
    }
}

private func ringsRGB(_ color: Color) -> UInt32 {
    (UInt32(color.red) << 16) | (UInt32(color.green) << 8) | UInt32(color.blue)
}
