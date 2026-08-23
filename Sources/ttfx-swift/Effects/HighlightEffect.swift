import Foundation
import TTFXCore

public struct HighlightEffect: Effect {
    public enum Direction: Sendable {
        case diagonalTopLeftToBottomRight
        case diagonalBottomRightToTopLeft
        case diagonalBottomLeftToTopRight
        case diagonalTopRightToBottomLeft
        case rowBottomToTop
        case rowTopToBottom
        case columnLeftToRight
        case columnRightToLeft
        case centerToOutside
        case outsideToCenter
    }

    public struct Configuration: Sendable {
        public var highlightBrightness: Double
        public var highlightDirection: Direction
        public var highlightWidth: Int
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            highlightBrightness: Double = 1.75,
            highlightDirection: Direction = .diagonalBottomLeftToTopRight,
            highlightWidth: Int = 8,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(highlightBrightness > 0, "highlight brightness must be positive")
            precondition(highlightWidth >= 1, "highlight width must be at least one")
            self.highlightBrightness = highlightBrightness
            self.highlightDirection = highlightDirection
            self.highlightWidth = highlightWidth
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Glyph {
        let coordinate: Coordinate
        let symbol: UInt32
        let colors: [UInt32]
        var visible = true
        var sceneIndex = 0
        var sceneTicksRemaining = 2
        var sceneActive = false

        var foreground: UInt32 { colors[sceneIndex] }
    }

    private let canvas: Canvas
    private let options: Configuration
    private var glyphs: [Glyph] = []
    private var groups: [[Int]] = []
    private var easingStep = 0
    private var previousLength = 0
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, highlightConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        highlightConfiguration: Configuration
    ) {
        self.canvas = canvas
        options = highlightConfiguration
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }

        advanceEaser()
        render(into: &frame)
        advanceScenes()

        if easingStep >= Self.easingSteps && !glyphs.contains(where: \.sceneActive) {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText) {
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        guard let bottom = coordinates.map(\.row).min(),
              let top = coordinates.map(\.row).max(),
              let left = coordinates.map(\.column).min(),
              let right = coordinates.map(\.column).max()
        else {
            isComplete = true
            return
        }

        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )).entries.map { ($0.coordinate, $0.color) })

        for (position, symbol) in zip(input.positions, input.scalars) {
            let coordinate = Coordinate(column: position.column, row: position.row)
            let base = mapping[coordinate]!
            let bright = adjustBrightness(base, factor: options.highlightBrightness)
            let gradient = try! Gradient(
                stops: [base, bright, bright, base],
                steps: [3, options.highlightWidth, 3]
            )
            glyphs.append(.init(
                coordinate: coordinate,
                symbol: symbol,
                colors: gradient.spectrum.map(rgb)
            ))
        }
        groups = groupedGlyphs()
    }

    private mutating func advanceEaser() {
        guard easingStep < Self.easingSteps else { return }
        easingStep += 1
        let progress = Double(easingStep) / Double(Self.easingSteps)
        let eased = min(max(Easing.inOutCirc.value(at: progress), 0), 1)
        let length = Int(eased * Double(groups.count))
        guard length > previousLength else { return }
        for group in groups[previousLength..<length] {
            for index in group { activate(index) }
        }
        previousLength = length
    }

    private mutating func activate(_ index: Int) {
        glyphs[index].visible = true
        glyphs[index].sceneIndex = 0
        glyphs[index].sceneTicksRemaining = 2
        glyphs[index].sceneActive = true
    }

    private mutating func advanceScenes() {
        for index in glyphs.indices where glyphs[index].sceneActive {
            glyphs[index].sceneTicksRemaining -= 1
            guard glyphs[index].sceneTicksRemaining == 0 else { continue }
            if glyphs[index].sceneIndex + 1 < glyphs[index].colors.count {
                glyphs[index].sceneIndex += 1
                glyphs[index].sceneTicksRemaining = 2
            } else {
                glyphs[index].sceneActive = false
            }
        }
    }

    private func groupedGlyphs() -> [[Int]] {
        let ordered = glyphs.indices.sorted {
            let lhs = glyphs[$0].coordinate
            let rhs = glyphs[$1].coordinate
            return (lhs.row, lhs.column) < (rhs.row, rhs.column)
        }
        let key: (Glyph) -> Int
        let reverse: Bool
        switch options.highlightDirection {
        case .diagonalTopLeftToBottomRight:
            key = { $0.coordinate.column - $0.coordinate.row }
            reverse = false
        case .diagonalBottomRightToTopLeft:
            key = { $0.coordinate.column - $0.coordinate.row }
            reverse = true
        case .diagonalBottomLeftToTopRight:
            key = { $0.coordinate.column + $0.coordinate.row }
            reverse = false
        case .diagonalTopRightToBottomLeft:
            key = { $0.coordinate.column + $0.coordinate.row }
            reverse = true
        case .rowBottomToTop:
            key = { $0.coordinate.row }
            reverse = false
        case .rowTopToBottom:
            key = { $0.coordinate.row }
            reverse = true
        case .columnLeftToRight:
            key = { $0.coordinate.column }
            reverse = false
        case .columnRightToLeft:
            key = { $0.coordinate.column }
            reverse = true
        case .centerToOutside, .outsideToCenter:
            let columns = glyphs.map(\.coordinate.column)
            let rows = glyphs.map(\.coordinate.row)
            let center = Coordinate(
                column: columns.min()! + (columns.max()! - columns.min()!) / 2,
                row: rows.min()! + (rows.max()! - rows.min()!) / 2
            )
            key = { abs($0.coordinate.column - center.column) + abs($0.coordinate.row - center.row) }
            reverse = options.highlightDirection == .outsideToCenter
        }
        var buckets: [Int: [Int]] = [:]
        for index in ordered { buckets[key(glyphs[index]), default: []].append(index) }
        var result = buckets.keys.sorted().compactMap { buckets[$0] }
        if reverse { result.reverse() }
        return result
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            for glyph in glyphs where glyph.visible {
                guard (1...canvas.columns).contains(glyph.coordinate.column),
                      (1...canvas.rows).contains(glyph.coordinate.row)
                else { continue }
                let index = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
                cells[index] = .init(codepoint: glyph.symbol, foreground: glyph.foreground, background: 0)
            }
        }
    }

    private static let easingSteps = 100

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }

    private func adjustBrightness(_ color: Color, factor: Double) -> Color {
        let red = Double(color.red) / 255.0
        let green = Double(color.green) / 255.0
        let blue = Double(color.blue) / 255.0
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        var lightness = (maxValue + minValue) / 2.0
        let threshold = 0.5
        let hue: Double
        let saturation: Double
        if maxValue == minValue {
            hue = 0
            saturation = 0
        } else {
            let diff = maxValue - minValue
            saturation = lightness > threshold ? diff / (2.0 - maxValue - minValue) : diff / (maxValue + minValue)
            var rawHue: Double
            if maxValue == red {
                rawHue = (green - blue) / diff + (green < blue ? 6.0 : 0.0)
            } else if maxValue == green {
                rawHue = (blue - red) / diff + 2.0
            } else {
                rawHue = (red - green) / diff + 4.0
            }
            hue = rawHue / 6.0
        }

        lightness = min(max(lightness * factor, 0), 1)
        let adjusted: (Double, Double, Double)
        if saturation == 0 {
            adjusted = (lightness, lightness, lightness)
        } else {
            let intensity = lightness < threshold
                ? lightness * (1.0 + saturation)
                : lightness + saturation - lightness * saturation
            let scaled = 2.0 * lightness - intensity
            adjusted = (
                hueToRGB(scaled: scaled, intensity: intensity, hue: hue + 1.0 / 3.0),
                hueToRGB(scaled: scaled, intensity: intensity, hue: hue),
                hueToRGB(scaled: scaled, intensity: intensity, hue: hue - 1.0 / 3.0)
            )
        }
        let adjustedRed = min(max(PyCompat.roundHalfEven(adjusted.0 * 255.0), 0), 255)
        let adjustedGreen = min(max(PyCompat.roundHalfEven(adjusted.1 * 255.0), 0), 255)
        let adjustedBlue = min(max(PyCompat.roundHalfEven(adjusted.2 * 255.0), 0), 255)
        return Color(hex: String(format: "%02x%02x%02x", adjustedRed, adjustedGreen, adjustedBlue))
    }

    private func hueToRGB(scaled: Double, intensity: Double, hue originalHue: Double) -> Double {
        var hue = originalHue
        if hue < 0 { hue += 1 }
        if hue > 1 { hue -= 1 }
        if hue < 1.0 / 6.0 { return scaled + (intensity - scaled) * 6.0 * hue }
        if hue < 1.0 / 2.0 { return intensity }
        if hue < 2.0 / 3.0 { return scaled + (intensity - scaled) * (2.0 / 3.0 - hue) * 6.0 }
        return scaled
    }
}
