import Foundation
import TTFXCore

public struct MatrixEffect: Effect {
    public struct Configuration: Sendable {
        public var highlightColor: Color
        public var rainColorGradient: [Color]
        public var rainSymbols: [String]
        public var rainFallDelayRange: ClosedRange<Int>
        public var rainColumnDelayRange: ClosedRange<Int>
        public var rainTime: Int
        public var symbolSwapChance: Double
        public var colorSwapChance: Double
        public var resolveDelay: Int
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientFrames: Int
        public var finalGradientDirection: GradientDirection

        public init(
            highlightColor: Color = Color(hex: "dbffdb"),
            rainColorGradient: [Color] = [Color(hex: "92be92"), Color(hex: "185318")],
            rainSymbols: [String] = ["2", "5", "9", "8", "Z", "*", ")", ":", ".", "\"", "=", "+", "-", "¦", "|", "_", "ｦ", "ｱ", "ｳ", "ｴ", "ｵ", "ｶ", "ｷ", "ｹ", "ｺ", "ｻ", "ｼ", "ｽ", "ｾ", "ｿ", "ﾀ", "ﾂ", "ﾃ", "ﾅ", "ﾆ", "ﾇ", "ﾈ", "ﾊ", "ﾋ", "ﾎ", "ﾏ", "ﾐ", "ﾑ", "ﾒ", "ﾓ", "ﾔ", "ﾕ", "ﾗ", "ﾘ", "ﾜ"],
            rainFallDelayRange: ClosedRange<Int> = 2...15,
            rainColumnDelayRange: ClosedRange<Int> = 3...9,
            rainTime: Int = 15,
            symbolSwapChance: Double = 0.005,
            colorSwapChance: Double = 0.001,
            resolveDelay: Int = 3,
            finalGradientStops: [Color] = [Color(hex: "92be92"), Color(hex: "336b33")],
            finalGradientSteps: [Int] = [12],
            finalGradientFrames: Int = 3,
            finalGradientDirection: GradientDirection = .radial
        ) {
            precondition(!rainColorGradient.isEmpty, "rain color gradient must not be empty")
            precondition(!rainSymbols.isEmpty, "rain symbols must not be empty")
            precondition(rainFallDelayRange.lowerBound > 0, "rain fall delay must be positive")
            precondition(rainColumnDelayRange.lowerBound > 0, "rain column delay must be positive")
            precondition(rainTime > 0, "rain time must be positive")
            precondition(symbolSwapChance > 0 && colorSwapChance > 0, "swap chances must be positive")
            precondition(resolveDelay > 0, "resolve delay must be positive")
            precondition(finalGradientFrames > 0, "final gradient frames must be positive")
            self.highlightColor = highlightColor
            self.rainColorGradient = rainColorGradient
            self.rainSymbols = rainSymbols
            self.rainFallDelayRange = rainFallDelayRange
            self.rainColumnDelayRange = rainColumnDelayRange
            self.rainTime = rainTime
            self.symbolSwapChance = symbolSwapChance
            self.colorSwapChance = colorSwapChance
            self.resolveDelay = resolveDelay
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientFrames = finalGradientFrames
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum Phase { case rain, fill, resolve }
    private struct Glyph {
        let input: Coordinate
        let source: UInt32
        let resolve: [UInt32]
        var coordinate: Coordinate
        var symbol: UInt32 = 32
        var foreground: UInt32 = 0
        var visible = false
        var sceneStep: Int?
    }
    private struct Column {
        let characters: [Int]
        var pending: [Int] = []
        var visible: [Int] = []
        var filling = false
        var baseDelay = 0
        var delay = 0
        var length = 0
        var hold = 0
        var dropChance = 0.08
    }
    private let canvas: Canvas
    private let options: Configuration
    private let stepDuration: Double
    private var elapsed = 0.0
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var columns: [Column] = []
    private var pending: [Int] = []
    private var active: [Int] = []
    private var full: [Int] = []
    private var colors: [Color] = []
    private var phase = Phase.rain
    private var columnDelay = 0
    private var resolveDelay = 0
    private var complete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, matrixConfiguration: .init())
    }

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64,
                matrixConfiguration: Configuration) {
        self.canvas = canvas
        self.options = matrixConfiguration
        self.resolveDelay = matrixConfiguration.resolveDelay
        self.stepDuration = 1 / Double(configuration.frameRate)
        self.rng = configuration.makeRNG(seed: seed)
        guard !input.scalars.isEmpty else { complete = true; return }
        let coordinates = input.positions.map { Coordinate(column: $0.column, row: $0.row) }
        let sources = Dictionary(uniqueKeysWithValues: zip(coordinates, input.scalars))
        let final = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = Dictionary(uniqueKeysWithValues: (try! final.coordinateColorMapping(
            minRow: coordinates.map(\.row).min()!, maxRow: coordinates.map(\.row).max()!,
            minColumn: coordinates.map(\.column).min()!, maxColumn: coordinates.map(\.column).max()!,
            direction: options.finalGradientDirection)).entries.map { ($0.coordinate, $0.color) })
        colors = (try! Gradient(stops: options.rainColorGradient, steps: 6)).spectrum
        for column in 1...canvas.columns {
            var characters: [Int] = []
            for row in stride(from: canvas.rows, through: 1, by: -1) {
                let coordinate = Coordinate(column: column, row: row)
                let resolution = (try! Gradient(stops: [options.highlightColor, mapping[coordinate] ?? Color(hex: "000000")], steps: 8)).spectrum
                    .flatMap { Array(repeating: Self.rgb($0), count: options.finalGradientFrames) }
                characters.append(glyphs.count)
                glyphs.append(.init(input: coordinate, source: sources[coordinate] ?? 32,
                    resolve: resolution, coordinate: coordinate))
            }
            columns.append(.init(characters: characters))
            setup(columns.count - 1, filling: false)
        }
        pending = Array(columns.indices)
        rng.shuffle(&pending)
    }

    private mutating func setup(_ index: Int, filling: Bool) {
        columns[index].filling = filling
        columns[index].pending = columns[index].characters
        columns[index].visible = []
        for id in columns[index].characters {
            glyphs[id].visible = false
            glyphs[id].coordinate = glyphs[id].input
        }
        columns[index].baseDelay = filling
            ? rng.integer(in: max(options.rainFallDelayRange.lowerBound / 3, 1)...max(options.rainFallDelayRange.upperBound / 3, 1))
            : rng.integer(in: options.rainFallDelayRange)
        columns[index].delay = 0
        columns[index].length = filling ? canvas.rows : rng.integer(in: max(1, Int(Double(canvas.rows) * 0.1))...canvas.rows)
        columns[index].hold = columns[index].length == canvas.rows ? rng.integer(in: 20...45) : 0
    }

    private mutating func trim(_ index: Int) {
        guard !columns[index].visible.isEmpty else { return }
        glyphs[columns[index].visible.removeFirst()].visible = false
        if columns[index].visible.count > 1 {
            let color = colors[rng.integer(in: max(0, colors.count - 3)..<colors.count)]
            glyphs[columns[index].visible[0]].foreground = Self.rgb(rustAdjustedBrightness(color, factor: 0.65))
        }
    }

    private mutating func tickColumn(_ index: Int) {
        if columns[index].delay == 0 {
            if !columns[index].pending.isEmpty {
                let next = columns[index].pending.removeFirst()
                glyphs[next].symbol = randomSymbol()
                glyphs[next].foreground = Self.rgb(options.highlightColor)
                if let previous = columns[index].visible.last { glyphs[previous].foreground = randomColor() }
                glyphs[next].visible = true
                columns[index].visible.append(next)
            } else if !columns[index].visible.isEmpty {
                let last = columns[index].visible.last!
                if glyphs[last].foreground == Self.rgb(options.highlightColor) { glyphs[last].foreground = randomColor() }
                if columns[index].hold != 0 { columns[index].hold -= 1 }
                else if !columns[index].filling {
                    if rng.random() < columns[index].dropChance {
                        for id in columns[index].visible {
                            glyphs[id].coordinate = .init(column: glyphs[id].coordinate.column, row: glyphs[id].coordinate.row - 1)
                            if glyphs[id].coordinate.row < 1 { glyphs[id].visible = false }
                        }
                        columns[index].visible.removeAll { !glyphs[$0].visible }
                    }
                    trim(index)
                }
            }
            if columns[index].visible.count > columns[index].length { trim(index) }
            columns[index].delay = columns[index].baseDelay
        } else { columns[index].delay -= 1 }
        for id in columns[index].visible {
            if rng.random() < options.symbolSwapChance { glyphs[id].symbol = randomSymbol() }
            if rng.random() < options.colorSwapChance { glyphs[id].foreground = randomColor() }
        }
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !complete else { return .complete }
        defer { elapsed += stepDuration }
        if phase != .resolve {
            if columnDelay == 0 {
                if phase == .rain {
                    for _ in 0..<rng.integer(in: 1...3) {
                        if !pending.isEmpty { active.append(pending.removeFirst()) }
                    }
                } else { active += pending; pending.removeAll() }
                columnDelay = phase == .rain ? rng.integer(in: options.rainColumnDelayRange) : 1
            } else { columnDelay -= 1 }
            for index in active {
                tickColumn(index)
                if columns[index].pending.isEmpty {
                    if columns[index].filling && !full.contains(index) { full.append(index) }
                    else if columns[index].visible.isEmpty {
                        setup(index, filling: phase == .fill)
                        pending.append(index)
                    }
                }
            }
            active.removeAll { columns[$0].visible.isEmpty }
            if phase == .fill && pending.isEmpty && active.allSatisfy({ columns[$0].pending.isEmpty && columns[$0].filling }) {
                phase = .resolve
                active.removeAll()
            }
            if phase == .rain && elapsed > Double(options.rainTime) {
                phase = .fill
                for index in active { columns[index].hold = 0; columns[index].dropChance = 1 }
                for index in pending { setup(index, filling: true) }
            }
        } else {
            for index in full {
                tickColumn(index)
                if !columns[index].visible.isEmpty {
                    if resolveDelay == 0 {
                        for _ in 0..<rng.integer(in: 1...4) where !columns[index].visible.isEmpty {
                            let position = rng.integer(in: columns[index].visible.indices)
                            let id = columns[index].visible.remove(at: position)
                            if glyphs[id].source != 32 { glyphs[id].sceneStep = 0 }
                            else { glyphs[id].visible = false }
                        }
                        resolveDelay = options.resolveDelay
                    } else { resolveDelay -= 1 }
                }
            }
            full.removeAll { columns[$0].visible.isEmpty }
        }
        let work = !full.isEmpty || !active.isEmpty || !pending.isEmpty || phase == .rain || glyphs.contains { $0.sceneStep != nil }
        for index in glyphs.indices {
            if let step = glyphs[index].sceneStep {
                glyphs[index].symbol = glyphs[index].source
                glyphs[index].foreground = glyphs[index].resolve[step]
                glyphs[index].sceneStep = step + 1 < glyphs[index].resolve.count ? step + 1 : nil
            }
            let glyph = glyphs[index]
            if glyph.visible && (1...canvas.rows).contains(glyph.coordinate.row) {
                frame[column: glyph.coordinate.column, row: glyph.coordinate.row] = .init(codepoint: glyph.symbol,
                    foreground: glyph.foreground, background: glyph.foreground == 0 ? 0xFFFF_FFFE : 0)
            }
        }
        complete = !work
        return complete ? .complete : .running
    }

    private mutating func randomSymbol() -> UInt32 {
        options.rainSymbols[rng.integer(in: options.rainSymbols.indices)].unicodeScalars.first!.value
    }
    private mutating func randomColor() -> UInt32 { Self.rgb(colors[rng.integer(in: colors.indices)]) }
    private static func rgb(_ color: Color) -> UInt32 { UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue) }
}
