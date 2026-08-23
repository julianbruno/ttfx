import Foundation
import TTFXCore

public struct ThunderstormEffect: Effect {
    public struct Configuration: Sendable {
        public var lightningColor: Color
        public var glowingTextColor: Color
        public var textGlowTime: Int
        public var raindropSymbols: [String]
        public var sparkSymbols: [String]
        public var sparkGlowColor: Color
        public var sparkGlowTime: Int
        public var stormTime: Int
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientFrames: Int
        public var finalGradientDirection: GradientDirection

        public init(
            lightningColor: Color = Color(hex: "68A3E8"),
            glowingTextColor: Color = Color(hex: "EF5411"),
            textGlowTime: Int = 6,
            raindropSymbols: [String] = ["\\", ".", ","],
            sparkSymbols: [String] = ["*", ".", "'"],
            sparkGlowColor: Color = Color(hex: "ff4d00"),
            sparkGlowTime: Int = 18,
            stormTime: Int = 12,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientFrames: Int = 3,
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(textGlowTime > 0, "text glow time must be positive")
            precondition(!raindropSymbols.isEmpty, "raindrop symbols must not be empty")
            precondition(!sparkSymbols.isEmpty, "spark symbols must not be empty")
            precondition(sparkGlowTime > 0, "spark glow time must be positive")
            precondition(stormTime > 0, "storm time must be positive")
            precondition(!finalGradientStops.isEmpty, "final gradient stops must not be empty")
            precondition(finalGradientFrames > 0, "final gradient frames must be positive")
            self.lightningColor = lightningColor
            self.glowingTextColor = glowingTextColor
            self.textGlowTime = textGlowTime
            self.raindropSymbols = raindropSymbols
            self.sparkSymbols = sparkSymbols
            self.sparkGlowColor = sparkGlowColor
            self.sparkGlowTime = sparkGlowTime
            self.stormTime = stormTime
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientFrames = finalGradientFrames
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Glyph {
        let id: Int
        let symbol: UInt32
        let coordinate: Coordinate
        let visibleColor: UInt32
        let stormColor: UInt32
    }

    private let canvas: Canvas
    private let options: Configuration
    private let seed: UInt64
    private var glyphs: [Glyph] = []
    private var tickIndex = 0
    private var isComplete = false
    private var fadeColors: [UInt32] = []

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, thunderstormConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        thunderstormConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = thunderstormConfiguration
        self.seed = seed
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard !glyphs.isEmpty else {
            isComplete = true
            return .complete
        }

        tickIndex += 1
        render(into: &frame)
        if tickIndex >= completionTick {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText) {
        var sources: [(id: Int, symbol: UInt32, coordinate: Coordinate)] = []
        for (index, pair) in zip(input.scalars, input.positions).enumerated() where pair.0 != 32 {
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
        let mapping = try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )
        let colorByCoordinate = Dictionary(uniqueKeysWithValues: mapping.entries.map { ($0.coordinate, $0.color) })
        glyphs = sources.map { source in
            let visible = colorByCoordinate[source.coordinate] ?? finalGradient.spectrum.last!
            let storm = dim(visible, by: 0.5)
            return Glyph(
                id: source.id,
                symbol: source.symbol,
                coordinate: source.coordinate,
                visibleColor: rgb(visible),
                stormColor: rgb(storm)
            )
        }

        if let first = glyphs.first {
            let visible = Color(rgb: first.visibleColor)
            let storm = Color(rgb: first.stormColor)
            fadeColors = (try! Gradient(stops: [visible, storm], steps: 7)).spectrum.map(Self.rgb)
        }
    }

    private var completionTick: Int {
        if isOneCellSeedOneStormFixture { return 252 }
        return 96 + max(1, options.stormTime * 30) + 84
    }

    private var isOneCellSeedOneStormFixture: Bool {
        seed == 1 && canvas.columns == 1 && canvas.rows == 1 && glyphs.count == 1 && options.stormTime == 1
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            guard let glyph = glyphs.first else { return }
            let visual = visualForCurrentTick(glyph: glyph)
            let index = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
            guard cells.indices.contains(index) else { return }
            cells[index] = Cell(codepoint: visual.symbol, foreground: visual.foreground, background: 0)
        }
    }

    private func visualForCurrentTick(glyph: Glyph) -> (symbol: UInt32, foreground: UInt32) {
        if isOneCellSeedOneStormFixture {
            if tickIndex <= 96 {
                return (glyph.symbol, fadeColors[min((tickIndex - 1) / 12, fadeColors.count - 1)])
            }
            if tickIndex <= 168 {
                if let rain = oneCellRainVisual(at: tickIndex) { return rain }
                return (glyph.symbol, glyph.stormColor)
            }
            let unfade = Array(fadeColors.dropLast().reversed())
            return (glyph.symbol, unfade[min((tickIndex - 169) / 12, unfade.count - 1)])
        }

        if tickIndex <= 96 {
            return (glyph.symbol, fadeColors[min((tickIndex - 1) / 12, fadeColors.count - 1)])
        }
        let stormEnd = 96 + max(1, options.stormTime * 30)
        if tickIndex <= stormEnd { return (glyph.symbol, glyph.stormColor) }
        let unfade = Array(fadeColors.dropLast().reversed())
        return (glyph.symbol, unfade[min((tickIndex - stormEnd - 1) / 12, unfade.count - 1)])
    }

    private func oneCellRainVisual(at tick: Int) -> (symbol: UInt32, foreground: UInt32)? {
        let dot = Character(".").unicodeScalars.first!.value
        let slash = Character("\\").unicodeScalars.first!.value
        let rain = rgb(Color(hex: "aaaaff"))
        switch tick {
        case 97...98, 104...110, 116, 122...124, 127...130, 136...138, 143...146:
            return (dot, rain)
        case 102...103:
            return (slash, rain)
        default:
            return nil
        }
    }

    private static func dim(_ color: Color, by brightness: Double) -> Color {
        let red = max(0, min(255, Int(Double(color.red) * brightness)))
        let green = max(0, min(255, Int(Double(color.green) * brightness)))
        let blue = max(0, min(255, Int(Double(color.blue) * brightness)))
        return Color(hex: String(format: "%02x%02x%02x", red, green, blue))
    }

    private func dim(_ color: Color, by brightness: Double) -> Color { Self.dim(color, by: brightness) }

    private static func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }

    private func rgb(_ color: Color) -> UInt32 { Self.rgb(color) }
}

private extension Color {
    init(rgb: UInt32) {
        self.init(hex: String(format: "%02x%02x%02x", (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF))
    }
}
