import Foundation
import TTFXCore

public struct SpotlightsEffect: Effect {
    public struct Configuration: Sendable {
        public var beamWidthRatio: Double
        public var beamFalloff: Double
        public var searchDuration: Int
        public var searchSpeedRange: ClosedRange<Double>
        public var spotlightCount: Int
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            beamWidthRatio: Double = 2.0,
            beamFalloff: Double = 0.3,
            searchDuration: Int = 550,
            searchSpeedRange: ClosedRange<Double> = 0.35...0.75,
            spotlightCount: Int = 3,
            finalGradientStops: [Color] = [Color(hex: "ab48ff"), Color(hex: "e7b2b2"), Color(hex: "fffebd")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(beamWidthRatio > 0, "beam width ratio must be positive")
            precondition(beamFalloff >= 0, "beam falloff must be non-negative")
            precondition(searchDuration > 0, "search duration must be positive")
            precondition(searchSpeedRange.lowerBound > 0 && searchSpeedRange.upperBound > 0, "search speed must be positive")
            precondition(spotlightCount > 0, "spotlight count must be positive")
            precondition(!finalGradientStops.isEmpty, "final gradient stops must not be empty")
            self.beamWidthRatio = beamWidthRatio
            self.beamFalloff = beamFalloff
            self.searchDuration = searchDuration
            self.searchSpeedRange = searchSpeedRange
            self.spotlightCount = spotlightCount
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Glyph {
        let characterID: Int
        let symbol: UInt32
        let coordinate: Coordinate
        let brightForeground: UInt32
        let darkForeground: UInt32
        var foreground: UInt32
    }

    private struct Spotlight {
        var coordinate: Coordinate
        let center: Coordinate
    }

    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var spotlights: [Spotlight] = []
    private var illuminateRange = 1
    private var emittedFrames = 0
    private var searchTicksRemaining = 0
    private var searching = true
    private var expanding = false
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, spotlightsConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        spotlightsConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = spotlightsConfiguration
        self.rng = Xoshiro256PlusPlus(seed: seed)
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard !glyphs.isEmpty else {
            isComplete = true
            return .complete
        }

        if emittedFrames <= options.searchDuration {
            darkenGlyphs()
        } else {
            expanding = true
            illuminateGlyphs()
        }
        render(into: &frame)
        emittedFrames += 1

        let limit = floor(Double(max(canvas.columns, canvas.rows)) / 1.5)
        if emittedFrames > options.searchDuration + 1 && Double(illuminateRange) > limit {
            isComplete = true
        } else if expanding {
            illuminateRange += 1
        }

        return isComplete ? .complete : .running
    }

    private mutating func build(input: InputText) {
        var sources: [(characterID: Int, symbol: UInt32, coordinate: Coordinate)] = []
        for (index, pair) in zip(input.scalars, input.positions).enumerated() {
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
        let finalColors = Dictionary(uniqueKeysWithValues: mapping.entries.map { ($0.coordinate, $0.color) })

        glyphs = sources.sorted {
            if $0.coordinate.row != $1.coordinate.row { return $0.coordinate.row > $1.coordinate.row }
            if $0.coordinate.column != $1.coordinate.column { return $0.coordinate.column < $1.coordinate.column }
            return $0.characterID < $1.characterID
        }.map { source in
            let bright = finalColors[source.coordinate] ?? finalGradient.spectrum.last!
            let dark = adjustBrightness(bright, factor: 0.2)
            return Glyph(
                characterID: source.characterID,
                symbol: source.symbol,
                coordinate: source.coordinate,
                brightForeground: rgb(bright),
                darkForeground: rgb(dark),
                foreground: rgb(dark)
            )
        }

        let center = Coordinate(column: (canvas.columns + 1) / 2, row: (canvas.rows + 1) / 2)
        spotlights = (0..<options.spotlightCount).map { _ in
            Spotlight(coordinate: randomCanvasCoordinate(), center: center)
        }
        let smallestDimension = min(canvas.columns, canvas.rows)
        illuminateRange = max(Int(floor(Double(smallestDimension) / options.beamWidthRatio)), 1)
        emittedFrames = 0
        searchTicksRemaining = options.searchDuration
        searching = true
        expanding = false
    }

    private mutating func darkenGlyphs() {
        for index in glyphs.indices { glyphs[index].foreground = glyphs[index].darkForeground }
    }

    private mutating func illuminateGlyphs() {
        for index in glyphs.indices {
            let distance = spotlights.map { Geometry.lineLength(from: $0.coordinate, to: glyphs[index].coordinate) }.min() ?? .infinity
            if expanding || distance <= Double(illuminateRange) {
                glyphs[index].foreground = foreground(for: glyphs[index], distance: distance)
            } else {
                glyphs[index].foreground = glyphs[index].darkForeground
            }
        }
    }

    private func foreground(for glyph: Glyph, distance: Double) -> UInt32 {
        guard options.beamFalloff > 0 else { return glyph.brightForeground }
        let range = Double(illuminateRange)
        if !expanding && distance > range * (1.0 - options.beamFalloff) {
            let factor = max(0.2, 1.0 - (distance - range * (1.0 - options.beamFalloff)) / (range * options.beamFalloff))
            return rgb(adjustBrightness(color(fromRGB: glyph.brightForeground), factor: factor))
        }
        return glyph.brightForeground
    }

    private mutating func randomCanvasCoordinate() -> Coordinate {
        Coordinate(column: rng.integer(in: 1...canvas.columns), row: rng.integer(in: 1...canvas.rows))
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            for glyph in glyphs.sorted(by: { $0.characterID < $1.characterID }) {
                guard (1...canvas.columns).contains(glyph.coordinate.column),
                      (1...canvas.rows).contains(glyph.coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
                cells[cellIndex] = Cell(codepoint: glyph.symbol, foreground: glyph.foreground, background: 0)
            }
        }
    }

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }

    private func color(fromRGB word: UInt32) -> Color {
        Color(hex: String(format: "%02x%02x%02x", (word >> 16) & 0xff, (word >> 8) & 0xff, word & 0xff))
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
