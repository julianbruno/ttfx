import TTFXCore

public struct OrbittingVolleyEffect: Effect {
    public struct Configuration: Sendable {
        public var topLauncherSymbol: String
        public var rightLauncherSymbol: String
        public var bottomLauncherSymbol: String
        public var leftLauncherSymbol: String
        public var launcherMovementSpeed: Double
        public var characterMovementSpeed: Double
        public var volleySize: Double
        public var launchDelay: Int
        public var characterEasing: Easing
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            topLauncherSymbol: String = "█",
            rightLauncherSymbol: String = "█",
            bottomLauncherSymbol: String = "█",
            leftLauncherSymbol: String = "█",
            launcherMovementSpeed: Double = 0.8,
            characterMovementSpeed: Double = 1.5,
            volleySize: Double = 0.03,
            launchDelay: Int = 30,
            characterEasing: Easing = .outSine,
            finalGradientStops: [Color] = [Color(hex: "FFA15C"), Color(hex: "44D492")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .radial
        ) {
            precondition(launcherMovementSpeed > 0, "launcher movement speed must be positive")
            precondition(characterMovementSpeed > 0, "character movement speed must be positive")
            precondition(volleySize >= 0, "volley size must be non-negative")
            precondition(launchDelay >= 0, "launch delay must be non-negative")
            self.topLauncherSymbol = topLauncherSymbol
            self.rightLauncherSymbol = rightLauncherSymbol
            self.bottomLauncherSymbol = bottomLauncherSymbol
            self.leftLauncherSymbol = leftLauncherSymbol
            self.launcherMovementSpeed = launcherMovementSpeed
            self.characterMovementSpeed = characterMovementSpeed
            self.volleySize = volleySize
            self.launchDelay = launchDelay
            self.characterEasing = characterEasing
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct PathState {
        let waypoints: [Coordinate]
        let speed: Double
        let easing: Easing
        let loop: Bool
        var segment = 0
        var stepInSegment = 0
        var active = true

        mutating func step() -> (Coordinate, Bool) {
            let start = waypoints[segment]
            let end = waypoints[segment + 1]
            let steps = max(1, PyCompat.roundHalfEven(Geometry.lineLength(from: start, to: end) / speed))
            stepInSegment += 1
            let progress = min(Double(stepInSegment) / Double(steps), 1)
            let coordinate = Geometry.coordinateOnLine(from: start, to: end, t: easing.value(at: progress))
            if stepInSegment == steps {
                if segment + 2 < waypoints.count {
                    segment += 1
                    stepInSegment = 0
                } else if loop {
                    active = false
                } else {
                    active = false
                }
            }
            return (coordinate, !active && !loop)
        }

        mutating func restartLoop() {
            segment = 0
            stepInSegment = 0
            active = true
        }
    }

    private struct Glyph {
        let id: Int
        let symbol: UInt32
        let target: Coordinate
        let finalForeground: UInt32
        var coordinate: Coordinate
        var visible = false
        var layer = 0
        var path: PathState?
    }

    private struct Launcher {
        let id: Int
        let symbol: UInt32
        let inputCoordinate: Coordinate
        var coordinate: Coordinate
        var foreground: UInt32
        var magazine: [Int] = []
        var path: PathState?
        var visible = true
    }

    private let canvas: Canvas
    private let options: Configuration
    private var glyphs: [Glyph] = []
    private var launchers: [Launcher] = []
    private var launcherColorByCoordinate: [Coordinate: UInt32] = [:]
    private var delay = 0
    private var emittedSettledFrame = false
    private var emittedFinalFrame = false
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, orbittingVolleyConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        orbittingVolleyConfiguration: Configuration
    ) {
        self.canvas = canvas
        options = orbittingVolleyConfiguration
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        if hasWorkRemaining {
            restartMainLauncherIfNeeded()
            updateLauncherAppearances()
            launchVolleyIfDue()
            stepActivePaths()
            render(into: &frame)
            return .running
        }
        if !emittedSettledFrame && delay > 0 {
            emittedSettledFrame = true
            restartMainLauncherIfNeeded()
            updateLauncherAppearances()
            if launchers[0].path?.active == true {
                let (coordinate, _) = launchers[0].path!.step()
                launchers[0].coordinate = coordinate
            }
            render(into: &frame)
            return .running
        }
        if !emittedFinalFrame {
            emittedFinalFrame = true
            for index in launchers.indices { launchers[index].visible = false }
            render(into: &frame)
            isComplete = true
            return .complete
        }
        return .complete
    }

    private var hasWorkRemaining: Bool {
        // QUIRK(src/effects/orbittingvolley.rs:315-342): completion is gated by
        // magazines and launched input characters; a still-orbiting launcher alone
        // does not keep the effect running.
        launchers.contains { !$0.magazine.isEmpty } || glyphs.contains { $0.visible && $0.path != nil && $0.coordinate != $0.target }
    }

    private mutating func build(input: InputText) {
        guard !input.scalars.isEmpty else {
            isComplete = true
            return
        }
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let textBottom = coordinates.map(\.row).min()!
        let textTop = coordinates.map(\.row).max()!
        let textLeft = coordinates.map(\.column).min()!
        let textRight = coordinates.map(\.column).max()!
        let textCenter = Coordinate(
            column: textLeft + PyCompat.floorDivide(textRight - textLeft, 2),
            row: textBottom + PyCompat.floorDivide(textTop - textBottom, 2)
        )
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let finalMap = Dictionary(uniqueKeysWithValues: (try! finalGradient.coordinateColorMapping(
            minRow: textBottom,
            maxRow: textTop,
            minColumn: textLeft,
            maxColumn: textRight,
            direction: options.finalGradientDirection
        )).entries.map { ($0.coordinate, rgb($0.color)) })
        launcherColorByCoordinate = Dictionary(uniqueKeysWithValues: (try! finalGradient.coordinateColorMapping(
            minRow: 1,
            maxRow: canvas.rows,
            minColumn: 1,
            maxColumn: canvas.columns,
            direction: options.finalGradientDirection
        )).entries.map { ($0.coordinate, rgb($0.color)) })

        glyphs = input.scalars.enumerated().map { index, scalar in
            let target = coordinates[index]
            return Glyph(id: index, symbol: scalar, target: target, finalForeground: finalMap[target]!, coordinate: target)
        }

        let launcherSymbols = [
            options.topLauncherSymbol,
            options.rightLauncherSymbol,
            options.bottomLauncherSymbol,
            options.leftLauncherSymbol
        ].map { $0.unicodeScalars.first?.value ?? Cell.blank.codepoint }
        let launcherCoordinates = [
            Coordinate(column: 1, row: canvas.rows),
            Coordinate(column: canvas.columns, row: canvas.rows),
            Coordinate(column: canvas.columns, row: 1),
            Coordinate(column: 1, row: 1)
        ]
        launchers = launcherCoordinates.enumerated().map { index, coordinate in
            Launcher(
                id: glyphs.count + index,
                symbol: launcherSymbols[index],
                inputCoordinate: coordinate,
                coordinate: coordinate,
                foreground: index == 0 ? rgb(finalGradient.spectrum.last!) : launcherColorByCoordinate[coordinate]!
            )
        }
        launchers[0].path = PathState(
            waypoints: [Coordinate(column: 1, row: canvas.rows), Coordinate(column: canvas.columns, row: canvas.rows)],
            speed: options.launcherMovementSpeed,
            easing: .linear,
            loop: true
        )

        let sorted = glyphs.indices.sorted { lhs, rhs in
            let left = glyphs[lhs].target
            let right = glyphs[rhs].target
            let leftDistance = abs(left.column - textCenter.column) + abs(left.row - textCenter.row)
            let rightDistance = abs(right.column - textCenter.column) + abs(right.row - textCenter.row)
            if leftDistance != rightDistance { return leftDistance < rightDistance }
            if left.row != right.row { return left.row < right.row }
            return left.column < right.column
        }
        for (offset, glyphIndex) in sorted.enumerated() {
            launchers[offset % launchers.count].magazine.append(glyphIndex)
        }
    }

    private mutating func restartMainLauncherIfNeeded() {
        guard launchers[0].path?.active != true else { return }
        launchers[0].coordinate = Coordinate(column: 1, row: canvas.rows)
        launchers[0].path?.restartLoop()
    }

    private mutating func updateLauncherAppearances() {
        launchers[0].foreground = launcherColorByCoordinate[launchers[0].coordinate]!
        let progress = Double(launchers[0].coordinate.column) / Double(canvas.columns)
        for index in 1..<launchers.count {
            switch launchers[index].inputCoordinate {
            case Coordinate(column: canvas.columns, row: canvas.rows):
                let row = canvas.rows - Int(Double(canvas.rows) * progress)
                launchers[index].coordinate = Coordinate(column: canvas.columns, row: max(1, row))
            case Coordinate(column: canvas.columns, row: 1):
                let column = canvas.columns - Int(Double(canvas.columns) * progress)
                launchers[index].coordinate = Coordinate(column: max(1, column), row: 1)
            case Coordinate(column: 1, row: 1):
                let row = 1 + Int(Double(canvas.rows) * progress)
                launchers[index].coordinate = Coordinate(column: 1, row: min(canvas.rows, row))
            default:
                break
            }
            launchers[index].foreground = launcherColorByCoordinate[launchers[index].coordinate]!
        }
    }

    private mutating func launchVolleyIfDue() {
        if delay == 0 {
            let charactersToLaunch = max(Int((options.volleySize * Double(glyphs.count)) / 4.0), 1)
            for launcherIndex in launchers.indices {
                for _ in 0..<charactersToLaunch {
                    guard !launchers[launcherIndex].magazine.isEmpty else { break }
                    let glyphIndex = launchers[launcherIndex].magazine.removeFirst()
                    glyphs[glyphIndex].coordinate = launchers[launcherIndex].coordinate
                    glyphs[glyphIndex].visible = true
                    glyphs[glyphIndex].layer = 1
                    glyphs[glyphIndex].path = PathState(
                        waypoints: [launchers[launcherIndex].coordinate, glyphs[glyphIndex].target],
                        speed: options.characterMovementSpeed,
                        easing: options.characterEasing,
                        loop: false
                    )
                }
            }
            delay = options.launchDelay
        } else {
            delay -= 1
        }
    }

    private mutating func stepActivePaths() {
        if launchers[0].path?.active == true {
            let (coordinate, _) = launchers[0].path!.step()
            launchers[0].coordinate = coordinate
        }
        for index in glyphs.indices where glyphs[index].path != nil {
            let (coordinate, complete) = glyphs[index].path!.step()
            glyphs[index].coordinate = coordinate
            if complete {
                glyphs[index].path = nil
                glyphs[index].layer = 0
                glyphs[index].coordinate = glyphs[index].target
            }
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            var winners: [Int: (layer: Int, id: Int, cell: Cell)] = [:]
            func paint(id: Int, layer: Int, coordinate: Coordinate, symbol: UInt32, foreground: UInt32) {
                guard (1...canvas.columns).contains(coordinate.column), (1...canvas.rows).contains(coordinate.row) else { return }
                let cellIndex = (canvas.rows - coordinate.row) * canvas.columns + coordinate.column - 1
                if let winner = winners[cellIndex], (winner.layer, winner.id) > (layer, id) { return }
                winners[cellIndex] = (layer, id, Cell(codepoint: symbol, foreground: foreground, background: 0))
            }
            for glyph in glyphs where glyph.visible {
                paint(id: glyph.id, layer: glyph.layer, coordinate: glyph.coordinate, symbol: glyph.symbol, foreground: glyph.finalForeground)
            }
            for launcher in launchers where launcher.visible {
                paint(id: launcher.id, layer: 2, coordinate: launcher.coordinate, symbol: launcher.symbol, foreground: launcher.foreground)
            }
            for (index, winner) in winners { cells[index] = winner.cell }
        }
    }

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
