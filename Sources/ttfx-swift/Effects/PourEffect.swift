import Foundation
import TTFXCore

public struct PourEffect: Effect {
    public enum PourDirection: Sendable {
        case up
        case down
        case left
        case right
    }

    public struct Configuration: Sendable {
        public var pourDirection: PourDirection
        public var pourSpeed: Int
        public var movementSpeedRange: ClosedRange<Double>
        public var gap: Int
        public var startingColor: Color
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientFrames: Int
        public var finalGradientDirection: GradientDirection
        public var movementEasing: Easing

        public init(
            pourDirection: PourDirection = .down,
            pourSpeed: Int = 2,
            movementSpeedRange: ClosedRange<Double> = 0.4...0.6,
            gap: Int = 1,
            startingColor: Color = Color(hex: "ffffff"),
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientFrames: Int = 6,
            finalGradientDirection: GradientDirection = .vertical,
            movementEasing: Easing = .inQuad
        ) {
            precondition(pourSpeed > 0, "pour speed must be positive")
            precondition(movementSpeedRange.lowerBound > 0 && movementSpeedRange.upperBound > 0, "movement speed must be positive")
            precondition(gap >= 0, "gap must not be negative")
            precondition(finalGradientFrames > 0, "gradient frames must be positive")
            self.pourDirection = pourDirection
            self.pourSpeed = pourSpeed
            self.movementSpeedRange = movementSpeedRange
            self.gap = gap
            self.startingColor = startingColor
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientFrames = finalGradientFrames
            self.finalGradientDirection = finalGradientDirection
            self.movementEasing = movementEasing
        }
    }

    private struct Glyph {
        let characterID: Int
        let inputCoordinate: Coordinate
        let symbol: UInt32
        let colors: [UInt32]
        var coordinate: Coordinate
        var pathOrigin: Coordinate
        var pathSteps: Int
        var pathStep = 0
        var pathActive = true
        var visible = false
        var sceneIndex = 0
        var sceneTicksElapsed = 0
        var sceneActive = true

        var active: Bool { pathActive || sceneActive }
        var foreground: UInt32 { colors[min(sceneIndex, colors.count - 1)] }
    }

    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var pendingGroups: [[Int]] = []
    private var currentGroup: [Int] = []
    private var active: [Int] = []
    private var gap: Int = 0
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, pourConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        pourConfiguration: Configuration
    ) {
        self.canvas = canvas
        options = pourConfiguration
        rng = Xoshiro256PlusPlus(seed: seed)
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard hasPendingWork else {
            isComplete = true
            return .complete
        }

        if currentGroup.isEmpty, !pendingGroups.isEmpty {
            currentGroup = pendingGroups.removeFirst()
        }
        if !currentGroup.isEmpty {
            if gap == 0 {
                for _ in 0..<options.pourSpeed {
                    guard !currentGroup.isEmpty else { break }
                    let index = currentGroup.removeFirst()
                    glyphs[index].visible = true
                    active.append(index)
                }
                gap = options.gap
            } else {
                gap -= 1
            }
        }

        active.sort()
        for index in active { updatePath(index) }
        render(into: &frame)
        for index in active { updateScene(index) }
        active.removeAll { !glyphs[$0].active }

        if !hasPendingWork {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText) {
        var created: [(characterID: Int, symbol: UInt32, coordinate: Coordinate)] = []
        for (index, pair) in zip(input.scalars, input.positions).enumerated() where pair.0 != 32 {
            created.append((index, pair.0, Coordinate(column: pair.1.column, row: pair.1.row)))
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
        let finalColors = Dictionary(uniqueKeysWithValues: mapping.entries.map { ($0.coordinate, $0.color) })

        glyphs = Array(repeating: placeholderGlyph(), count: created.count)
        for sourceIndex in created.indices.sorted(by: { lhs, rhs in
            let a = created[lhs].coordinate
            let b = created[rhs].coordinate
            switch options.pourDirection {
            case .down: return a.row == b.row ? a.column < b.column : a.row < b.row
            case .up: return a.row == b.row ? a.column < b.column : a.row > b.row
            case .left: return a.column == b.column ? a.row < b.row : a.column < b.column
            case .right: return a.column == b.column ? a.row < b.row : a.column > b.column
            }
        }) {
            let source = created[sourceIndex]
            let finalColor = finalColors[source.coordinate]!
            let colors = try! Gradient(
                stops: [options.startingColor, finalColor],
                steps: options.finalGradientSteps
            ).spectrum.map(rgb)
            let start = startingCoordinate(for: source.coordinate)
            let speed = rng.uniform(options.movementSpeedRange.lowerBound, options.movementSpeedRange.upperBound)
            let distance = Geometry.lineLength(from: start, to: source.coordinate)
            glyphs[sourceIndex] = Glyph(
                characterID: source.characterID,
                inputCoordinate: source.coordinate,
                symbol: source.symbol,
                colors: colors,
                coordinate: start,
                pathOrigin: start,
                pathSteps: PyCompat.roundHalfEven(distance / speed)
            )
        }

        let groups = groupedGlyphIndices()
        for (index, group) in groups.enumerated() {
            if index.isMultiple(of: 2) {
                pendingGroups.append(group)
            } else {
                pendingGroups.append(group.reversed())
            }
        }
    }

    private func groupedGlyphIndices() -> [[Int]] {
        let sorted = glyphs.indices.sorted {
            let lhs = glyphs[$0].inputCoordinate
            let rhs = glyphs[$1].inputCoordinate
            if lhs.row != rhs.row { return lhs.row < rhs.row }
            return lhs.column < rhs.column
        }
        switch options.pourDirection {
        case .down:
            return Array(Set(glyphs.map { $0.inputCoordinate.row })).sorted().map { row in
                sorted.filter { glyphs[$0].inputCoordinate.row == row }
            }
        case .up:
            return Array(Set(glyphs.map { $0.inputCoordinate.row })).sorted(by: >).map { row in
                sorted.filter { glyphs[$0].inputCoordinate.row == row }
            }
        case .left:
            return Array(Set(glyphs.map { $0.inputCoordinate.column })).sorted().map { column in
                sorted.filter { glyphs[$0].inputCoordinate.column == column }
            }
        case .right:
            return Array(Set(glyphs.map { $0.inputCoordinate.column })).sorted(by: >).map { column in
                sorted.filter { glyphs[$0].inputCoordinate.column == column }
            }
        }
    }

    private func startingCoordinate(for coordinate: Coordinate) -> Coordinate {
        switch options.pourDirection {
        case .down:
            return Coordinate(column: coordinate.column, row: canvas.rows)
        case .up:
            return Coordinate(column: coordinate.column, row: 1)
        case .left:
            return Coordinate(column: canvas.columns, row: coordinate.row)
        case .right:
            return Coordinate(column: 1, row: coordinate.row)
        }
    }

    private mutating func updatePath(_ index: Int) {
        guard glyphs[index].pathActive else { return }
        if glyphs[index].pathSteps == 0 {
            glyphs[index].coordinate = glyphs[index].inputCoordinate
            glyphs[index].pathActive = false
            return
        }
        glyphs[index].pathStep += 1
        let raw = Double(glyphs[index].pathStep) / Double(glyphs[index].pathSteps)
        let eased = options.movementEasing.value(at: raw)
        glyphs[index].coordinate = Geometry.coordinateOnLine(
            from: glyphs[index].pathOrigin,
            to: glyphs[index].inputCoordinate,
            t: eased
        )
        if glyphs[index].pathStep >= glyphs[index].pathSteps {
            glyphs[index].pathActive = false
        }
    }

    private mutating func updateScene(_ index: Int) {
        guard glyphs[index].sceneActive else { return }
        glyphs[index].sceneTicksElapsed += 1
        guard glyphs[index].sceneTicksElapsed == options.finalGradientFrames else { return }
        glyphs[index].sceneTicksElapsed = 0
        if glyphs[index].sceneIndex + 1 < glyphs[index].colors.count {
            glyphs[index].sceneIndex += 1
        } else {
            glyphs[index].sceneActive = false
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            var winners: [Int: (characterID: Int, glyph: Glyph)] = [:]
            for glyph in glyphs where glyph.visible {
                guard (1...canvas.columns).contains(glyph.coordinate.column),
                      (1...canvas.rows).contains(glyph.coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
                if let winner = winners[cellIndex], winner.characterID > glyph.characterID { continue }
                winners[cellIndex] = (glyph.characterID, glyph)
            }
            for (cellIndex, winner) in winners {
                cells[cellIndex] = .init(codepoint: winner.glyph.symbol, foreground: winner.glyph.foreground, background: 0)
            }
        }
    }

    private var hasPendingWork: Bool {
        !pendingGroups.isEmpty || !currentGroup.isEmpty || !active.isEmpty
    }

    private func placeholderGlyph() -> Glyph {
        Glyph(
            characterID: 0,
            inputCoordinate: Coordinate(column: 1, row: 1),
            symbol: 32,
            colors: [0],
            coordinate: Coordinate(column: 1, row: 1),
            pathOrigin: Coordinate(column: 1, row: 1),
            pathSteps: 0,
            pathActive: false,
            sceneActive: false
        )
    }

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
