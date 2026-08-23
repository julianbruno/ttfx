import TTFXCore

public struct RainEffect: Effect {
    public struct Configuration: Sendable {
        public var rainColors: [Color]
        public var movementSpeed: (Double, Double)
        public var rainSymbols: [String]
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection
        public var movementEasing: Easing

        public init(
            rainColors: [Color] = [
                Color(hex: "00315C"),
                Color(hex: "004C8F"),
                Color(hex: "0075DB"),
                Color(hex: "3F91D9"),
                Color(hex: "78B9F2"),
                Color(hex: "9AC8F5"),
                Color(hex: "B8D8F8"),
                Color(hex: "E3EFFC")
            ],
            movementSpeed: (Double, Double) = (0.33, 0.57),
            rainSymbols: [String] = ["o", ".", ",", "*", "|"],
            finalGradientStops: [Color] = [Color(hex: "488bff"), Color(hex: "b2e7de"), Color(hex: "57eaf7")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .diagonal,
            movementEasing: Easing = .inQuart
        ) {
            precondition(!rainColors.isEmpty, "rain colors must not be empty")
            precondition(movementSpeed.0 > 0 && movementSpeed.1 > 0, "movement speed must be positive")
            precondition(!rainSymbols.isEmpty, "rain symbols must not be empty")
            self.rainColors = rainColors
            self.movementSpeed = movementSpeed
            self.rainSymbols = rainSymbols
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
            self.movementEasing = movementEasing
        }
    }

    private enum ScenePhase {
        case rain
        case rainHold
        case fade(index: Int, ticksElapsed: Int)
        case done
    }

    private struct Glyph {
        let characterID: Int
        let inputCoordinate: Coordinate
        let inputSymbol: UInt32
        let rainSymbol: UInt32
        let rainColor: UInt32
        let fadeColors: [UInt32]
        let pathOrigin: Coordinate
        let totalDistance: Double
        let pathSteps: Int
        var coordinate: Coordinate
        var pathStep = 0
        var pathActive = true
        var visible = false
        var scene: ScenePhase = .rain

        var isActive: Bool {
            pathActive || {
                switch scene {
                case .rain, .fade: return true
                case .rainHold, .done: return false
                }
            }()
        }

        var visual: (symbol: UInt32, foreground: UInt32) {
            switch scene {
            case .rain, .rainHold:
                return (rainSymbol, rainColor)
            case .fade(let index, _):
                return (inputSymbol, fadeColors[index])
            case .done:
                return (inputSymbol, fadeColors[fadeColors.count - 1])
            }
        }
    }

    private static let fadeSteps = 7
    private static let fadeFrameDuration = 3

    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var groups: [[Int]] = []
    private var pending: [Int] = []
    private var active: [Int] = []
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, rainConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        rainConfiguration: Configuration
    ) {
        self.canvas = canvas
        options = rainConfiguration
        rng = Xoshiro256PlusPlus(seed: seed)
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }

        if !hasPendingWork {
            isComplete = true
            return .complete
        }

        if pending.isEmpty, !groups.isEmpty {
            pending = groups.removeFirst()
        }
        if !pending.isEmpty {
            // QUIRK(src/effects/rain.rs:224-236; plan.md): each tick draws randint(1, 2)
            // inclusive, then removes a random pending index until that budget or the
            // row group is exhausted.
            for _ in 0..<rng.integer(in: 1...2) {
                guard !pending.isEmpty else { break }
                let index = rng.integer(in: 0...pending.count - 1)
                let glyphIndex = pending.remove(at: index)
                glyphs[glyphIndex].visible = true
                active.append(glyphIndex)
            }
        }

        active.sort()
        for glyphIndex in active {
            updatePath(for: glyphIndex)
        }
        render(into: &frame)
        for glyphIndex in active {
            updateScene(for: glyphIndex)
        }
        active.removeAll { !glyphs[$0].isActive }

        if !hasPendingWork {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText) {
        var created: [(characterID: Int, symbol: UInt32, coordinate: Coordinate)] = []
        created.reserveCapacity(input.scalars.count)
        for (index, pair) in zip(input.scalars, input.positions).enumerated() {
            // QUIRK(src/engine/input.rs:147-148; plan.md): character_id is allocated for
            // every parsed scalar, including later-dropped spaces, so collision order
            // follows allocation identity rather than surviving-glyph index.
            if pair.0 != 32 {
                created.append((index, pair.0, Coordinate(column: pair.1.column, row: pair.1.row)))
            }
        }
        guard !created.isEmpty else {
            isComplete = true
            return
        }

        let coordinates = created.map(\.coordinate)
        let bottom = coordinates.map(\.row).min()!
        let top = coordinates.map(\.row).max()!
        let left = coordinates.map(\.column).min()!
        let right = coordinates.map(\.column).max()!
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )
        let finalColors = Dictionary(uniqueKeysWithValues: mapping.entries.map { ($0.coordinate, rgb($0.color)) })

        // QUIRK(src/engine/terminal.rs:389-397; src/effects/rain.rs:92-95; plan.md):
        // default sort is (-row, column); TopToBottomLeftToRight then leaves that order.
        let buildOrder = created.indices.sorted {
            let lhs = created[$0].coordinate
            let rhs = created[$1].coordinate
            if lhs.row != rhs.row { return lhs.row > rhs.row }
            return lhs.column < rhs.column
        }

        glyphs = Array(repeating: placeholderGlyph(), count: created.count)
        var pendingOrder: [Int] = []
        pendingOrder.reserveCapacity(created.count)
        for sourceIndex in buildOrder {
            let source = created[sourceIndex]
            let rainColor = options.rainColors[rng.integer(in: 0..<options.rainColors.count)]
            let rainSymbol = options.rainSymbols[rng.integer(in: 0..<options.rainSymbols.count)]
            let finalColor = color(finalColors[source.coordinate]!)
            let fadeColors = try! Gradient(stops: [rainColor, finalColor], steps: Self.fadeSteps).spectrum.map(rgb)
            let origin = Coordinate(column: source.coordinate.column, row: canvas.rows)
            let speed = rng.uniform(options.movementSpeed.0, options.movementSpeed.1)
            let distance = Geometry.lineLength(from: origin, to: source.coordinate)
            glyphs[sourceIndex] = Glyph(
                characterID: source.characterID,
                inputCoordinate: source.coordinate,
                inputSymbol: source.symbol,
                rainSymbol: rainSymbol.unicodeScalars.first!.value,
                rainColor: rgb(rainColor),
                fadeColors: fadeColors,
                pathOrigin: origin,
                totalDistance: distance,
                pathSteps: PyCompat.roundHalfEven(distance / speed),
                coordinate: origin
            )
            pendingOrder.append(sourceIndex)
        }

        // QUIRK(src/effects/rain.rs:213-217; plan.md): pending is re-sorted by input
        // row and grouped in BTreeMap order, then the build pending list is cleared.
        let sortedByRow = pendingOrder.sorted { glyphs[$0].inputCoordinate.row < glyphs[$1].inputCoordinate.row }
        var grouped: [Int: [Int]] = [:]
        var rows: [Int] = []
        for index in sortedByRow {
            let row = glyphs[index].inputCoordinate.row
            if grouped[row] == nil { rows.append(row) }
            grouped[row, default: []].append(index)
        }
        groups = rows.sorted().compactMap { grouped[$0] }
    }

    private mutating func updatePath(for index: Int) {
        guard glyphs[index].pathActive else { return }
        let glyph = glyphs[index]
        if glyph.pathSteps == 0 || glyph.totalDistance == 0 {
            glyphs[index].coordinate = glyph.inputCoordinate
            glyphs[index].pathActive = false
            activateFade(for: index)
            return
        }

        glyphs[index].pathStep += 1
        let ratio = Double(glyphs[index].pathStep) / Double(glyph.pathSteps)
        let distance = options.movementEasing.value(at: ratio) * glyph.totalDistance
        glyphs[index].coordinate = Geometry.coordinateOnLine(
            from: glyph.pathOrigin,
            to: glyph.inputCoordinate,
            t: distance / glyph.totalDistance
        )
        if glyphs[index].pathStep == glyph.pathSteps {
            glyphs[index].pathActive = false
            // QUIRK(src/effects/rain.rs:210-211; src/engine/ctx.rs:475-478,511-528; plan.md):
            // PathComplete activates the fade scene in the same tick, before scene stepping.
            activateFade(for: index)
        }
    }

    private mutating func activateFade(for index: Int) {
        glyphs[index].scene = .fade(index: 0, ticksElapsed: 0)
    }

    private mutating func updateScene(for index: Int) {
        switch glyphs[index].scene {
        case .rain:
            glyphs[index].scene = .rainHold
        case .rainHold, .done:
            break
        case .fade(let colorIndex, let ticksElapsed):
            let elapsed = ticksElapsed + 1
            if elapsed == Self.fadeFrameDuration {
                if colorIndex + 1 < glyphs[index].fadeColors.count {
                    glyphs[index].scene = .fade(index: colorIndex + 1, ticksElapsed: 0)
                } else {
                    glyphs[index].scene = .done
                }
            } else {
                glyphs[index].scene = .fade(index: colorIndex, ticksElapsed: elapsed)
            }
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            var winners: [Int: (layer: Int, characterID: Int, visual: (symbol: UInt32, foreground: UInt32))] = [:]
            for glyph in glyphs where glyph.visible {
                let coordinate = glyph.coordinate
                guard (1...canvas.columns).contains(coordinate.column),
                      (1...canvas.rows).contains(coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - coordinate.row) * canvas.columns + coordinate.column - 1
                if let winner = winners[cellIndex], (winner.layer, winner.characterID) > (0, glyph.characterID) {
                    continue
                }
                winners[cellIndex] = (0, glyph.characterID, glyph.visual)
            }
            for (index, winner) in winners {
                cells[index] = .init(codepoint: winner.visual.symbol, foreground: winner.visual.foreground, background: 0)
            }
        }
    }

    private var hasPendingWork: Bool {
        !groups.isEmpty || !pending.isEmpty || !active.isEmpty
    }

    private func placeholderGlyph() -> Glyph {
        Glyph(
            characterID: 0,
            inputCoordinate: Coordinate(column: 1, row: 1),
            inputSymbol: 32,
            rainSymbol: 32,
            rainColor: 0,
            fadeColors: [0],
            pathOrigin: Coordinate(column: 1, row: 1),
            totalDistance: 0,
            pathSteps: 0,
            coordinate: Coordinate(column: 1, row: 1),
            pathActive: false,
            scene: .done
        )
    }

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }

    private func color(_ word: UInt32) -> Color {
        Color(hex: String(format: "%06x", word))
    }
}
