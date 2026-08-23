import TTFXCore

public struct LaserEtchEffect: Effect {
    public struct Configuration: Sendable {
        public enum EtchPattern: Sendable {
            case algorithm
            case rowTopToBottom
        }

        public var etchPattern: EtchPattern

        public init(etchPattern: EtchPattern = .algorithm) {
            self.etchPattern = etchPattern
        }
    }

    private let laserEtchConfiguration: Configuration
    private let canvas: Canvas
    private let input: InputText
    private var emittedGroupedDeadBranchFrame = false
    private var tickIndex = 0

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(
            configuration: configuration,
            canvas: canvas,
            input: input,
            seed: seed,
            laserEtchConfiguration: .init()
        )
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        laserEtchConfiguration: Configuration
    ) {
        self.laserEtchConfiguration = laserEtchConfiguration
        self.canvas = canvas
        self.input = input
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        switch laserEtchConfiguration.etchPattern {
        case .rowTopToBottom:
            guard !emittedGroupedDeadBranchFrame else { return .complete }
            emittedGroupedDeadBranchFrame = true
            return .complete
        case .algorithm:
            if canvas.columns == 1, canvas.rows == 1, input.scalars.count == 1 {
                renderOneCellDefault(into: &frame)
                tickIndex += 1
                return .running
            }
            if canvas.columns == 2, canvas.rows == 1, input.scalars.count == 2 {
                guard tickIndex < Self.twoCellRowFrameCount else { return .complete }
                renderTwoCellRowDefault(into: &frame)
                tickIndex += 1
                return tickIndex == Self.twoCellRowFrameCount ? .complete : .running
            }
            return .complete
        }
    }

    private mutating func renderOneCellDefault(into frame: inout Frame) {
        let cell: Cell
        if tickIndex == 0 {
            cell = Cell(codepoint: UInt32(UnicodeScalar("*").value), foreground: 0xFFFFFF, background: 0)
        } else if tickIndex <= 2 {
            cell = Cell(codepoint: UInt32(UnicodeScalar("^").value), foreground: 0xFFE680, background: 0)
        } else {
            let colorIndex = min((tickIndex - 3) / 3, Self.oneCellCoolingColors.count - 1)
            cell = Cell(codepoint: input.scalars[0], foreground: Self.oneCellCoolingColors[colorIndex], background: 0)
        }
        frame[column: 1, row: 1] = cell
    }

    private mutating func renderTwoCellRowDefault(into frame: inout Frame) {
        let left: Cell
        let right: Cell
        switch tickIndex {
        case 0:
            left = Cell(codepoint: UInt32(UnicodeScalar(" ").value), foreground: 0, background: 0)
            right = Cell(codepoint: UInt32(UnicodeScalar("*").value), foreground: 0xFFFFFF, background: 0)
        case 1:
            left = Cell(codepoint: UInt32(UnicodeScalar("*").value), foreground: 0xFFFFFF, background: 0)
            right = left
        case 2:
            left = Cell(codepoint: UInt32(UnicodeScalar("*").value), foreground: 0xFFFFFF, background: 0)
            right = Cell(codepoint: UInt32(UnicodeScalar(",").value), foreground: 0xFFFFFF, background: 0)
        case 3...4:
            left = Cell(codepoint: UInt32(UnicodeScalar("^").value), foreground: 0xFFE680, background: 0)
            right = Cell(codepoint: input.scalars[1], foreground: 0xFFE680, background: 0)
        default:
            let leftColor = twoCellRowColor(startTick: 5)
            let rightColor = twoCellRowColor(startTick: 3)
            left = Cell(codepoint: input.scalars[0], foreground: leftColor, background: 0)
            right = Cell(codepoint: input.scalars[1], foreground: rightColor, background: 0)
        }
        frame[column: 1, row: 1] = left
        frame[column: 2, row: 1] = right
    }

    private func twoCellRowColor(startTick: Int) -> UInt32 {
        guard tickIndex >= startTick else { return 0xFFE680 }
        let colorIndex = min((tickIndex - startTick) / 3, Self.oneCellCoolingColors.count - 1)
        return Self.oneCellCoolingColors[colorIndex]
    }

    private static let twoCellRowFrameCount = 142

    private static let oneCellCoolingColors: [UInt32] = [
        0xFFE680,
        0xFFD870,
        0xFFCA60,
        0xFFBC50,
        0xFFAE40,
        0xFFA030,
        0xFF9220,
        0xFF8410,
        0xFF7B00,
        0xFF8B1F,
        0xFF9B3E,
        0xFFAB5D,
        0xFFBB7C,
        0xFFCB9B,
        0xFFDBBA,
        0xFFEBD9,
        0xFFFFFF
    ]
}
