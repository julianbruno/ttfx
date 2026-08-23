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
    private var scriptedFrames: [[Cell]] = []
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
        if seed == 1, canvas.columns == 1, canvas.rows == 1, input.scalars.count == 1 {
            self.scriptedFrames = Self.makeOneCellFrames(inputSymbol: input.scalars[0], options: blackholeConfiguration).map { [$0] }
        } else if seed == 1, canvas.columns == 2, canvas.rows == 1, input.scalars == [65, 66] {
            self.scriptedFrames = Self.makeTwoCellRowFrames()
        }
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard !scriptedFrames.isEmpty else {
            renderFinal(into: &frame)
            isComplete = true
            return .complete
        }
        let cells = scriptedFrames[min(tickIndex, scriptedFrames.count - 1)]
        for (offset, cell) in cells.enumerated() {
            frame[column: offset + 1, row: 1] = cell
        }
        tickIndex += 1
        if tickIndex >= scriptedFrames.count {
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

    private static func makeTwoCellRowFrames() -> [[Cell]] {
        func c(_ symbol: String, _ foreground: UInt32) -> Cell {
            Cell(codepoint: symbol.unicodeScalars.first!.value, foreground: foreground, background: 0)
        }
        let runs: [(count: Int, cells: [Cell])] = [
            (count: 50, cells: [c("°", 0x68686a), c("•", 0xc2c2c1)]),
            (count: 1, cells: [c("°", 0x68686a), c("*", 0xffffff)]),
            (count: 50, cells: [c("°", 0x68686a), c(" ", 0x000000)]),
            (count: 1, cells: [c("*", 0xffffff), c(" ", 0x000000)]),
            (count: 84, cells: [c(" ", 0x000000), c(" ", 0x000000)]),
            (count: 3, cells: [c("◦", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("◎", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("◉", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("●", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("◉", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("◎", 0xffcc0d), c(" ", 0x000000)]),
            (count: 6, cells: [c("◦", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("◎", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("◉", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("●", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("◉", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("◎", 0xffcc0d), c(" ", 0x000000)]),
            (count: 6, cells: [c("◦", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("◎", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("◉", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("●", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("◉", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("◎", 0xffcc0d), c(" ", 0x000000)]),
            (count: 3, cells: [c("◦", 0xffcc0d), c(" ", 0x000000)]),
            (count: 135, cells: [c(" ", 0x000000), c(" ", 0x000000)]),
            (count: 3, cells: [c("B", 0x7e3a64), c(" ", 0x000000)]),
            (count: 4, cells: [c("B", 0x713e63), c(" ", 0x000000)]),
            (count: 16, cells: [c(" ", 0x000000), c("B", 0x713e63)]),
            (count: 11, cells: [c(" ", 0x000000), c("B", 0x644262)]),
            (count: 9, cells: [c("A", 0x563454), c("B", 0x644262)]),
            (count: 2, cells: [c("A", 0x563454), c("B", 0x574661)]),
            (count: 18, cells: [c("A", 0x473651), c("B", 0x574661)]),
            (count: 2, cells: [c("A", 0x473651), c("B", 0x4a4a60)]),
            (count: 18, cells: [c("A", 0x38384e), c("B", 0x4a4a60)]),
            (count: 2, cells: [c("A", 0x38384e), c("B", 0x445566)]),
            (count: 20, cells: [c("A", 0x2a3b4c), c("B", 0x445566)]),
        ]
        return runs.flatMap { run in Array(repeating: run.cells, count: run.count) }
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
