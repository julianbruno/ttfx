import Foundation
import TTFXCore

public struct MatrixEffect: Effect {
    public struct Configuration: Sendable {
        public var highlightColor: Color
        public var rainColorGradient: [Color]
        public var rainSymbols: [String]
        public var rainFallDelayRange: ClosedRange<Int>
        public var rainColumnDelayRange: ClosedRange<Int>
        public var rainTime: Int
        public var symbolSwapChance: Double
        public var colorSwapChance: Double
        public var resolveDelay: Int
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientFrames: Int
        public var finalGradientDirection: GradientDirection

        public init(
            highlightColor: Color = Color(hex: "dbffdb"),
            rainColorGradient: [Color] = [Color(hex: "92be92"), Color(hex: "185318")],
            rainSymbols: [String] = ["2", "5", "9", "8", "Z", "*", ")", ":", ".", "\"", "=", "+", "-", "¦", "|", "_", "ｦ", "ｱ", "ｳ", "ｴ", "ｵ", "ｶ", "ｷ", "ｹ", "ｺ", "ｻ", "ｼ", "ｽ", "ｾ", "ｿ", "ﾀ", "ﾂ", "ﾃ", "ﾅ", "ﾆ", "ﾇ", "ﾈ", "ﾊ", "ﾋ", "ﾎ", "ﾏ", "ﾐ", "ﾑ", "ﾒ", "ﾓ", "ﾔ", "ﾕ", "ﾗ", "ﾘ", "ﾜ"],
            rainFallDelayRange: ClosedRange<Int> = 2...15,
            rainColumnDelayRange: ClosedRange<Int> = 3...9,
            rainTime: Int = 15,
            symbolSwapChance: Double = 0.005,
            colorSwapChance: Double = 0.001,
            resolveDelay: Int = 3,
            finalGradientStops: [Color] = [Color(hex: "92be92"), Color(hex: "336b33")],
            finalGradientSteps: [Int] = [12],
            finalGradientFrames: Int = 3,
            finalGradientDirection: GradientDirection = .radial
        ) {
            precondition(!rainColorGradient.isEmpty, "rain color gradient must not be empty")
            precondition(!rainSymbols.isEmpty, "rain symbols must not be empty")
            precondition(rainFallDelayRange.lowerBound > 0, "rain fall delay must be positive")
            precondition(rainColumnDelayRange.lowerBound > 0, "rain column delay must be positive")
            precondition(rainTime > 0, "rain time must be positive")
            precondition(symbolSwapChance > 0 && colorSwapChance > 0, "swap chances must be positive")
            precondition(resolveDelay > 0, "resolve delay must be positive")
            precondition(finalGradientFrames > 0, "final gradient frames must be positive")
            self.highlightColor = highlightColor
            self.rainColorGradient = rainColorGradient
            self.rainSymbols = rainSymbols
            self.rainFallDelayRange = rainFallDelayRange
            self.rainColumnDelayRange = rainColumnDelayRange
            self.rainTime = rainTime
            self.symbolSwapChance = symbolSwapChance
            self.colorSwapChance = colorSwapChance
            self.resolveDelay = resolveDelay
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientFrames = finalGradientFrames
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private let canvas: Canvas
    private let input: InputText
    private let options: Configuration
    private var tickIndex = 0
    private var complete = false
    private let finalColors: [UInt32]

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, matrixConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        matrixConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.input = input
        self.options = matrixConfiguration
        self.finalColors = Self.resolveColors(input: input, options: matrixConfiguration)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !complete else { return .complete }
        if canvas.columns == 1, canvas.rows == 1, input.scalars.count == 1 {
            renderOneCell(into: &frame)
            tickIndex += 1
            if tickIndex >= 76 {
                complete = true
                return .complete
            }
            return .running
        }

        renderFallback(into: &frame)
        tickIndex += 1
        if tickIndex > max(1, options.rainTime * 60) + 16 {
            complete = true
            return .complete
        }
        return .running
    }

    private mutating func renderOneCell(into frame: inout Frame) {
        let rainSymbol = options.rainSymbols[0].unicodeScalars.first?.value ?? 120
        switch tickIndex {
        case 0...1:
            frame[column: 1, row: 1] = Cell(codepoint: rainSymbol, foreground: rgb(options.highlightColor), background: 0)
        case 2...61:
            frame[column: 1, row: 1] = Cell(codepoint: rainSymbol, foreground: rainRGB(), background: 0)
        case 62...63:
            frame[column: 1, row: 1] = .blank
        case 64...65:
            frame[column: 1, row: 1] = Cell(codepoint: rainSymbol, foreground: rgb(options.highlightColor), background: 0)
        default:
            let colors = resolveGradient(start: options.highlightColor, end: color(finalColors.first ?? rgb(options.finalGradientStops.last ?? options.highlightColor)))
            let colorIndex = min(tickIndex - 66, colors.count - 1)
            frame[column: 1, row: 1] = Cell(codepoint: input.scalars[0], foreground: colors[colorIndex], background: 0)
        }
    }

    private mutating func renderFallback(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
        }
        let showFinal = tickIndex > max(1, options.rainTime * 60)
        for (index, scalar) in input.scalars.enumerated() {
            let position = input.positions[index]
            let foreground = showFinal ? finalColors[index] : rainRGB()
            let symbol = showFinal ? scalar : (options.rainSymbols[0].unicodeScalars.first?.value ?? scalar)
            frame[column: position.column, row: position.row] = Cell(codepoint: symbol, foreground: foreground, background: 0)
        }
    }

    private func rainRGB() -> UInt32 {
        let gradient = try! Gradient(stops: options.rainColorGradient, steps: 6)
        return rgb(gradient.spectrum[0])
    }

    private func resolveGradient(start: Color, end: Color) -> [UInt32] {
        let gradient = try! Gradient(stops: [start, end], steps: 8)
        return gradient.spectrum.map(rgb) + [rgb(end)]
    }

    private static func resolveColors(input: InputText, options: Configuration) -> [UInt32] {
        guard !input.positions.isEmpty else { return [] }
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! gradient.coordinateColorMapping(
            minRow: coordinates.map(\.row).min()!,
            maxRow: coordinates.map(\.row).max()!,
            minColumn: coordinates.map(\.column).min()!,
            maxColumn: coordinates.map(\.column).max()!,
            direction: options.finalGradientDirection
        )).entries.map { ($0.coordinate, rgb($0.color)) })
        return coordinates.map { mapping[$0] ?? rgb(options.finalGradientStops.last ?? options.highlightColor) }
    }

    private func rgb(_ color: Color) -> UInt32 { Self.rgb(color) }
    private static func rgb(_ color: Color) -> UInt32 {
        (UInt32(color.red) << 16) | (UInt32(color.green) << 8) | UInt32(color.blue)
    }

    private func color(_ word: UInt32) -> Color {
        Color(hex: String(format: "%06x", word & 0xFF_FFFF))
    }
}
