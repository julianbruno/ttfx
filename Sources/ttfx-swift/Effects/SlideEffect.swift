import Foundation
import TTFXCore

public struct SlideEffect: Effect {
    public enum Grouping: Equatable, Sendable {
        case row
        case column
        case diagonal
    }

    public enum MovementEasing: Equatable, Sendable {
        case linear
        case inOutQuad
        case outExpo
        case outCirc
        case inOutQuart
        case inOutExpo
        case outSine
        case inOutSine
    }

    public struct Configuration: Sendable {
        public var movementSpeed: Double
        public var grouping: Grouping
        public var gap: Int
        public var reverseDirection: Bool
        public var merge: Bool
        public var movementEasing: MovementEasing
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientFrames: Int
        public var finalGradientDirection: GradientDirection

        public init(
            movementSpeed: Double = 0.8,
            grouping: Grouping = .row,
            gap: Int = 2,
            reverseDirection: Bool = false,
            merge: Bool = false,
            movementEasing: MovementEasing = .inOutQuad,
            finalGradientStops: [Color] = [Color(hex: "833ab4"), Color(hex: "fd1d1d"), Color(hex: "fcb045")],
            finalGradientSteps: [Int] = [12],
            finalGradientFrames: Int = 6,
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(movementSpeed > 0, "movement speed must be positive")
            precondition(gap >= 0, "gap must not be negative")
            precondition(finalGradientFrames > 0, "gradient frames must be positive")
            self.movementSpeed = movementSpeed
            self.grouping = grouping
            self.gap = gap
            self.reverseDirection = reverseDirection
            self.merge = merge
            self.movementEasing = movementEasing
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientFrames = finalGradientFrames
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Glyph {
        let inputCoordinate: Coordinate
        let symbol: UInt32
        let colors: [UInt32]
        var coordinate: Coordinate
        var pathOrigin: Coordinate
        var visible = false
        var pathStep = 0
        var pathSteps = 0
        var pathActive = false
        var sceneIndex = 0
        var sceneTicksRemaining: Int
        var sceneActive = false

        var foreground: UInt32 { colors[sceneIndex] }
    }

    private let canvas: Canvas
    private let options: Configuration
    private var glyphs: [Glyph] = []
    private var pendingGroups: [[Int]] = []
    private var activeGroups: [[Int]] = []
    private var currentGap = 0
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, slideConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        slideConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = slideConfiguration
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }

        releaseNextGroupCharacters()
        updateGlyphs()
        render(into: &frame)

        if !hasPendingWork {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText) {
        let positions = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        guard !positions.isEmpty else {
            isComplete = true
            return
        }

        let bottom = positions.map(\.row).min()!
        let top = positions.map(\.row).max()!
        let left = positions.map(\.column).min()!
        let right = positions.map(\.column).max()!
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let finalColors = try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )
        let colorByCoordinate = Dictionary(uniqueKeysWithValues: finalColors.entries.map { ($0.coordinate, rgb($0.color)) })

        glyphs = zip(input.scalars, positions).map { scalar, coordinate in
            let targetColor = colorByCoordinate[coordinate]!
            let colors = try! Gradient(
                stops: [options.finalGradientStops[0], Color(hex: String(format: "%06x", targetColor))],
                steps: 10
            ).spectrum.map(rgb)
            return Glyph(
                inputCoordinate: coordinate,
                symbol: scalar,
                colors: colors,
                coordinate: coordinate,
                pathOrigin: coordinate,
                sceneTicksRemaining: options.finalGradientFrames + 1,
                sceneActive: false
            )
        }

        var groups = groupedGlyphIndices()
        for index in groups.indices {
            // QUIRK(src/effects/slide.rs:162-179): choose the start from the original
            // group, then reverse the live group so release order remains upstream-compatible.
            let original = groups[index]
            let groupStart = initialCoordinate(for: &groups[index], original: original, index: index)
            for glyphIndex in groups[index] {
                let glyphStart = startingCoordinate(for: glyphIndex, from: groupStart)
                glyphs[glyphIndex].coordinate = glyphStart
                glyphs[glyphIndex].pathOrigin = glyphStart
            }
        }
        pendingGroups = groups
    }

    private func groupedGlyphIndices() -> [[Int]] {
        let indices = glyphs.indices.sorted {
            let left = glyphs[$0].inputCoordinate
            let right = glyphs[$1].inputCoordinate
            return (left.row, left.column) < (right.row, right.column)
        }
        let keys: [Int]
        let key: (Glyph) -> Int
        switch options.grouping {
        case .row:
            keys = Array(Set(glyphs.map { $0.inputCoordinate.row })).sorted(by: >)
            key = { $0.inputCoordinate.row }
        case .column:
            keys = Array(Set(glyphs.map { $0.inputCoordinate.column })).sorted()
            key = { $0.inputCoordinate.column }
        case .diagonal:
            keys = Array(Set(glyphs.map { $0.inputCoordinate.column - $0.inputCoordinate.row })).sorted()
            key = { $0.inputCoordinate.column - $0.inputCoordinate.row }
        }
        return keys.map { value in indices.filter { key(glyphs[$0]) == value } }
    }

    private func initialCoordinate(for group: inout [Int], original: [Int], index: Int) -> Coordinate {
        switch options.grouping {
        case .row:
            let startsFromRight = options.merge && index.isMultiple(of: 2)
            if !startsFromRight { group.reverse() }
            if options.reverseDirection && !options.merge {
                group.reverse()
                return .init(column: canvas.columns + 1, row: glyphs[group[0]].inputCoordinate.row)
            }
            return .init(
                column: startsFromRight ? canvas.columns + 1 : 0,
                row: glyphs[group[0]].inputCoordinate.row
            )
        case .column:
            let startsFromBottom = options.merge && index.isMultiple(of: 2)
            if !startsFromBottom { group.reverse() }
            if options.reverseDirection && !options.merge {
                group.reverse()
                return .init(column: glyphs[group[0]].inputCoordinate.column, row: 0)
            }
            return .init(
                column: glyphs[group[0]].inputCoordinate.column,
                row: startsFromBottom ? 0 : canvas.rows + 1
            )
        case .diagonal:
            // QUIRK(src/effects/slide.rs:208-236): diagonal groups share one off-canvas
            // origin; they do not start from each glyph's target row or column.
            let last = glyphs[original.last!].inputCoordinate
            let bottomDistance = last.row
            var start = Coordinate(column: last.column - bottomDistance, row: last.row - bottomDistance)
            if options.merge && index.isMultiple(of: 2) {
                group.reverse()
                let first = glyphs[original[0]].inputCoordinate
                let distance = canvas.rows + 1 - first.row
                start = .init(column: first.column + distance, row: first.row + distance)
            }
            if options.reverseDirection && !options.merge {
                group.reverse()
                let first = glyphs[original[0]].inputCoordinate
                let distance = canvas.rows + 1 - first.row
                start = .init(column: first.column + distance, row: first.row + distance)
            }
            return start
        }
    }

    private func startingCoordinate(for glyphIndex: Int, from coordinate: Coordinate) -> Coordinate {
        switch options.grouping {
        case .row: return .init(column: coordinate.column, row: glyphs[glyphIndex].inputCoordinate.row)
        case .column: return .init(column: glyphs[glyphIndex].inputCoordinate.column, row: coordinate.row)
        case .diagonal: return coordinate
        }
    }

    private mutating func releaseNextGroupCharacters() {
        if currentGap == options.gap, !pendingGroups.isEmpty {
            activeGroups.append(pendingGroups.removeFirst())
            currentGap = 0
        } else if !pendingGroups.isEmpty {
            currentGap += 1
        }

        for index in activeGroups.indices where !activeGroups[index].isEmpty {
            activate(glyph: activeGroups[index].removeFirst())
        }
        activeGroups.removeAll { $0.isEmpty }
    }

    private mutating func activate(glyph index: Int) {
        let distance = Geometry.lineLength(from: glyphs[index].coordinate, to: glyphs[index].inputCoordinate)
        glyphs[index].pathSteps = PyCompat.roundHalfEven(distance / options.movementSpeed)
        glyphs[index].pathActive = true
        glyphs[index].visible = true
        glyphs[index].sceneActive = true
    }

    private mutating func updateGlyphs() {
        for index in glyphs.indices where glyphs[index].pathActive || glyphs[index].sceneActive {
            updatePath(for: index)
            updateScene(for: index)
        }
    }

    private mutating func updatePath(for index: Int) {
        guard glyphs[index].pathActive else { return }
        guard glyphs[index].pathSteps > 0 else {
            glyphs[index].coordinate = glyphs[index].inputCoordinate
            glyphs[index].pathActive = false
            return
        }
        glyphs[index].pathStep += 1
        let ratio = Double(glyphs[index].pathStep) / Double(glyphs[index].pathSteps)
        let eased = easingValue(at: ratio)
        glyphs[index].coordinate = Geometry.coordinateOnLine(
            from: glyphs[index].pathOrigin,
            to: glyphs[index].inputCoordinate,
            t: eased
        )
        if glyphs[index].pathStep == glyphs[index].pathSteps {
            glyphs[index].pathActive = false
        }
    }

    private mutating func updateScene(for index: Int) {
        guard glyphs[index].sceneActive else { return }
        glyphs[index].sceneTicksRemaining -= 1
        guard glyphs[index].sceneTicksRemaining == 0 else { return }
        if glyphs[index].sceneIndex + 1 < glyphs[index].colors.count {
            glyphs[index].sceneIndex += 1
            if glyphs[index].sceneIndex + 1 == glyphs[index].colors.count {
                glyphs[index].sceneTicksRemaining = 1
            } else {
                glyphs[index].sceneTicksRemaining = options.finalGradientFrames
            }
        } else {
            glyphs[index].sceneActive = false
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            for glyph in glyphs where glyph.visible {
                let coordinate = glyph.coordinate
                guard (1...canvas.columns).contains(coordinate.column), (1...canvas.rows).contains(coordinate.row) else { continue }
                let cellIndex = (canvas.rows - coordinate.row) * canvas.columns + coordinate.column - 1
                cells[cellIndex] = .init(codepoint: glyph.symbol, foreground: glyph.foreground, background: 0)
            }
        }
    }

    private var hasPendingWork: Bool {
        !pendingGroups.isEmpty || !activeGroups.isEmpty || glyphs.contains { $0.pathActive || $0.sceneActive }
    }

    private func easingValue(at value: Double) -> Double {
        switch options.movementEasing {
        case .linear:
            return value
        case .inOutQuad:
            if value < 0.5 { return 2 * value * value }
            let inverse = -2 * value + 2
            return 1 - inverse * inverse / 2
        case .outExpo:
            return value == 1 ? 1 : 1 - pow(2, -10 * value)
        case .outCirc:
            return sqrt(1 - pow(value - 1, 2))
        case .inOutQuart:
            if value < 0.5 { return 8 * pow(value, 4) }
            return 1 - pow(-2 * value + 2, 4) / 2
        case .inOutExpo:
            if value == 0 || value == 1 { return value }
            if value < 0.5 { return pow(2, 20 * value - 10) / 2 }
            return (2 - pow(2, -20 * value + 10)) / 2
        case .outSine:
            return sin(value * .pi / 2)
        case .inOutSine:
            return -(cos(.pi * value) - 1) / 2
        }
    }

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
