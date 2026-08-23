import Foundation
import TTFXCore

public struct MiddleoutEffect: Effect {
    public enum ExpandDirection: Sendable {
        case vertical
        case horizontal
    }

    public struct Configuration: Sendable {
        public var startingColor: Color
        public var expandDirection: ExpandDirection
        public var centerMovementSpeed: Double
        public var fullMovementSpeed: Double
        public var centerEasing: Easing
        public var fullEasing: Easing
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            startingColor: Color = Color(hex: "ffffff"),
            expandDirection: ExpandDirection = .vertical,
            centerMovementSpeed: Double = 0.6,
            fullMovementSpeed: Double = 0.6,
            centerEasing: Easing = .inOutSine,
            fullEasing: Easing = .inOutSine,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(centerMovementSpeed > 0, "center movement speed must be positive")
            precondition(fullMovementSpeed > 0, "full movement speed must be positive")
            self.startingColor = startingColor
            self.expandDirection = expandDirection
            self.centerMovementSpeed = centerMovementSpeed
            self.fullMovementSpeed = fullMovementSpeed
            self.centerEasing = centerEasing
            self.fullEasing = fullEasing
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum Phase { case center, full, complete }

    private struct Glyph {
        let symbol: UInt32
        let target: Coordinate
        let centerTarget: Coordinate
        let finalColors: [UInt32]
        var coordinate: Coordinate
        var centerStep = 0
        var fullStep = 0
        var fullAge = 0
        let centerSteps: Int
        let fullSteps: Int
        let centerDistance: Double
        let fullDistance: Double
    }

    private let canvas: Canvas
    private let options: Configuration
    private var glyphs: [Glyph] = []
    private var phase: Phase = .center

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, middleoutConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        middleoutConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = middleoutConfiguration
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard phase != .complete else { return .complete }

        if phase == .center, centerComplete {
            phase = .full
        }

        switch phase {
        case .center:
            advanceCenter()
            render(into: &frame)
            if centerComplete, glyphs.isEmpty {
                phase = .complete
                return .complete
            }
            return .running

        case .full:
            advanceFull()
            render(into: &frame)
            if fullComplete {
                phase = .complete
                return .complete
            }
            return .running

        case .complete:
            return .complete
        }
    }

    private var centerComplete: Bool {
        glyphs.allSatisfy { $0.centerStep >= $0.centerSteps }
    }

    private var fullComplete: Bool {
        // Rust's gradient scene keeps its terminal visual active for one extra
        // six-frame hold after the ten interpolated colors have been emitted.
        glyphs.allSatisfy { $0.fullStep >= $0.fullSteps && $0.fullAge >= 66 }
    }

    private mutating func build(input: InputText) {
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        guard !coordinates.isEmpty,
              let bottom = coordinates.map(\.row).min(),
              let top = coordinates.map(\.row).max(),
              let left = coordinates.map(\.column).min(),
              let right = coordinates.map(\.column).max()
        else {
            phase = .complete
            return
        }

        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let finalMapping = Dictionary(uniqueKeysWithValues: (try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )).entries.map { ($0.coordinate, rgb($0.color)) })
        let center = canvasCenter()
        glyphs = zip(input.scalars, coordinates).map { symbol, target in
            let centerTarget: Coordinate
            switch options.expandDirection {
            case .vertical:
                centerTarget = Coordinate(column: target.column, row: center.row)
            case .horizontal:
                centerTarget = Coordinate(column: center.column, row: target.row)
            }
            let finalColor = finalMapping[target] ?? rgb(options.finalGradientStops.last ?? options.startingColor)
            let colors = (try! Gradient(stops: [options.startingColor, Color(rgb: finalColor)], steps: 10)).spectrum.map(rgb) + [finalColor]
            let centerDistance = Geometry.lineLength(from: center, to: centerTarget)
            let fullDistance = Geometry.lineLength(from: centerTarget, to: target)
            return Glyph(
                symbol: symbol,
                target: target,
                centerTarget: centerTarget,
                finalColors: colors,
                coordinate: center,
                centerSteps: PyCompat.roundHalfEven(centerDistance / options.centerMovementSpeed),
                fullSteps: PyCompat.roundHalfEven(fullDistance / options.fullMovementSpeed),
                centerDistance: centerDistance,
                fullDistance: fullDistance
            )
        }
    }

    private mutating func advanceCenter() {
        let center = canvasCenter()
        for index in glyphs.indices where glyphs[index].centerStep < glyphs[index].centerSteps {
            glyphs[index].centerStep += 1
            let progress = Double(glyphs[index].centerStep) / Double(max(glyphs[index].centerSteps, 1))
            let eased = options.centerEasing.value(at: progress)
            glyphs[index].coordinate = Geometry.coordinateOnLine(from: center, to: glyphs[index].centerTarget, t: eased)
        }
        for index in glyphs.indices where glyphs[index].centerSteps == 0 {
            glyphs[index].coordinate = glyphs[index].centerTarget
        }
    }

    private mutating func advanceFull() {
        for index in glyphs.indices {
            if glyphs[index].fullStep < glyphs[index].fullSteps {
                glyphs[index].fullStep += 1
                let progress = Double(glyphs[index].fullStep) / Double(max(glyphs[index].fullSteps, 1))
                let eased = options.fullEasing.value(at: progress)
                glyphs[index].coordinate = Geometry.coordinateOnLine(from: glyphs[index].centerTarget, to: glyphs[index].target, t: eased)
            } else if glyphs[index].fullSteps == 0 {
                glyphs[index].coordinate = glyphs[index].target
            }
            if glyphs[index].fullAge < 66 {
                glyphs[index].fullAge += 1
            }
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            var winners: [Int: Glyph] = [:]
            for glyph in glyphs {
                guard (1...canvas.columns).contains(glyph.coordinate.column),
                      (1...canvas.rows).contains(glyph.coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
                winners[cellIndex] = glyph
            }
            for (index, glyph) in winners {
                cells[index] = Cell(codepoint: glyph.symbol, foreground: foreground(for: glyph), background: 0)
            }
        }
    }

    private func foreground(for glyph: Glyph) -> UInt32 {
        guard phase == .full else { return rgb(options.startingColor) }
        let colorIndex = min(max((max(glyph.fullAge, 1) - 1) / 6, 0), glyph.finalColors.count - 1)
        return glyph.finalColors[colorIndex]
    }

    private func canvasCenter() -> Coordinate {
        Coordinate(column: centered(canvas.columns), row: centered(canvas.rows))
    }

    private func centered(_ size: Int) -> Int {
        var center = max(PyCompat.floorDivide(size, 2), 1)
        if !size.isMultiple(of: 2), size > 1 { center += 1 }
        return center
    }
}

private func rgb(_ color: Color) -> UInt32 {
    (UInt32(color.red) << 16) | (UInt32(color.green) << 8) | UInt32(color.blue)
}

private extension Color {
    init(rgb: UInt32) {
        self.init(hex: String(format: "%06x", rgb & 0xFF_FFFF))
    }
}
