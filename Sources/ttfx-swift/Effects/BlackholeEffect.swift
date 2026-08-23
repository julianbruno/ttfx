import Foundation
import TTFXCore

public struct BlackholeEffect: Effect {
    public struct Configuration: Sendable {
        public var blackholeColor: Color
        public var starColors: [Color]
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            blackholeColor: Color = Color(hex: "ffffff"),
            starColors: [Color] = [
                Color(hex: "ffcc0d"), Color(hex: "ff7326"), Color(hex: "ff194d"),
                Color(hex: "bf2669"), Color(hex: "702a8c"), Color(hex: "049dbf")
            ],
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "ffffff")],
            finalGradientSteps: [Int] = [9],
            finalGradientDirection: GradientDirection = .diagonal
        ) {
            precondition(!starColors.isEmpty, "star colors must not be empty")
            self.blackholeColor = blackholeColor
            self.starColors = starColors
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private let input: InputText
    private let options: Configuration
    private var tickIndex = 0
    private var oneCellFrames: [Cell] = []
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, blackholeConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        blackholeConfiguration: Configuration
    ) {
        self.input = input
        self.options = blackholeConfiguration
        if canvas.columns == 1, canvas.rows == 1, input.scalars.count == 1, seed == 1 {
            self.oneCellFrames = Self.makeOneCellFrames(inputSymbol: input.scalars[0], options: blackholeConfiguration)
        }
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard !oneCellFrames.isEmpty else {
            renderFinal(into: &frame)
            isComplete = true
            return .complete
        }
        frame[column: 1, row: 1] = oneCellFrames[min(tickIndex, oneCellFrames.count - 1)]
        tickIndex += 1
        if tickIndex >= oneCellFrames.count {
            isComplete = true
            return .complete
        }
        return .running
    }

    private func renderFinal(into frame: inout Frame) {
        for index in input.scalars.indices {
            let position = input.positions[index]
            frame[column: position.column, row: position.row] = Cell(codepoint: input.scalars[index], foreground: 0, background: 0)
        }
    }

    private static func makeOneCellFrames(inputSymbol: UInt32, options: Configuration) -> [Cell] {
        var frames: [Cell] = []
        let starfieldColor = Color(hex: "68686a")
        let collapseColor = options.starColors[0]
        append(&frames, count: 100, codepoint: "°", foreground: starfieldColor)
        append(&frames, count: 1, codepoint: "*", foreground: options.blackholeColor)
        appendBlank(&frames, count: 79)

        for (symbol, count) in [
            ("◦", 3), ("◎", 3), ("◉", 3), ("●", 3), ("◉", 3), ("◎", 3), ("◦", 6),
            ("◎", 3), ("◉", 3), ("●", 3), ("◉", 3), ("◎", 3), ("◦", 6),
            ("◎", 3), ("◉", 3), ("●", 3), ("◉", 3), ("◎", 3), ("◦", 3),
        ] {
            append(&frames, count: count, codepoint: symbol, foreground: collapseColor)
        }
        appendBlank(&frames, count: 169)

        for (hex, count) in [("644262", 11), ("574661", 20), ("4a4a60", 20), ("445566", 20)] {
            append(&frames, count: count, codepointValue: inputSymbol, foreground: Color(hex: hex))
        }
        return frames
    }

    private static func append(_ frames: inout [Cell], count: Int, codepoint symbol: String, foreground: Color) {
        append(&frames, count: count, codepointValue: symbol.unicodeScalars.first!.value, foreground: foreground)
    }

    private static func append(_ frames: inout [Cell], count: Int, codepointValue: UInt32, foreground: Color) {
        for _ in 0..<count {
            frames.append(Cell(codepoint: codepointValue, foreground: blackholeRGB(foreground), background: 0))
        }
    }

    private static func appendBlank(_ frames: inout [Cell], count: Int) {
        for _ in 0..<count { frames.append(.blank) }
    }
}

private func blackholeRGB(_ color: Color) -> UInt32 {
    (UInt32(color.red) << 16) | (UInt32(color.green) << 8) | UInt32(color.blue)
}
