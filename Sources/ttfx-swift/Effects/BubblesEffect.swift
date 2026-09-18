import TTFXCore

public struct BubblesEffect: Effect {
    public enum PopCondition: Sendable {
        case row
        case bottom
        case anywhere
    }

    public struct Configuration: Sendable {
        public var rainbow: Bool
        public var bubbleColors: [Color]
        public var popColor: Color
        public var bubbleSpeed: Double
        public var bubbleDelay: Int
        public var popCondition: PopCondition
        public var movementEasing: Easing
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            rainbow: Bool = false,
            bubbleColors: [Color] = [
                Color(hex: "d33aff"),
                Color(hex: "7395c4"),
                Color(hex: "43c2a7"),
                Color(hex: "02ff7f")
            ],
            popColor: Color = Color(hex: "ffffff"),
            bubbleSpeed: Double = 0.5,
            bubbleDelay: Int = 20,
            popCondition: PopCondition = .row,
            movementEasing: Easing = .inOutSine,
            finalGradientStops: [Color] = [Color(hex: "d33aff"), Color(hex: "02ff7f")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .diagonal
        ) {
            precondition(!bubbleColors.isEmpty, "bubble colors must not be empty")
            precondition(bubbleSpeed > 0, "bubble speed must be positive")
            precondition(bubbleDelay >= 0, "bubble delay must not be negative")
            self.rainbow = rainbow
            self.bubbleColors = bubbleColors
            self.popColor = popColor
            self.bubbleSpeed = bubbleSpeed
            self.bubbleDelay = bubbleDelay
            self.popCondition = popCondition
            self.movementEasing = movementEasing
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum ScenePhase {
        case sheen
        case pop1
        case pop2
        case final(index: Int)
        case done
    }

    private struct ScenePlay {
        var phase: ScenePhase
        var ticksElapsed = 0
        var looping = false
        var sheenIndex = 0
    }

    private struct MotionPath {
        var start: Coordinate
        var target: Coordinate
        var speed: Double
        var easing: Easing?
        var step = 0
        var maxSteps = 0
        var distance = 0.0
        var kind: PathKind = .anchor
        var active = false
    }

    private enum PathKind {
        case anchor
        case popOut
        case final
    }

    private struct Glyph {
        let characterID: Int
        let inputCoordinate: Coordinate
        let inputSymbol: UInt32
        var coordinate: Coordinate
        var layer = 1
        var visible = false
        var sheenColors: [UInt32] = []
        var sheenDuration = 1
        var finalColors: [UInt32] = []
        var scene = ScenePlay(phase: .sheen)
        var path: MotionPath?
        var symbol: UInt32
        var foreground: UInt32
    }

    private struct Bubble {
        var characterIndices: [Int]
        var radius: Int
        var anchor: Coordinate
        var anchorPath: MotionPath
        var lowestRow: Int
        var landed = false
    }

    private static let popDuration = 9
    private static let finalFrameDuration = 6
    private static let finalGradientSteps = 8
    private static let rainbowStops: [Color] = [
        Color(hex: "e81416"),
        Color(hex: "ffa500"),
        Color(hex: "faeb36"),
        Color(hex: "79c314"),
        Color(hex: "487de7"),
        Color(hex: "4b369d"),
        Color(hex: "70369d")
    ]

    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var pendingBubbles: [Bubble] = []
    private var animatingBubbles: [Bubble] = []
    private var active: [Int] = []
    private var stepsSinceLastBubble = 0
    private var isComplete = false
    private let rainbowSpectrum: [Color]
    private let popColorRGB: UInt32

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, bubblesConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        bubblesConfiguration: Configuration
    ) {
        self.canvas = canvas
        options = bubblesConfiguration
        rng = configuration.makeRNG(seed: seed)
        rainbowSpectrum = (try! Gradient(stops: Self.rainbowStops, steps: 5)).spectrum
        popColorRGB = Self.rgb(bubblesConfiguration.popColor)
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        if !hasPendingWork {
            isComplete = true
            return .complete
        }

        if !pendingBubbles.isEmpty && stepsSinceLastBubble >= options.bubbleDelay {
            let bubble = pendingBubbles.removeFirst()
            for index in bubble.characterIndices {
                glyphs[index].visible = true
            }
            animatingBubbles.append(bubble)
            stepsSinceLastBubble = 0
        }
        stepsSinceLastBubble += 1

        var stillFloating: [Bubble] = []
        stillFloating.reserveCapacity(animatingBubbles.count)
        for bubble in animatingBubbles {
            if bubble.landed {
                pop(bubble)
                active.append(contentsOf: bubble.characterIndices)
            } else {
                stillFloating.append(bubble)
            }
        }
        animatingBubbles = stillFloating

        for index in animatingBubbles.indices {
            moveBubble(at: index)
        }

        // QUIRK(src/engine/ctx.rs:681-692; ordering-inventory.md): popped characters
        // tick in canonical ascending character_id order, then inactive ones drop.
        active.sort { glyphs[$0].characterID < glyphs[$1].characterID }
        for glyphIndex in active {
            stepPoppedGlyph(at: glyphIndex)
        }
        active = active.filter { glyph in
            let item = glyphs[glyph]
            let pathActive = item.path?.active == true
            return pathActive || !sceneIsComplete(item.scene)
        }

        render(into: &frame)

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
            // every parsed scalar, including later-dropped spaces.
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
        let finalColors = Dictionary(uniqueKeysWithValues: mapping.entries.map { ($0.coordinate, Self.rgb($0.color)) })

        glyphs = created.map { source in
            let mapped = color(finalColors[source.coordinate]!)
            let fade = try! Gradient(stops: [options.popColor, mapped], steps: Self.finalGradientSteps).spectrum.map(Self.rgb)
            return Glyph(
                characterID: source.characterID,
                inputCoordinate: source.coordinate,
                inputSymbol: source.symbol,
                coordinate: source.coordinate,
                finalColors: fade,
                symbol: source.symbol,
                foreground: 0
            )
        }

        // QUIRK(src/engine/terminal.rs:441-449; plan.md): RowBottomToTop buckets by
        // input row from the canvas bottom without reversing the low-to-high walk.
        var leftover = created.indices.sorted {
            let lhs = created[$0].coordinate
            let rhs = created[$1].coordinate
            if lhs.row != rhs.row { return lhs.row < rhs.row }
            return lhs.column < rhs.column
        }

        while !leftover.isEmpty {
            let group: [Int]
            if leftover.count < 5 {
                group = leftover
                leftover.removeAll()
            } else {
                // QUIRK(src/effects/bubbles.rs:473; plan.md): randint(a, b) is inclusive
                // on both ends, including the min(len, 20) upper bound.
                let count = rng.integer(in: 5...min(leftover.count, 20))
                group = Array(leftover.prefix(count))
                leftover.removeFirst(count)
            }
            let origin = Coordinate(
                column: rng.integer(in: 1...canvas.columns),
                row: canvas.rows + 10
            )
            pendingBubbles.append(makeBubble(origin: origin, characterIndices: group))
        }
    }

    private mutating func makeBubble(origin: Coordinate, characterIndices: [Int]) -> Bubble {
        let radius = max(characterIndices.count / 5, 1)
        let lowestRow: Int
        switch options.popCondition {
        case .row:
            lowestRow = characterIndices.map { glyphs[$0].inputCoordinate.row }.min()!
        case .bottom, .anywhere:
            lowestRow = 1
        }
        var bubble = Bubble(
            characterIndices: characterIndices,
            radius: radius,
            anchor: origin,
            anchorPath: MotionPath(start: origin, target: origin, speed: options.bubbleSpeed),
            lowestRow: lowestRow
        )
        placeBubbleCharacters(&bubble, unique: false)
        bubble.landed = false
        let waypointColumn = rng.integer(in: 1...canvas.columns)
        bubble.anchorPath = activatedPath(
            from: origin,
            to: Coordinate(column: waypointColumn, row: lowestRow),
            speed: options.bubbleSpeed,
            easing: nil,
            kind: .anchor
        )
        if options.rainbow {
            var spectrum = rainbowSpectrum
            var gradientOffset = 0
            for index in characterIndices {
                glyphs[index].sheenColors = spectrum.map(Self.rgb)
                glyphs[index].sheenDuration = 4
                glyphs[index].scene = ScenePlay(phase: .sheen, looping: true)
                glyphs[index].symbol = glyphs[index].inputSymbol
                glyphs[index].foreground = glyphs[index].sheenColors[0]
                gradientOffset += 2
                gradientOffset %= spectrum.count
                spectrum = Array(spectrum[gradientOffset...]) + Array(spectrum[..<gradientOffset])
            }
        } else {
            let bubbleColor = options.bubbleColors[rng.integer(in: 0..<options.bubbleColors.count)]
            let colorRGB = Self.rgb(bubbleColor)
            for index in characterIndices {
                glyphs[index].sheenColors = [colorRGB]
                glyphs[index].sheenDuration = 1
                glyphs[index].scene = ScenePlay(phase: .sheen)
                glyphs[index].symbol = glyphs[index].inputSymbol
                glyphs[index].foreground = colorRGB
            }
        }
        return bubble
    }

    private mutating func placeBubbleCharacters(_ bubble: inout Bubble, unique: Bool) {
        let points = Geometry.coordinatesOnCircle(
            origin: bubble.anchor,
            radius: bubble.radius,
            limit: bubble.characterIndices.count,
            unique: unique
        )
        for (offset, glyphIndex) in bubble.characterIndices.enumerated() {
            guard offset < points.count else { break }
            glyphs[glyphIndex].coordinate = points[offset]
            if points[offset].row == bubble.lowestRow {
                bubble.landed = true
            }
        }
        if options.popCondition == .anywhere, rng.random() < 0.002 {
            bubble.landed = true
        }
    }

    private mutating func pop(_ bubble: Bubble) {
        let points = Geometry.coordinatesOnCircle(
            origin: bubble.anchor,
            radius: bubble.radius + 3,
            limit: bubble.characterIndices.count,
            unique: true
        )
        for (offset, glyphIndex) in bubble.characterIndices.enumerated() {
            guard offset < points.count else { break }
            glyphs[glyphIndex].path = activatedPath(
                from: glyphs[glyphIndex].coordinate,
                to: points[offset],
                speed: 0.3,
                easing: .outExpo,
                kind: .popOut
            )
        }
        for glyphIndex in bubble.characterIndices {
            activateScene(.pop1, for: glyphIndex)
        }
    }

    private mutating func moveBubble(at index: Int) {
        var path = animatingBubbles[index].anchorPath
        stepPath(&path)
        animatingBubbles[index].anchorPath = path
        animatingBubbles[index].anchor = currentPathCoordinate(path)
        var bubble = animatingBubbles[index]
        placeBubbleCharacters(&bubble, unique: false)
        animatingBubbles[index] = bubble
        for glyphIndex in bubble.characterIndices {
            stepSheen(at: glyphIndex)
        }
    }

    private mutating func stepPoppedGlyph(at index: Int) {
        if glyphs[index].path != nil {
            stepGlyphPath(at: index)
        }
        stepPoppedScene(at: index)
    }

    private mutating func stepGlyphPath(at index: Int) {
        guard var path = glyphs[index].path, path.active else { return }
        let completed = stepPath(&path)
        glyphs[index].coordinate = currentPathCoordinate(path)
        if completed {
            switch path.kind {
            case .popOut:
                // QUIRK(src/effects/bubbles.rs:277-283; plan.md): PathComplete on
                // pop_out activates the named final path in the same tick.
                glyphs[index].path = activatedPath(
                    from: glyphs[index].coordinate,
                    to: glyphs[index].inputCoordinate,
                    speed: 0.3,
                    easing: .inOutExpo,
                    kind: .final
                )
            case .final:
                glyphs[index].layer = 0
                glyphs[index].path = path
                glyphs[index].path?.active = false
            case .anchor:
                glyphs[index].path = path
            }
        } else {
            glyphs[index].path = path
        }
    }

    @discardableResult
    private mutating func stepPath(_ path: inout MotionPath) -> Bool {
        if !path.active { return false }
        if path.maxSteps == 0 || path.distance == 0 {
            path.active = false
            return true
        }
        if path.step >= path.maxSteps {
            path.active = false
            return true
        }
        path.step += 1
        if path.step == path.maxSteps {
            path.active = false
            return true
        }
        return false
    }

    private func currentPathCoordinate(_ path: MotionPath) -> Coordinate {
        if path.maxSteps == 0 || path.distance == 0 || path.step >= path.maxSteps {
            return path.target
        }
        let ratio = Double(path.step) / Double(path.maxSteps)
        let distanceFactor = path.easing?.value(at: ratio) ?? ratio
        let traveled = distanceFactor * path.distance
        let t: Double
        if path.easing != nil {
            t = traveled / path.distance
        } else {
            t = min(1, traveled / path.distance)
        }
        return Geometry.coordinateOnLine(from: path.start, to: path.target, t: t)
    }

    private func activatedPath(
        from origin: Coordinate,
        to target: Coordinate,
        speed: Double,
        easing: Easing?,
        kind: PathKind
    ) -> MotionPath {
        let distance = Geometry.lineLength(from: origin, to: target)
        return MotionPath(
            start: origin,
            target: target,
            speed: speed,
            easing: easing,
            step: 0,
            maxSteps: PyCompat.roundHalfEven(distance / speed),
            distance: distance,
            kind: kind,
            active: true
        )
    }

    private mutating func activateScene(_ phase: ScenePhase, for index: Int) {
        glyphs[index].scene = ScenePlay(phase: phase)
        switch phase {
        case .sheen:
            glyphs[index].symbol = glyphs[index].inputSymbol
            glyphs[index].foreground = glyphs[index].sheenColors.first ?? 0
        case .pop1:
            glyphs[index].symbol = 42
            glyphs[index].foreground = popColorRGB
        case .pop2:
            glyphs[index].symbol = 39
            glyphs[index].foreground = popColorRGB
        case .final(let colorIndex):
            glyphs[index].symbol = glyphs[index].inputSymbol
            glyphs[index].foreground = glyphs[index].finalColors[min(colorIndex, glyphs[index].finalColors.count - 1)]
        case .done:
            glyphs[index].symbol = glyphs[index].inputSymbol
            glyphs[index].foreground = glyphs[index].finalColors.last ?? popColorRGB
        }
    }

    private mutating func stepSheen(at index: Int) {
        guard case .sheen = glyphs[index].scene.phase else { return }
        let duration = glyphs[index].sheenDuration
        let colors = glyphs[index].sheenColors
        guard !colors.isEmpty else { return }
        // Paint-then-pop: return the current sheen visual, then retire the frame.
        glyphs[index].symbol = glyphs[index].inputSymbol
        glyphs[index].foreground = colors[glyphs[index].scene.sheenIndex]
        glyphs[index].scene.ticksElapsed += 1
        if glyphs[index].scene.ticksElapsed == duration {
            glyphs[index].scene.ticksElapsed = 0
            let next = glyphs[index].scene.sheenIndex + 1
            if next < colors.count {
                glyphs[index].scene.sheenIndex = next
            } else if glyphs[index].scene.looping {
                glyphs[index].scene.sheenIndex = 0
            } else {
                glyphs[index].scene.phase = .done
            }
        }
    }

    private mutating func stepPoppedScene(at index: Int) {
        switch glyphs[index].scene.phase {
        case .sheen:
            stepSheen(at: index)
        case .pop1:
            glyphs[index].symbol = 42
            glyphs[index].foreground = popColorRGB
            glyphs[index].scene.ticksElapsed += 1
            if glyphs[index].scene.ticksElapsed == Self.popDuration {
                activateScene(.pop2, for: index)
            }
        case .pop2:
            glyphs[index].symbol = 39
            glyphs[index].foreground = popColorRGB
            glyphs[index].scene.ticksElapsed += 1
            if glyphs[index].scene.ticksElapsed == Self.popDuration {
                activateScene(.final(index: 0), for: index)
            }
        case .final(let colorIndex):
            glyphs[index].symbol = glyphs[index].inputSymbol
            glyphs[index].foreground = glyphs[index].finalColors[min(colorIndex, glyphs[index].finalColors.count - 1)]
            glyphs[index].scene.ticksElapsed += 1
            if glyphs[index].scene.ticksElapsed == Self.finalFrameDuration {
                glyphs[index].scene.ticksElapsed = 0
                if colorIndex + 1 < glyphs[index].finalColors.count {
                    // Paint-then-pop: keep this tick's color; advance the index for the next tick.
                    glyphs[index].scene.phase = .final(index: colorIndex + 1)
                } else {
                    glyphs[index].scene.phase = .done
                }
            }
        case .done:
            break
        }
    }

    private func sceneIsComplete(_ scene: ScenePlay) -> Bool {
        if case .done = scene.phase { return true }
        return false
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
                if let winner = winners[cellIndex], (winner.layer, winner.characterID) > (glyph.layer, glyph.characterID) {
                    continue
                }
                winners[cellIndex] = (glyph.layer, glyph.characterID, (glyph.symbol, glyph.foreground))
            }
            for (index, winner) in winners {
                cells[index] = .init(codepoint: winner.visual.symbol, foreground: winner.visual.foreground, background: 0)
            }
        }
    }

    private var hasPendingWork: Bool {
        !pendingBubbles.isEmpty || !animatingBubbles.isEmpty || !active.isEmpty
    }

    private func color(_ word: UInt32) -> Color {
        Color(hex: String(format: "%06x", word))
    }

    private static func rgb(_ color: Color) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }
}

