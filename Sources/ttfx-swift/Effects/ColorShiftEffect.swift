import Foundation
import TTFXCore

public struct ColorShiftEffect: Effect {
    public struct Configuration: Sendable {
        public var gradientStops: [Color]
        public var gradientSteps: [Int]
        public var gradientFrames: Int
        public var noTravel: Bool
        public var travelDirection: GradientDirection
        public var reverseTravelDirection: Bool
        public var noLoop: Bool
        public var cycles: Int
        public var skipFinalGradient: Bool
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            gradientStops: [Color] = [Color(hex: "e81416"), Color(hex: "ffa500"), Color(hex: "faeb36"), Color(hex: "79c314"), Color(hex: "487de7"), Color(hex: "4b369d"), Color(hex: "70369d")],
            gradientSteps: [Int] = [12],
            gradientFrames: Int = 2,
            noTravel: Bool = false,
            noLoop: Bool = false,
            cycles: Int = 3,
            skipFinalGradient: Bool = false,
            finalGradientStops: [Color] = [Color(hex: "e81416"), Color(hex: "ffa500"), Color(hex: "faeb36"), Color(hex: "79c314"), Color(hex: "487de7"), Color(hex: "4b369d"), Color(hex: "70369d")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical,
            travelDirection: GradientDirection = .radial,
            reverseTravelDirection: Bool = false
        ) {
            precondition(!gradientStops.isEmpty, "gradient stops must not be empty")
            precondition(!finalGradientStops.isEmpty, "final gradient stops must not be empty")
            precondition(!gradientSteps.isEmpty && gradientSteps.allSatisfy { $0 > 0 }, "gradient steps must be positive")
            precondition(!finalGradientSteps.isEmpty && finalGradientSteps.allSatisfy { $0 > 0 }, "final gradient steps must be positive")
            precondition(gradientFrames > 0, "gradient frames must be positive")
            precondition(cycles >= 0, "cycles must not be negative")
            self.gradientStops = gradientStops
            self.gradientSteps = gradientSteps
            self.gradientFrames = gradientFrames
            self.noTravel = noTravel
            self.travelDirection = travelDirection
            self.reverseTravelDirection = reverseTravelDirection
            self.noLoop = noLoop
            self.cycles = cycles
            self.skipFinalGradient = skipFinalGradient
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum Phase { case gradient, final, done }

    private struct Glyph {
        let coordinate: Coordinate
        let symbol: UInt32
        let gradientColors: [UInt32]
        let finalColors: [UInt32]
        var phase: Phase = .gradient
        var frameIndex = 0
        var ticksRemaining: Int
        var completedGradientLoops = 0
        var displayedForeground: UInt32?

        var active: Bool { phase != .done }

        var foreground: UInt32 {
            switch phase {
            case .gradient:
                gradientColors[frameIndex]
            case .final:
                finalColors[frameIndex]
            case .done:
                finalColors.last ?? gradientColors.last ?? 0
            }
        }
    }

    private let canvas: Canvas
    private let options: Configuration
    private var glyphs: [Glyph] = []
    private var complete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, colorShiftConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        colorShiftConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = colorShiftConfiguration
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !complete else { return .complete }
        guard glyphs.contains(where: \.active) else {
            complete = true
            return .complete
        }

        advanceScenes()
        render(into: &frame)

        if !glyphs.contains(where: \.active) {
            complete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText) {
        let sources = zip(input.scalars, input.positions).map { scalar, position in
            (symbol: scalar, coordinate: Coordinate(column: position.column, row: position.row))
        }
        guard !sources.isEmpty else {
            complete = true
            return
        }
        let coordinates = sources.map(\.coordinate)
        let bottom = coordinates.map(\.row).min()!
        let top = coordinates.map(\.row).max()!
        let left = coordinates.map(\.column).min()!
        let right = coordinates.map(\.column).max()!

        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let finalMapping = Dictionary(uniqueKeysWithValues: (try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )).entries.map { ($0.coordinate, $0.color) })

        let gradient = try! Gradient(stops: options.gradientStops, steps: options.gradientSteps, loop: !options.noLoop)
        glyphs = sources.map { source in
            let colors = shiftedColors(for: source.coordinate, spectrum: gradient.spectrum, textBounds: (bottom, top, left, right))
            let last = colors.last!
            let target = finalMapping[source.coordinate]!
            let finalScene = try! Gradient(stops: [last, target], steps: 8)
            return Glyph(
                coordinate: source.coordinate,
                symbol: source.symbol,
                gradientColors: colors.map(rgb),
                finalColors: finalScene.spectrum.map(rgb),
                ticksRemaining: options.gradientFrames
            )
        }
    }

    private func shiftedColors(for coordinate: Coordinate, spectrum: [Color], textBounds: (bottom: Int, top: Int, left: Int, right: Int)) -> [Color] {
        guard !options.noTravel, !spectrum.isEmpty else { return spectrum }
        let directionIndex: Double
        switch options.travelDirection {
        case .horizontal:
            directionIndex = Double(coordinate.column) / Double(canvas.columns)
        case .vertical:
            directionIndex = Double(coordinate.row) / Double(canvas.rows)
        case .diagonal:
            directionIndex = Double(coordinate.row + coordinate.column) / Double(canvas.columns + canvas.rows)
        case .radial:
            directionIndex = (try? Geometry.normalizedDistanceFromCenter(
                bottom: textBounds.bottom,
                top: textBounds.top,
                left: textBounds.left,
                right: textBounds.right,
                coordinate: coordinate
            )) ?? 0
        }
        var shiftDistance = Int(Double(spectrum.count) * directionIndex)
        if options.reverseTravelDirection { shiftDistance *= -1 }
        let count = spectrum.count
        let split: Int
        if shiftDistance < 0 {
            split = max(count + shiftDistance, 0)
        } else {
            split = min(shiftDistance, count)
        }
        return Array(spectrum[split...]) + Array(spectrum[..<split])
    }

    private mutating func advanceScenes() {
        for index in glyphs.indices where glyphs[index].active {
            glyphs[index].displayedForeground = glyphs[index].foreground
            glyphs[index].ticksRemaining -= 1
            guard glyphs[index].ticksRemaining == 0 else { continue }
            switch glyphs[index].phase {
            case .gradient:
                if glyphs[index].frameIndex + 1 < glyphs[index].gradientColors.count {
                    glyphs[index].frameIndex += 1
                    glyphs[index].ticksRemaining = options.gradientFrames
                } else {
                    glyphs[index].completedGradientLoops += 1
                    if options.cycles == 0 || glyphs[index].completedGradientLoops < options.cycles {
                        glyphs[index].frameIndex = 0
                        glyphs[index].ticksRemaining = options.gradientFrames
                        glyphs[index].displayedForeground = glyphs[index].foreground
                    } else if options.skipFinalGradient {
                        glyphs[index].phase = .done
                    } else {
                        glyphs[index].phase = .final
                        glyphs[index].frameIndex = 0
                        glyphs[index].ticksRemaining = options.gradientFrames
                        glyphs[index].displayedForeground = glyphs[index].foreground
                    }
                }
            case .final:
                if glyphs[index].frameIndex + 1 < glyphs[index].finalColors.count {
                    glyphs[index].frameIndex += 1
                    glyphs[index].ticksRemaining = options.gradientFrames
                } else {
                    glyphs[index].phase = .done
                }
            case .done:
                break
            }
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
        }
        for glyph in glyphs {
            guard (1...canvas.columns).contains(glyph.coordinate.column),
                  (1...canvas.rows).contains(glyph.coordinate.row)
            else { continue }
            frame[column: glyph.coordinate.column, row: glyph.coordinate.row] = Cell(
                codepoint: glyph.symbol,
                foreground: glyph.displayedForeground ?? glyph.foreground,
                background: 0
            )
        }
    }

    private func rgb(_ color: Color) -> UInt32 {
        (UInt32(color.red) << 16) | (UInt32(color.green) << 8) | UInt32(color.blue)
    }
}
