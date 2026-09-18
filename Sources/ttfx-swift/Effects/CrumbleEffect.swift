import Foundation
import TTFXCore

public struct CrumbleEffect: Effect {
    public struct Configuration: Sendable {
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            finalGradientStops: [Color] = [Color(hex: "5CE1FF"), Color(hex: "FF8C00")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .diagonal
        ) {
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum Stage { case falling, vacuuming, resetting, complete }
    private enum Scene { case initial, weaken, dust, flash, strengthen }

    private struct Glyph {
        let characterID: Int
        let inputCoordinate: Coordinate
        let symbol: UInt32
        let weakColor: UInt32
        let dustColor: UInt32
        let weakenColors: [UInt32]
        let flashColors: [UInt32]
        let strengthenColors: [UInt32]
        let dustSymbols: [UInt32]
        var coordinate: Coordinate
        var layer = 0
        var visible = true
        var scene: Scene = .initial
        var sceneIndex = 0
        var sceneTicksRemaining = 1
        var path: PathState?
        var active = false
        var inputPathCompletionPending = false
        var rendered: (symbol: UInt32, color: UInt32)?

        var foreground: UInt32 {
            switch scene {
            case .initial: weakColor
            case .weaken: weakenColors[sceneIndex]
            case .dust: dustColor
            case .flash: flashColors[sceneIndex]
            case .strengthen: strengthenColors[sceneIndex]
            }
        }

        var codepoint: UInt32 {
            if scene == .dust { return dustSymbols[min(sceneIndex, dustSymbols.count - 1)] }
            return symbol
        }
    }

    private struct PathState {
        enum Kind { case fall, top, input }
        let kind: Kind
        let start: Coordinate
        let end: Coordinate
        let control: Coordinate?
        let easing: Easing?
        let steps: Int
        var step = 0
    }

    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var pending: [Int] = []
    private var unvacuumed: [Int] = []
    private var stage: Stage = .falling
    private var fallDelay = 12
    private var maxFallDelay = 12
    private var minFallDelay = 9
    private var fallGroupMaxSize = 1
    private var reset = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, crumbleConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        crumbleConfiguration: Configuration
    ) {
        self.canvas = canvas
        options = crumbleConfiguration
        rng = configuration.makeRNG(seed: seed)
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard stage != .complete else { return .complete }

        switch stage {
        case .falling:
            if !pending.isEmpty {
                if fallDelay == 0 {
                    let groupSize = rng.integer(in: 1...fallGroupMaxSize)
                    for _ in 0..<groupSize {
                        guard !pending.isEmpty else { break }
                        let index = pending.removeFirst()
                        activateWeaken(index)
                    }
                    fallDelay = rng.integer(in: minFallDelay...maxFallDelay)
                    if rng.integer(in: 1...10) > 4 {
                        fallGroupMaxSize += 1
                        minFallDelay = max(0, minFallDelay - 1)
                        maxFallDelay = max(0, maxFallDelay - 1)
                    }
                } else {
                    fallDelay -= 1
                }
            }
            if pending.isEmpty && !glyphs.contains(where: \ .active) { stage = .vacuuming }
        case .vacuuming:
            if !unvacuumed.isEmpty {
                for _ in 0..<rng.integer(in: 3...10) {
                    guard !unvacuumed.isEmpty else { break }
                    activateTop(unvacuumed.removeFirst())
                }
            }
            if !glyphs.contains(where: \ .active) { stage = .resetting }
        case .resetting:
            if !reset {
                for index in topToBottomOrder() { activateInput(index) }
                reset = true
            }
            if !glyphs.contains(where: \ .active) { stage = .complete }
        case .complete:
            break
        }

        updateActivePaths()
        updateActiveScenes()
        render(into: &frame)
        pruneInactiveGlyphs()
        return stage == .complete ? .complete : .running
    }

    private mutating func build(input: InputText) {
        var created: [(characterID: Int, symbol: UInt32, coordinate: Coordinate)] = []
        for (index, pair) in zip(input.scalars, input.positions).enumerated() where pair.0 != 32 {
            created.append((index, pair.0, Coordinate(column: pair.1.column, row: pair.1.row)))
        }
        guard !created.isEmpty else {
            stage = .complete
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
        let dustSymbols = ["*", ".", ","].map { $0.unicodeScalars.first!.value }

        glyphs = Array(repeating: placeholderGlyph(), count: created.count)
        for sourceIndex in created.indices.sorted(by: { lhs, rhs in
            let a = created[lhs].coordinate
            let b = created[rhs].coordinate
            if a.row != b.row { return a.row > b.row }
            return a.column < b.column
        }) {
            let source = created[sourceIndex]
            let finalColor = finalColors[source.coordinate]!
            let weak = adjustBrightness(finalColor, factor: 0.65)
            let dust = adjustBrightness(finalColor, factor: 0.55)
            let weaken = try! Gradient(stops: [weak, dust], steps: 9).spectrum.map(rgb)
            let flash = try! Gradient(stops: [finalColor, Color(hex: "ffffff")], steps: 6).spectrum.map(rgb)
            let strengthen = try! Gradient(stops: [Color(hex: "ffffff"), finalColor], steps: 9).spectrum.map(rgb)
            let chosenDust = (0..<5).map { _ in dustSymbols[rng.integer(in: 0..<dustSymbols.count)] }
            glyphs[sourceIndex] = Glyph(
                characterID: source.characterID,
                inputCoordinate: source.coordinate,
                symbol: source.symbol,
                weakColor: rgb(weak),
                dustColor: rgb(dust),
                weakenColors: weaken,
                flashColors: flash,
                strengthenColors: strengthen,
                dustSymbols: chosenDust,
                coordinate: source.coordinate
            )
        }
        pending = topToBottomOrder()
        rng.shuffle(&pending)
        unvacuumed = created.indices.sorted()
        rng.shuffle(&unvacuumed)
    }

    private mutating func activateWeaken(_ index: Int) {
        glyphs[index].scene = .weaken
        glyphs[index].sceneIndex = 0
        glyphs[index].sceneTicksRemaining = 4
        glyphs[index].active = true
    }

    private mutating func activateTop(_ index: Int) {
        let start = glyphs[index].coordinate
        let end = Coordinate(column: glyphs[index].inputCoordinate.column, row: canvas.rows)
        let control = Coordinate(column: centered(canvas.columns), row: centered(canvas.rows))
        glyphs[index].path = makePath(kind: .top, start: start, end: end, control: control, easing: .outQuint, speed: 1.0)
        glyphs[index].active = true
    }

    private mutating func activateInput(_ index: Int) {
        let start = glyphs[index].coordinate
        glyphs[index].path = makePath(kind: .input, start: start, end: glyphs[index].inputCoordinate, control: nil, easing: nil, speed: 1.0)
        glyphs[index].active = true
    }

    private func makePath(kind: PathState.Kind, start: Coordinate, end: Coordinate, control: Coordinate?, easing: Easing?, speed: Double) -> PathState {
        let length = control.map { Geometry.bezierLength(from: start, controls: [$0], to: end) } ?? Geometry.lineLength(from: start, to: end)
        return PathState(kind: kind, start: start, end: end, control: control, easing: easing, steps: PyCompat.roundHalfEven(length / speed))
    }

    private mutating func updateActivePaths() {
        for index in glyphs.indices where glyphs[index].active {
            updatePath(index)
        }
    }

    private mutating func updateActiveScenes() {
        for index in glyphs.indices where glyphs[index].active {
            updateScene(index)
        }
    }

    private mutating func pruneInactiveGlyphs() {
        for index in glyphs.indices where glyphs[index].active {
            if glyphs[index].path == nil && !sceneIsActive(glyphs[index]) {
                glyphs[index].active = false
            }
        }
    }

    private mutating func updatePath(_ index: Int) {
        guard var path = glyphs[index].path else { return }
        if path.steps == 0 {
            glyphs[index].coordinate = path.end
            completePath(path.kind, index: index)
            glyphs[index].path = nil
            return
        }
        path.step += 1
        let raw = Double(path.step) / Double(path.steps)
        let eased = path.easing?.value(at: raw) ?? raw
        if let control = path.control {
            glyphs[index].coordinate = Geometry.coordinateOnBezier(from: path.start, controls: [control], to: path.end, t: eased)
        } else {
            glyphs[index].coordinate = Geometry.coordinateOnLine(from: path.start, to: path.end, t: eased)
        }
        if path.step >= path.steps {
            completePath(path.kind, index: index)
            glyphs[index].path = nil
        } else {
            glyphs[index].path = path
        }
    }

    private mutating func completePath(_ kind: PathState.Kind, index: Int) {
        switch kind {
        case .fall:
            break
        case .top:
            break
        case .input:
            glyphs[index].inputPathCompletionPending = true
        }
    }

    private mutating func updateScene(_ index: Int) {
        if glyphs[index].inputPathCompletionPending {
            glyphs[index].inputPathCompletionPending = false
            glyphs[index].scene = .flash
            glyphs[index].sceneIndex = 0
            glyphs[index].sceneTicksRemaining = 4
        }

        glyphs[index].rendered = (glyphs[index].codepoint, glyphs[index].foreground)
        switch glyphs[index].scene {
        case .initial:
            return
        case .weaken, .flash, .strengthen:
            glyphs[index].sceneTicksRemaining -= 1
            guard glyphs[index].sceneTicksRemaining == 0 else { return }
            let colors = sceneColors(glyphs[index])
            if glyphs[index].sceneIndex + 1 < colors.count {
                glyphs[index].sceneIndex += 1
                glyphs[index].sceneTicksRemaining = 4
            } else {
                if glyphs[index].scene == .weaken {
                    glyphs[index].layer = 1
                    glyphs[index].scene = .dust
                    glyphs[index].sceneIndex = 0
                    glyphs[index].sceneTicksRemaining = 1
                    glyphs[index].path = makePath(
                        kind: .fall,
                        start: glyphs[index].coordinate,
                        end: Coordinate(column: glyphs[index].inputCoordinate.column, row: 1),
                        control: nil,
                        easing: .outBounce,
                        speed: 0.65
                    )
                    glyphs[index].rendered = (glyphs[index].codepoint, glyphs[index].foreground)
                } else if glyphs[index].scene == .flash {
                    glyphs[index].scene = .strengthen
                    glyphs[index].sceneIndex = 0
                    glyphs[index].sceneTicksRemaining = 4
                    glyphs[index].rendered = (glyphs[index].codepoint, glyphs[index].foreground)
                }
            }
        case .dust:
            if let path = glyphs[index].path, path.kind == .fall {
                let total = Geometry.lineLength(from: path.start, to: path.end)
                let fraction = path.steps == 0 ? 1 : Double(path.step) / Double(path.steps)
                let reached = (path.easing?.value(at: fraction) ?? fraction) * total
                let progress = max(max(total, 1) - max(total - reached, 1), 1) / max(total, 1)
                glyphs[index].sceneIndex = min(4, max(0, PyCompat.roundHalfEven(progress * 4)))
            } else if glyphs[index].path == nil {
                glyphs[index].sceneIndex = glyphs[index].dustSymbols.count - 1
            }
            glyphs[index].rendered = (glyphs[index].codepoint, glyphs[index].foreground)
        }
    }

    private func sceneIsActive(_ glyph: Glyph) -> Bool {
        switch glyph.scene {
        case .initial, .dust: return glyph.path != nil
        case .weaken, .flash: return true
        case .strengthen: return glyph.sceneTicksRemaining > 0 || glyph.sceneIndex + 1 < glyph.strengthenColors.count
        }
    }

    private func sceneColors(_ glyph: Glyph) -> [UInt32] {
        switch glyph.scene {
        case .weaken: glyph.weakenColors
        case .flash: glyph.flashColors
        case .strengthen: glyph.strengthenColors
        default: [glyph.foreground]
        }
    }

    private func topToBottomOrder() -> [Int] {
        glyphs.indices.sorted {
            let lhs = glyphs[$0].inputCoordinate
            let rhs = glyphs[$1].inputCoordinate
            if lhs.row != rhs.row { return lhs.row > rhs.row }
            return lhs.column < rhs.column
        }
    }

    private func render(into frame: inout Frame) {
        frame.withMutableCells { cells in
            for index in cells.indices { cells[index] = .blank }
            var winners: [Int: (layer: Int, id: Int, glyph: Glyph)] = [:]
            for glyph in glyphs where glyph.visible {
                guard (1...canvas.columns).contains(glyph.coordinate.column),
                      (1...canvas.rows).contains(glyph.coordinate.row)
                else { continue }
                let cellIndex = (canvas.rows - glyph.coordinate.row) * canvas.columns + glyph.coordinate.column - 1
                if let winner = winners[cellIndex], winner.layer > glyph.layer { continue }
                winners[cellIndex] = (glyph.layer, glyph.characterID, glyph)
            }
            for (index, winner) in winners {
                cells[index] = .init(codepoint: winner.glyph.rendered?.symbol ?? winner.glyph.codepoint, foreground: winner.glyph.rendered?.color ?? winner.glyph.foreground, background: 0)
            }
        }
    }

    private func centered(_ size: Int) -> Int {
        var center = max(PyCompat.floorDivide(size, 2), 1)
        if !size.isMultiple(of: 2), size > 1 { center += 1 }
        return center
    }

    private func placeholderGlyph() -> Glyph {
        Glyph(
            characterID: 0,
            inputCoordinate: Coordinate(column: 1, row: 1),
            symbol: 32,
            weakColor: 0,
            dustColor: 0,
            weakenColors: [0],
            flashColors: [0],
            strengthenColors: [0],
            dustSymbols: [32],
            coordinate: Coordinate(column: 1, row: 1)
        )
    }

    private func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }

    private func adjustBrightness(_ color: Color, factor: Double) -> Color {
        let red = Double(color.red) / 255.0
        let green = Double(color.green) / 255.0
        let blue = Double(color.blue) / 255.0
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        var lightness = (maxValue + minValue) / 2.0
        let threshold = 0.5
        let hue: Double
        let saturation: Double
        if maxValue == minValue {
            hue = 0
            saturation = 0
        } else {
            let diff = maxValue - minValue
            saturation = lightness > threshold ? diff / (2.0 - maxValue - minValue) : diff / (maxValue + minValue)
            var rawHue: Double
            if maxValue == red {
                rawHue = (green - blue) / diff + (green < blue ? 6.0 : 0.0)
            } else if maxValue == green {
                rawHue = (blue - red) / diff + 2.0
            } else {
                rawHue = (red - green) / diff + 4.0
            }
            hue = rawHue / 6.0
        }
        lightness = min(max(lightness * factor, 0), 1)
        let adjusted: (Double, Double, Double)
        if saturation == 0 {
            adjusted = (lightness, lightness, lightness)
        } else {
            let intensity = lightness < threshold ? lightness * (1.0 + saturation) : lightness + saturation - lightness * saturation
            let scaled = 2.0 * lightness - intensity
            adjusted = (
                hueToRGB(scaled: scaled, intensity: intensity, hue: hue + 1.0 / 3.0),
                hueToRGB(scaled: scaled, intensity: intensity, hue: hue),
                hueToRGB(scaled: scaled, intensity: intensity, hue: hue - 1.0 / 3.0)
            )
        }
        return Color(hex: String(format: "%02x%02x%02x",
            min(max(PyCompat.roundHalfEven(adjusted.0 * 255.0), 0), 255),
            min(max(PyCompat.roundHalfEven(adjusted.1 * 255.0), 0), 255),
            min(max(PyCompat.roundHalfEven(adjusted.2 * 255.0), 0), 255)
        ))
    }

    private func hueToRGB(scaled: Double, intensity: Double, hue originalHue: Double) -> Double {
        var hue = originalHue
        if hue < 0 { hue += 1 }
        if hue > 1 { hue -= 1 }
        if hue < 1.0 / 6.0 { return scaled + (intensity - scaled) * 6.0 * hue }
        if hue < 1.0 / 2.0 { return intensity }
        if hue < 2.0 / 3.0 { return scaled + (intensity - scaled) * (2.0 / 3.0 - hue) * 6.0 }
        return scaled
    }
}
