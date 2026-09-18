import Foundation
import TTFXCore

private let explicitBlackForegroundSentinel: UInt32 = 0xFFFF_FFFE

public struct SweepEffect: Effect {
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
        public var sweepSymbols: [String]
        public var firstSweepDirection: Direction
        public var secondSweepDirection: Direction
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            sweepSymbols: [String] = ["█", "▓", "▒", "░"],
            firstSweepDirection: Direction = .columnRightToLeft,
            secondSweepDirection: Direction = .columnLeftToRight,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "ffffff")],
            finalGradientSteps: [Int] = [8],
            finalGradientDirection: GradientDirection = .vertical
        ) {
            precondition(!sweepSymbols.isEmpty, "sweep symbols must not be empty")
            precondition(!finalGradientStops.isEmpty, "final gradient stops must not be empty")
            precondition(!finalGradientSteps.isEmpty && finalGradientSteps.allSatisfy { $0 > 0 }, "final gradient steps must be positive")
            self.sweepSymbols = sweepSymbols
            self.firstSweepDirection = firstSweepDirection
            self.secondSweepDirection = secondSweepDirection
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum SceneKind { case initial, second }

    private struct SceneFrame {
        let symbol: UInt32
        let foreground: UInt32
        let background: UInt32
        let duration: Int

        init(symbol: UInt32, foreground: UInt32, background: UInt32 = 0, duration: Int) {
            self.symbol = symbol
            self.foreground = foreground
            self.background = background
            self.duration = duration
        }
    }

    private struct Glyph {
        let coordinate: Coordinate
        let inputSymbol: UInt32
        let initialFrames: [SceneFrame]
        let secondFrames: [SceneFrame]
        var visible = false
        var activeScene: SceneKind?
        var renderedFrame: SceneFrame?
        var frameIndex = 0
        var ticksRemaining = 0

        var active: Bool { activeScene != nil }

        var currentFrame: SceneFrame? {
            switch activeScene {
            case .initial: return initialFrames[frameIndex]
            case .second: return secondFrames[frameIndex]
            case nil: return nil
            }
        }
    }

    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var firstGroups: [[Int]] = []
    private var secondGroups: [[Int]] = []
    private var easingStep = 0
    private var previousLength = 0
    private var firstPhase = true
    private var complete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, sweepConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        sweepConfiguration: Configuration
    ) {
        self.canvas = canvas
        self.options = sweepConfiguration
        self.rng = configuration.makeRNG(seed: seed)
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !complete || glyphs.contains(where: \.active) else { return .complete }

        advanceEaser()
        render(into: &frame)
        advanceScenes()

        if complete && !glyphs.contains(where: \.active) { return .complete }
        return .running
    }

    private mutating func build(input: InputText) {
        let inputSources = zip(input.scalars, input.positions).map { scalar, position in
            (coordinate: Coordinate(column: position.column, row: position.row), symbol: scalar)
        }
        guard !inputSources.isEmpty else {
            complete = true
            return
        }
        let inputByCoordinate = Dictionary(uniqueKeysWithValues: inputSources.map { ($0.coordinate, $0.symbol) })
        let sources = (1...canvas.rows).reversed().flatMap { row in
            (1...canvas.columns).map { column in
                let coordinate = Coordinate(column: column, row: row)
                return (
                    symbol: inputByCoordinate[coordinate] ?? UInt32(32),
                    coordinate: coordinate,
                    isFill: inputByCoordinate[coordinate] == nil
                )
            }
        }

        let coordinates = inputSources.map(\.coordinate)
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
        )).entries.map { ($0.coordinate, rgb($0.color)) })
        let grayPalette = ["A0A0A0", "808080", "404040", "202020", "101010"].map(Color.init(hex:)).map(rgb)
        let secondPalette = finalGradient.spectrum.map(rgb)
        let sweepScalars = options.sweepSymbols.map { symbol in symbol.unicodeScalars.first?.value ?? 32 }

        glyphs = sources.map { source in
            var initialFrames: [SceneFrame] = []
            initialFrames.reserveCapacity(sweepScalars.count + 1)
            for symbol in sweepScalars {
                initialFrames.append(.init(
                    symbol: symbol,
                    foreground: choice(from: grayPalette),
                    duration: 5
                ))
            }
            initialFrames.append(.init(symbol: source.symbol, foreground: 0x808080, duration: 1))

            var secondFrames: [SceneFrame] = []
            secondFrames.reserveCapacity(sweepScalars.count + 1)
            for symbol in sweepScalars {
                secondFrames.append(.init(
                    symbol: symbol,
                    foreground: choice(from: secondPalette),
                    duration: 5
                ))
            }
            let finalForeground = source.isFill ? UInt32(0) : finalMapping[source.coordinate]!
            let finalBackground = source.isFill ? explicitBlackForegroundSentinel : UInt32(0)
            secondFrames.append(.init(symbol: source.symbol, foreground: finalForeground, background: finalBackground, duration: 1))

            return Glyph(
                coordinate: source.coordinate,
                inputSymbol: source.symbol,
                initialFrames: initialFrames,
                secondFrames: secondFrames
            )
        }
        firstGroups = groupedGlyphs(direction: options.firstSweepDirection)
        secondGroups = groupedGlyphs(direction: options.secondSweepDirection)
    }

    private mutating func choice(from values: [UInt32]) -> UInt32 {
        values[rng.integer(in: 0..<values.count)]
    }

    private mutating func advanceEaser() {
        guard !complete else { return }
        let groups = firstPhase ? firstGroups : secondGroups
        guard easingStep < Self.easingSteps else { return }
        easingStep += 1
        let progress = Double(easingStep) / Double(Self.easingSteps)
        let eased = min(max(Easing.inOutCirc.value(at: progress), 0), 1)
        let length = Int(eased * Double(groups.count))
        if length > previousLength {
            for group in groups[previousLength..<length] {
                for index in group { activate(index, scene: firstPhase ? .initial : .second) }
            }
        }
        previousLength = length
        if easingStep >= Self.easingSteps {
            if firstPhase {
                firstPhase = false
                easingStep = 0
                previousLength = 0
            } else {
                complete = true
            }
        }
    }

    private mutating func activate(_ index: Int, scene: SceneKind) {
        glyphs[index].visible = true
        glyphs[index].activeScene = scene
        glyphs[index].frameIndex = 0
        glyphs[index].renderedFrame = glyphs[index].currentFrame
        glyphs[index].ticksRemaining = frameDuration(for: index)
    }

    private func frameDuration(for index: Int) -> Int {
        glyphs[index].currentFrame?.duration ?? 0
    }

    private mutating func advanceScenes() {
        for index in glyphs.indices where glyphs[index].active {
            glyphs[index].ticksRemaining -= 1
            guard glyphs[index].ticksRemaining == 0 else { continue }
            let frameCount = glyphs[index].activeScene == .initial ? glyphs[index].initialFrames.count : glyphs[index].secondFrames.count
            if glyphs[index].frameIndex + 1 < frameCount {
                glyphs[index].frameIndex += 1
                glyphs[index].renderedFrame = glyphs[index].currentFrame
                glyphs[index].ticksRemaining = frameDuration(for: index)
            } else {
                glyphs[index].activeScene = nil
            }
        }
    }

    private func groupedGlyphs(direction: Direction) -> [[Int]] {
        let ordered = glyphs.indices.sorted {
            let lhs = glyphs[$0].coordinate
            let rhs = glyphs[$1].coordinate
            return (lhs.row, lhs.column) < (rhs.row, rhs.column)
        }
        let key: (Glyph) -> Int
        let reverse: Bool
        switch direction {
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
            reverse = direction == .outsideToCenter
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
                guard let sceneFrame = glyph.renderedFrame,
                      (1...canvas.columns).contains(glyph.coordinate.column),
                      (1...canvas.rows).contains(glyph.coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
                cells[cellIndex] = .init(codepoint: sceneFrame.symbol, foreground: sceneFrame.foreground, background: sceneFrame.background)
            }
        }
    }

    private static let easingSteps = 100

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}
