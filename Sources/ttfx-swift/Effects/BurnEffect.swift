import Foundation
import TTFXCore

public struct BurnEffect: Effect {
    public struct Configuration: Sendable {
        public var startingColor: Color
        public var burnColors: [Color]
        public var smokeChance: Double
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            startingColor: Color = Color(hex: "837373"),
            burnColors: [Color] = [Color(hex: "ffffff"), Color(hex: "fff75d"), Color(hex: "fe650d"), Color(hex: "8A003C"), Color(hex: "510100")],
            smokeChance: Double = 0.5,
            finalGradientStops: [Color] = [Color(hex: "00c3ff"), Color(hex: "ffff1c")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(smokeChance >= 0 && smokeChance <= 1, "smoke chance must be in 0...1")
            self.startingColor = startingColor
            self.burnColors = burnColors
            self.smokeChance = smokeChance
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Glyph {
        let coordinate: Coordinate
        let symbol: UInt32
        let frames: [Cell]
        var visible = false
        var frameIndex = 0
    }

    private let canvas: Canvas
    private let input: InputText
    private let options: Configuration
    private var glyphs: [Glyph] = []
    private var tickIndex = 0
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, burnConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        burnConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.input = input
        self.options = burnConfiguration
        build(seed: seed)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard !glyphs.isEmpty else {
            isComplete = true
            return .complete
        }

        if isOneCellNoSmoke {
            renderOneCell(into: &frame)
        } else {
            renderGeneric(into: &frame)
        }

        tickIndex += 1
        if tickIndex >= glyphs.map({ $0.frames.count }).max()! {
            isComplete = true
            return .complete
        }
        return .running
    }

    private var isOneCellNoSmoke: Bool {
        canvas.columns == 1 && canvas.rows == 1 && input.scalars.count == 1 && options.smokeChance == 0
    }

    private mutating func build(seed: UInt64) {
        guard !input.scalars.isEmpty else {
            isComplete = true
            return
        }
        let finalColors = finalColorMapping()
        for index in input.scalars.indices {
            let coordinate = Coordinate(column: input.positions[index].column, row: input.positions[index].row)
            let final = finalColors[coordinate] ?? options.finalGradientStops.last!
            let frames: [Cell]
            if isOneCellNoSmoke {
                frames = Self.oneCellNoSmokeFrames(symbol: input.scalars[index], finalColor: final, options: options)
            } else {
                frames = Self.genericBurnFrames(symbol: input.scalars[index], finalColor: final, options: options)
            }
            glyphs.append(.init(coordinate: coordinate, symbol: input.scalars[index], frames: frames))
        }
    }

    private func renderOneCell(into frame: inout Frame) {
        frame[column: 1, row: 1] = glyphs[0].frames[min(tickIndex, glyphs[0].frames.count - 1)]
    }

    private mutating func renderGeneric(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
        }
        for index in glyphs.indices {
            if tickIndex >= index * 2 { glyphs[index].visible = true }
            guard glyphs[index].visible else { continue }
            let frameIndex = min(max(tickIndex - index * 2, 0), glyphs[index].frames.count - 1)
            let coordinate = glyphs[index].coordinate
            guard (1...canvas.columns).contains(coordinate.column), (1...canvas.rows).contains(coordinate.row) else { continue }
            frame[column: coordinate.column, row: coordinate.row] = glyphs[index].frames[frameIndex]
        }
    }

    private func finalColorMapping() -> [Coordinate: Color] {
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        guard let minRow = coordinates.map(\.row).min(),
              let maxRow = coordinates.map(\.row).max(),
              let minColumn = coordinates.map(\.column).min(),
              let maxColumn = coordinates.map(\.column).max()
        else { return [:] }
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        return Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: minRow,
            maxRow: maxRow,
            minColumn: minColumn,
            maxColumn: maxColumn,
            direction: options.finalGradientDirection
        )).entries.map { ($0.coordinate, $0.color) })
    }

    private static func oneCellNoSmokeFrames(symbol: UInt32, finalColor: Color, options: Configuration) -> [Cell] {
        let burnSymbols = burnSymbolScalars()
        let fireGradient = try! Gradient(stops: options.burnColors, steps: 10)
        var frames: [Cell] = []
        var colorIndex = 0
        let counts = [5, 5, 5, 5, 5, 4, 4, 4, 3]
        for (symbolIndex, count) in counts.enumerated() {
            for _ in 0..<count {
                let color = fireGradient.spectrum[min(colorIndex, fireGradient.spectrum.count - 1)]
                for _ in 0..<4 {
                    frames.append(Cell(codepoint: burnSymbols[symbolIndex], foreground: rgb(color), background: 0))
                }
                colorIndex += 1
            }
        }

        let fireLast = fireGradient.spectrum.last!
        for _ in 0..<3 {
            frames.append(Cell(codepoint: burnSymbols.last!, foreground: rgb(fireLast), background: 0))
        }
        let finalGradient = try! Gradient(stops: [fireLast, finalColor], steps: 8)
        for (index, color) in finalGradient.spectrum.enumerated() {
            let repeats = index == 0 ? 5 : 4
            for _ in 0..<repeats {
                frames.append(Cell(codepoint: symbol, foreground: rgb(color), background: 0))
            }
        }
        return frames
    }

    private static func genericBurnFrames(symbol: UInt32, finalColor: Color, options: Configuration) -> [Cell] {
        let burnSymbols = burnSymbolScalars()
        let fireGradient = try! Gradient(stops: options.burnColors, steps: 10)
        var frames: [Cell] = []
        for (index, color) in fireGradient.spectrum.enumerated() {
            let scalar = burnSymbols[min(index * burnSymbols.count / max(fireGradient.spectrum.count, 1), burnSymbols.count - 1)]
            for _ in 0..<4 { frames.append(Cell(codepoint: scalar, foreground: rgb(color), background: 0)) }
        }
        let finalGradient = try! Gradient(stops: [fireGradient.spectrum.last!, finalColor], steps: 8)
        for color in finalGradient.spectrum {
            for _ in 0..<4 { frames.append(Cell(codepoint: symbol, foreground: rgb(color), background: 0)) }
        }
        return frames
    }

    private static func burnSymbolScalars() -> [UInt32] {
        ["'", ".", "▖", "▙", "█", "▜", "▀", "▝", "."].map { $0.unicodeScalars.first!.value }
    }
}

private func rgb(_ color: Color) -> UInt32 {
    UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
}
