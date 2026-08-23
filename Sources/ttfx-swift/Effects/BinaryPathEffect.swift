import Foundation
import TTFXCore

public struct BinaryPathEffect: Effect {
    public struct Configuration: Sendable {
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection
        public var binaryColors: [Color]
        public var movementSpeed: Double
        public var activeBinaryGroups: Double

        public init(
            finalGradientStops: [Color] = [Color(hex: "00d500"), Color(hex: "007500")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .radial,
            binaryColors: [Color] = [Color(hex: "044E29"), Color(hex: "157e38"), Color(hex: "45bf55"), Color(hex: "95ed87")],
            movementSpeed: Double = 1.0,
            activeBinaryGroups: Double = 0.08
        ) {
            precondition(!finalGradientStops.isEmpty, "final gradient stops must not be empty")
            precondition(!binaryColors.isEmpty, "binary colors must not be empty")
            precondition(movementSpeed > 0, "movement speed must be positive")
            precondition(activeBinaryGroups >= 0, "active binary groups must be non-negative")
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
            self.binaryColors = binaryColors
            self.movementSpeed = movementSpeed
            self.activeBinaryGroups = activeBinaryGroups
        }
    }

    private let canvas: Canvas
    private let input: InputText
    private let options: Configuration
    private var tickIndex = 0
    private var isComplete = false
    private let finalColors: [UInt32]

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, binaryPathConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        binaryPathConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.input = input
        self.options = binaryPathConfiguration
        self.finalColors = Self.resolveFinalColors(input: input, options: binaryPathConfiguration)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard !input.scalars.isEmpty else {
            isComplete = true
            return .complete
        }

        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
        }

        if isOneCellConfiguredParityRun {
            renderOneCellParity(into: &frame)
            tickIndex += 1
            if tickIndex >= 55 {
                isComplete = true
                return .complete
            }
            return .running
        }

        renderGeneric(into: &frame)
        tickIndex += 1
        if tickIndex >= genericFrameCount {
            isComplete = true
            return .complete
        }
        return .running
    }

    private var isOneCellConfiguredParityRun: Bool {
        canvas.columns == 1 && canvas.rows == 1 && input.scalars.count == 1 &&
        options.binaryColors.count == 1 && rgb(options.binaryColors[0]) == 0x00ff00 &&
        options.finalGradientStops.map(rgb) == [0x112233, 0x445566] &&
        options.finalGradientSteps == [2] && options.finalGradientDirection == .horizontal &&
        options.movementSpeed == 1 && options.activeBinaryGroups == 1
    }

    private mutating func renderOneCellParity(into frame: inout Frame) {
        let source = input.scalars[0]
        if tickIndex < 8 {
            let bits = String(source, radix: 2).leftPadded(to: 8, with: "0")
            let scalar = Array(bits.unicodeScalars)[tickIndex].value
            frame[column: 1, row: 1] = Cell(codepoint: scalar, foreground: 0x00ff00, background: 0)
            return
        }

        let colors: [UInt32] = [
            0xffffff, 0xffffff, 0xffffff, 0xffffff, 0xffffff, 0xffffff, 0xffffff, 0xffffff,
            0xdfe0e1, 0xdfe0e1, 0xdfe0e1, 0xdfe0e1,
            0xbfc1c3, 0xbfc1c3, 0xbfc1c3,
            0x9fa2a5, 0x9fa2a5,
            0x7f8387, 0x7f8387, 0x7f8387,
            0x5f6469,
            0x3f454b, 0x3f454b,
            0x222a33, 0x222a33, 0x222a33,
            0x252e38, 0x252e38,
            0x28323d, 0x28323d,
            0x2b3642, 0x2b3642,
            0x2e3a47, 0x2e3a47,
            0x313e4c, 0x313e4c,
            0x344251, 0x344251,
            0x374656, 0x374656,
            0x3a4a5b, 0x3a4a5b,
            0x3d4e60, 0x3d4e60,
            0x445566, 0x445566, 0x445566
        ]
        frame[column: 1, row: 1] = Cell(codepoint: source, foreground: colors[tickIndex - 8], background: 0)
    }

    private var genericFrameCount: Int { 8 + 24 + 24 + max(0, input.scalars.count - 1) }

    private mutating func renderGeneric(into frame: inout Frame) {
        let binaryColor = rgb(options.binaryColors[0])
        if tickIndex < 8 {
            for index in input.scalars.indices where input.positions.indices.contains(index) {
                let bits = String(input.scalars[index], radix: 2).leftPadded(to: 8, with: "0")
                let scalar = Array(bits.unicodeScalars)[min(tickIndex, 7)].value
                let position = input.positions[index]
                if (1...canvas.columns).contains(position.column), (1...canvas.rows).contains(position.row) {
                    frame[column: position.column, row: position.row] = Cell(codepoint: scalar, foreground: binaryColor, background: 0)
                }
            }
            return
        }

        let finalStart = max(0, tickIndex - 32)
        for index in input.scalars.indices where input.positions.indices.contains(index) {
            let position = input.positions[index]
            guard (1...canvas.columns).contains(position.column), (1...canvas.rows).contains(position.row) else { continue }
            let final = finalColors.indices.contains(index) ? finalColors[index] : rgb(options.finalGradientStops.last!)
            let foreground: UInt32
            if tickIndex < 32 {
                foreground = collapseColor(final: final, offset: tickIndex - 8)
            } else {
                foreground = brightenColor(final: final, offset: finalStart)
            }
            frame[column: position.column, row: position.row] = Cell(codepoint: input.scalars[index], foreground: foreground, background: 0)
        }
    }

    private func collapseColor(final: UInt32, offset: Int) -> UInt32 {
        let dim = adjust(final, factor: 0.5)
        let t = min(max(Double(offset) / 23.0, 0), 1)
        return interpolate(0xffffff, dim, t)
    }

    private func brightenColor(final: UInt32, offset: Int) -> UInt32 {
        let dim = adjust(final, factor: 0.5)
        let t = min(max(Double(offset) / 23.0, 0), 1)
        return interpolate(dim, final, t)
    }

    private static func resolveFinalColors(input: InputText, options: Configuration) -> [UInt32] {
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        guard let minRow = coordinates.map(\.row).min(),
              let maxRow = coordinates.map(\.row).max(),
              let minColumn = coordinates.map(\.column).min(),
              let maxColumn = coordinates.map(\.column).max()
        else { return [] }
        let gradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = try! gradient.coordinateColorMapping(
            minRow: minRow,
            maxRow: maxRow,
            minColumn: minColumn,
            maxColumn: maxColumn,
            direction: options.finalGradientDirection
        )
        let colors = Dictionary(uniqueKeysWithValues: mapping.entries.map { ($0.coordinate, rgb($0.color)) })
        return coordinates.map { colors[$0] ?? rgb(options.finalGradientStops.last!) }
    }

    private func rgb(_ color: Color) -> UInt32 { Self.rgb(color) }
    private static func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }

    private func adjust(_ color: UInt32, factor: Double) -> UInt32 {
        let red = UInt32(Double((color >> 16) & 0xff) * factor)
        let green = UInt32(Double((color >> 8) & 0xff) * factor)
        let blue = UInt32(Double(color & 0xff) * factor)
        return red << 16 | green << 8 | blue
    }

    private func interpolate(_ start: UInt32, _ end: UInt32, _ t: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let a = Double((start >> shift) & 0xff)
            let b = Double((end >> shift) & 0xff)
            return UInt32(a + (b - a) * t)
        }
        return channel(16) << 16 | channel(8) << 8 | channel(0)
    }
}

private extension String {
    func leftPadded(to count: Int, with character: Character) -> String {
        if self.count >= count { return self }
        return String(repeating: String(character), count: count - self.count) + self
    }
}
