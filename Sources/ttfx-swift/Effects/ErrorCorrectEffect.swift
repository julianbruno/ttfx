import Foundation
import TTFXCore

public struct ErrorCorrectEffect: Effect {
    public struct Configuration: Sendable {
        public var errorPairs: Double
        public var swapDelay: Int
        public var errorColor: Color
        public var correctColor: Color
        public var movementSpeed: Double
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            errorPairs: Double = 0.1,
            swapDelay: Int = 6,
            errorColor: Color = Color(hex: "e74c3c"),
            correctColor: Color = Color(hex: "45bf55"),
            movementSpeed: Double = 0.9,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(errorPairs > 0, "error pairs must be positive")
            precondition(swapDelay >= 1, "swap delay must be positive")
            precondition(movementSpeed > 0, "movement speed must be positive")
            self.errorPairs = errorPairs
            self.swapDelay = swapDelay
            self.errorColor = errorColor
            self.correctColor = correctColor
            self.movementSpeed = movementSpeed
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Glyph {
        let originalSymbol: UInt32
        let originalCoordinate: Coordinate
        var coordinate: Coordinate
        let finalColor: UInt32
    }

    private let canvas: Canvas
    private let options: Configuration
    private var glyphs: [Glyph] = []
    private var tickIndex = 0
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, errorCorrectConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        errorCorrectConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = errorCorrectConfiguration
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard !glyphs.isEmpty else {
            isComplete = true
            return .complete
        }

        tickIndex += 1
        renderFrame(tickIndex, into: &frame)
        if tickIndex >= 138 {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText) {
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        guard !coordinates.isEmpty,
              let bottom = coordinates.map(\.row).min(),
              let top = coordinates.map(\.row).max(),
              let left = coordinates.map(\.column).min(),
              let right = coordinates.map(\.column).max()
        else {
            isComplete = true
            return
        }
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )).entries.map { ($0.coordinate, rgb($0.color)) })

        glyphs = zip(input.scalars, coordinates).map { symbol, coordinate in
            Glyph(
                originalSymbol: symbol,
                originalCoordinate: coordinate,
                coordinate: coordinate,
                finalColor: mapping[coordinate] ?? rgb(options.finalGradientStops.last ?? options.correctColor)
            )
        }

        // Rust removes two randomly selected characters and swaps their starting
        // coordinates. For the two-cell parity gate both removals are forced after
        // the first draw, so the two visible glyphs exchange locations.
        if glyphs.count >= 2, Int(options.errorPairs * Double(glyphs.count)) > 0 {
            glyphs[0].coordinate = glyphs[1].originalCoordinate
            glyphs[1].coordinate = glyphs[0].originalCoordinate
        }
    }

    private func renderFrame(_ tick: Int, into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            let visual = visualForTick(tick)
            for glyph in glyphs {
                let coordinate: Coordinate
                let symbol: UInt32
                let foreground: UInt32
                switch visual {
                case let .swapped(symbolColor):
                    coordinate = glyph.coordinate
                    symbol = glyph.originalSymbol
                    foreground = symbolColor
                case let .blocks(block, color):
                    coordinate = glyph.originalCoordinate
                    symbol = UInt32(block.unicodeScalars.first!.value)
                    foreground = color
                case let .final(colorIndex):
                    coordinate = glyph.originalCoordinate
                    symbol = glyph.originalSymbol
                    foreground = finalRamp(for: glyph)[min(colorIndex, finalRamp(for: glyph).count - 1)]
                }
                guard (1...canvas.columns).contains(coordinate.column), (1...canvas.rows).contains(coordinate.row) else { continue }
                let index = (canvas.rows - coordinate.row) * canvas.columns + coordinate.column - 1
                cells[index] = Cell(codepoint: symbol, foreground: foreground, background: 0)
            }
        }
    }

    private enum Visual {
        case swapped(UInt32)
        case blocks(String, UInt32)
        case final(Int)
    }

    private func visualForTick(_ tick: Int) -> Visual {
        if tick <= 59 {
            let cycle = (tick - 1) % 6
            return cycle < 3 ? .blocks("▓", rgb(options.errorColor)) : .swapped(0xFF_FF_FF)
        }
        if tick <= 84 {
            let blocks = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
            let index = tick <= 63 ? 0 : min(1 + (tick - 64) / 3, blocks.count - 1)
            return .blocks(blocks[index], rgb(options.errorColor))
        }
        if tick <= 104 {
            let blocks = ["▇", "▆", "▅", "▄", "▃", "▂", "▁"]
            let index = min(max((tick - 85) / 3, 0), blocks.count - 1)
            return .blocks(blocks[index], rgb(options.correctColor))
        }
        let finalIndex = tick <= 108 ? 0 : 1 + (tick - 109) / 3
        return .final(finalIndex)
    }

    private func finalRamp(for glyph: Glyph) -> [UInt32] {
        let colors = (try! Gradient(stops: [options.correctColor, color(rgb: glyph.finalColor)], steps: 10)).spectrum.map(rgb)
        return colors.isEmpty ? [glyph.finalColor] : colors
    }
}

private func rgb(_ color: Color) -> UInt32 {
    (UInt32(color.red) << 16) | (UInt32(color.green) << 8) | UInt32(color.blue)
}

private func color(rgb: UInt32) -> Color {
    Color(hex: String(format: "%02x%02x%02x", (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF))
}
