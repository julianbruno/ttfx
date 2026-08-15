import TTFXCore

public struct WipeEffect: Effect {
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
        public var direction: Direction
        public var delay: Int
        public var easing: Easing
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientFrames: Int
        public var finalGradientDirection: GradientDirection

        public init(
            direction: Direction = .diagonalTopLeftToBottomRight,
            delay: Int = 0,
            easing: Easing = .inOutCirc,
            finalGradientStops: [Color] = [Color(hex: "833ab4"), Color(hex: "fd1d1d"), Color(hex: "fcb045")],
            finalGradientSteps: [Int] = [12],
            finalGradientFrames: Int = 3,
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(delay >= 0, "wipe delay must not be negative")
            precondition(finalGradientFrames > 0, "gradient frames must be positive")
            self.direction = direction
            self.delay = delay
            self.easing = easing
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientFrames = finalGradientFrames
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Glyph {
        let coordinate: Coordinate
        let symbol: UInt32
        let colors: [UInt32]
        var visible = false
        var sceneIndex = 0
        var sceneTicksRemaining: Int
        var sceneActive = false

        var foreground: UInt32 { colors[sceneIndex] }
    }

    private let canvas: Canvas
    private let options: Configuration
    private var glyphs: [Glyph] = []
    private var groups: [[Int]] = []
    private var easingStep = 0
    private var previousLength = 0
    private var delayRemaining = 0
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, wipeConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        wipeConfiguration: Configuration
    ) {
        self.canvas = canvas
        options = wipeConfiguration
        delayRemaining = wipeConfiguration.delay
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }

        if delayRemaining == 0 {
            advanceEaser()
            delayRemaining = options.delay
        } else {
            delayRemaining -= 1
        }
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
        else { return }

        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = try! finalGradient.coordinateColorMapping(
            minRow: bottom,
            maxRow: top,
            minColumn: left,
            maxColumn: right,
            direction: options.finalGradientDirection
        )
        let finalColors = Dictionary(uniqueKeysWithValues: mapping.entries.map { ($0.coordinate, rgb($0.color)) })
        let startColor = finalGradient.spectrum[0]

        for (position, symbol) in zip(input.positions, input.scalars) {
            let coordinate = Coordinate(column: position.column, row: position.row)
            let scene = try! Gradient(
                stops: [startColor, finalColors[coordinate].map(color) ?? startColor],
                steps: options.finalGradientSteps
            )
            glyphs.append(.init(
                coordinate: coordinate,
                symbol: symbol,
                colors: scene.spectrum.map(rgb),
                sceneTicksRemaining: options.finalGradientFrames
            ))
        }
        groups = groupedGlyphs()
    }

    private mutating func advanceEaser() {
        guard easingStep < Self.easingSteps else { return }
        easingStep += 1
        let progress = Double(easingStep) / Double(Self.easingSteps)
        let eased = min(max(options.easing.value(at: progress), 0), 1)
        let length = Int(eased * Double(groups.count))

        if length > previousLength {
            for group in groups[previousLength..<length] {
                for index in group { activate(index) }
            }
        } else if length < previousLength {
            // QUIRK(src/effects/wipe.rs:142-157; ordering-inventory.md): non-monotonic easings remove whole
            // groups, reset their scene, and only then permit a later re-add.
            for group in groups[length..<previousLength] {
                for index in group { removeAndReset(index) }
            }
        }
        previousLength = length
    }

    private mutating func advanceScenes() {
        for index in glyphs.indices where glyphs[index].sceneActive {
            glyphs[index].sceneTicksRemaining -= 1
            guard glyphs[index].sceneTicksRemaining == 0 else { continue }
            if glyphs[index].sceneIndex + 1 < glyphs[index].colors.count {
                glyphs[index].sceneIndex += 1
                glyphs[index].sceneTicksRemaining = options.finalGradientFrames
            } else {
                glyphs[index].sceneActive = false
            }
        }
    }

    private mutating func activate(_ index: Int) {
        glyphs[index].visible = true
        glyphs[index].sceneIndex = 0
        glyphs[index].sceneTicksRemaining = options.finalGradientFrames
        glyphs[index].sceneActive = true
    }

    private mutating func removeAndReset(_ index: Int) {
        glyphs[index].sceneActive = false
        glyphs[index].sceneIndex = 0
        glyphs[index].sceneTicksRemaining = options.finalGradientFrames
        glyphs[index].visible = false
    }

    private func groupedGlyphs() -> [[Int]] {
        let ordered = glyphs.indices.sorted {
            let lhs = glyphs[$0].coordinate
            let rhs = glyphs[$1].coordinate
            return (lhs.row, lhs.column) < (rhs.row, rhs.column)
        }
        let key: (Glyph) -> Int
        let reverse: Bool
        switch options.direction {
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
            reverse = options.direction == .outsideToCenter
        }
        var buckets: [Int: [Int]] = [:]
        for index in ordered { buckets[key(glyphs[index]), default: []].append(index) }
        var groups = buckets.keys.sorted().compactMap { buckets[$0] }
        if reverse { groups.reverse() }
        return groups
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

    private func color(_ word: UInt32) -> Color {
        Color(hex: String(format: "%06x", word))
    }
}
