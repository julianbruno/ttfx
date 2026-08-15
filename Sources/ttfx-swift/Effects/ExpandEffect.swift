import TTFXCore

public struct ExpandEffect: Effect {
    public struct Configuration: Sendable {
        public var movementEasing: Easing
        public var movementSpeed: Double
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            movementEasing: Easing = .inOutQuart,
            movementSpeed: Double = 0.35,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(movementSpeed > 0, "movement speed must be positive")
            self.movementEasing = movementEasing
            self.movementSpeed = movementSpeed
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Glyph {
        let target: Coordinate
        let symbol: UInt32
        let colors: [UInt32]
        let totalDistance: Double
        let maxSteps: Int
        var coordinate: Coordinate
        var currentStep = 0
        var lastDistance = 0.0
        var pathActive = true

        // QUIRK(src/effects/expand.rs:124-142): path activation raises the layer to 1,
        // then path completion restores layer 0 while the distance-synced scene remains active.
        var layer: Int { pathActive ? 1 : 0 }

        var foreground: UInt32 {
            guard pathActive else { return colors[colors.count - 1] }
            let total = max(totalDistance, 1)
            let remaining = max(totalDistance - lastDistance, 1)
            let reached = max(total - remaining, 1)
            let progress = reached / total
            let index = min(max(PyCompat.roundHalfEven(Double(colors.count - 1) * progress), 0), colors.count - 1)
            return colors[index]
        }
    }

    private let canvas: Canvas
    private let options: Configuration
    private var glyphs: [Glyph] = []
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, expandConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        expandConfiguration: Configuration
    ) {
        self.canvas = canvas
        options = expandConfiguration
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }

        advancePaths()
        render(into: &frame)
        if !glyphs.contains(where: \.pathActive) {
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
        let finalColors = try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )
        let colorByCoordinate = Dictionary(uniqueKeysWithValues: finalColors.entries.map { ($0.coordinate, $0.color) })
        let center = canvasCenter()
        let startColor = finalGradient.spectrum[0]

        glyphs = zip(input.scalars, coordinates).map { symbol, target in
            let colors = try! Gradient(
                stops: [startColor, colorByCoordinate[target]!],
                steps: 10
            ).spectrum.map(rgb)
            let distance = Geometry.lineLength(from: center, to: target)
            return Glyph(
                target: target,
                symbol: symbol,
                colors: colors,
                totalDistance: distance,
                maxSteps: PyCompat.roundHalfEven(distance / options.movementSpeed),
                coordinate: center
            )
        }
    }

    private mutating func advancePaths() {
        let center = canvasCenter()
        for index in glyphs.indices where glyphs[index].pathActive {
            guard glyphs[index].maxSteps > 0 else {
                glyphs[index].coordinate = glyphs[index].target
                glyphs[index].pathActive = false
                continue
            }

            glyphs[index].currentStep += 1
            let ratio = Double(glyphs[index].currentStep) / Double(glyphs[index].maxSteps)
            let distance = options.movementEasing.value(at: ratio) * glyphs[index].totalDistance
            glyphs[index].lastDistance = distance
            glyphs[index].coordinate = Geometry.coordinateOnLine(
                from: center,
                to: glyphs[index].target,
                t: distance / glyphs[index].totalDistance
            )
            if glyphs[index].currentStep == glyphs[index].maxSteps {
                glyphs[index].pathActive = false
            }
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            var winners: [Int: (layer: Int, glyph: Glyph)] = [:]
            for glyph in glyphs {
                guard (1...canvas.columns).contains(glyph.coordinate.column),
                      (1...canvas.rows).contains(glyph.coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
                if let winner = winners[cellIndex], winner.layer > glyph.layer { continue }
                winners[cellIndex] = (glyph.layer, glyph)
            }
            for (index, winner) in winners {
                cells[index] = .init(codepoint: winner.glyph.symbol, foreground: winner.glyph.foreground, background: 0)
            }
        }
    }

    private func canvasCenter() -> Coordinate {
        Coordinate(
            column: centered(canvas.columns),
            row: centered(canvas.rows)
        )
    }

    private func centered(_ size: Int) -> Int {
        var center = max(PyCompat.floorDivide(size, 2), 1)
        if !size.isMultiple(of: 2), size > 1 { center += 1 }
        return center
    }

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
