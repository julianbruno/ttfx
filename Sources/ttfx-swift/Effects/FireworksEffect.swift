import TTFXCore

public struct FireworksEffect: Effect {
    public struct Configuration: Sendable {
        public var explodeAnywhere: Bool
        public var fireworkColors: [Color]
        public var fireworkSymbol: String
        public var fireworkVolume: Double
        public var launchDelay: Int
        public var explodeDistance: Double
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            explodeAnywhere: Bool = false,
            fireworkColors: [Color] = [
                Color(hex: "88F7E2"),
                Color(hex: "44D492"),
                Color(hex: "F5EB67"),
                Color(hex: "FFA15C"),
                Color(hex: "FA233E")
            ],
            fireworkSymbol: String = "o",
            fireworkVolume: Double = 0.05,
            launchDelay: Int = 45,
            explodeDistance: Double = 0.2,
            finalGradientStops: [Color] = [Color(hex: "8A008A"), Color(hex: "00D1FF"), Color(hex: "FFFFFF")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .horizontal
        ) {
            precondition(!fireworkColors.isEmpty, "firework colors must not be empty")
            precondition(fireworkVolume >= 0, "firework volume must not be negative")
            precondition(launchDelay >= 0, "launch delay must not be negative")
            precondition(explodeDistance >= 0, "explode distance must not be negative")
            self.explodeAnywhere = explodeAnywhere
            self.fireworkColors = fireworkColors
            self.fireworkSymbol = fireworkSymbol
            self.fireworkVolume = fireworkVolume
            self.launchDelay = launchDelay
            self.explodeDistance = explodeDistance
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private enum PathKind {
        case apex
        case explode
        case input
        case finished
    }

    private enum SceneKind {
        case launch
        case bloom
        case fall
        case done
    }

    private struct Segment {
        var start: Coordinate
        var end: Coordinate
        var controls: [Coordinate]
        var distance: Double
    }

    private struct MotionPath {
        var speed: Double
        var easing: Easing?
        var holdTime: Int
        var segments: [Segment]
        var totalDistance: Double
        var currentStep = 0
        var maxSteps = 0
        var holdRemaining: Int
        var lastDistance = 0.0

        mutating func activate(from origin: Coordinate) {
            guard let firstWaypoint = firstWaypoint else { return }
            let originDistance = firstWaypointControls.isEmpty
                ? Geometry.lineLength(from: origin, to: firstWaypoint)
                : Geometry.bezierLength(from: origin, controls: firstWaypointControls, to: firstWaypoint)
            let originSegment = Segment(
                start: origin,
                end: firstWaypoint,
                controls: firstWaypointControls,
                distance: originDistance
            )
            if let existing = originSegmentMarker, !segments.isEmpty {
                totalDistance -= existing
                segments[0] = originSegment
            } else {
                segments.insert(originSegment, at: 0)
            }
            originSegmentMarker = originDistance
            totalDistance += originDistance
            currentStep = 0
            holdRemaining = holdTime
            lastDistance = 0
            maxSteps = PyCompat.roundHalfEven(totalDistance / speed)
        }

        var firstWaypoint: Coordinate?
        var firstWaypointControls: [Coordinate] = []
        var originSegmentMarker: Double?

        mutating func move() -> (coordinate: Coordinate, completed: Bool) {
            guard let last = segments.last else { return (Coordinate(column: 1, row: 1), true) }
            if maxSteps == 0 || currentStep >= maxSteps || totalDistance == 0 {
                return finishHold(at: last.end)
            }
            currentStep += 1
            let ratio = Double(currentStep) / Double(maxSteps)
            var distanceToTravel = (easing?.value(at: ratio) ?? ratio) * totalDistance
            lastDistance = distanceToTravel
            var activeIndex: Int?
            for index in segments.indices {
                if distanceToTravel <= segments[index].distance {
                    activeIndex = index
                    break
                }
                distanceToTravel -= segments[index].distance
            }
            let index = activeIndex ?? {
                distanceToTravel += segments[segments.count - 1].distance
                return segments.count - 1
            }()
            let segment = segments[index]
            let t: Double
            if segment.distance == 0 {
                t = 0
            } else if easing != nil {
                t = distanceToTravel / segment.distance
            } else {
                t = min(distanceToTravel / segment.distance, 1)
            }
            let coordinate = segment.controls.isEmpty
                ? Geometry.coordinateOnLine(from: segment.start, to: segment.end, t: t)
                : Geometry.coordinateOnBezier(from: segment.start, controls: segment.controls, to: segment.end, t: t)
            if currentStep == maxSteps {
                return finishHold(at: coordinate)
            }
            return (coordinate, false)
        }

        mutating func finishHold(at coordinate: Coordinate) -> (Coordinate, Bool) {
            if holdTime != 0 && holdRemaining == holdTime {
                holdRemaining -= 1
                return (coordinate, false)
            }
            if holdRemaining != 0 {
                holdRemaining -= 1
                return (coordinate, false)
            }
            return (coordinate, true)
        }
    }

    private struct Glyph {
        let characterID: Int
        let inputCoordinate: Coordinate
        let inputSymbol: UInt32
        let launchSymbol: UInt32
        var shellColor: UInt32
        let white: UInt32
        var bloomColors: [UInt32]
        var fallColors: [UInt32]
        var apex: MotionPath
        var explode: MotionPath
        var inputPath: MotionPath
        var coordinate: Coordinate
        var activePath = PathKind.apex
        var scene = SceneKind.launch
        var launchIndex = 0
        var launchTicks = 0
        var fallIndex = 0
        var fallTicks = 0
        var visible = false
        var layer = 0

        var isActive: Bool {
            activePath != .finished || scene != .done
        }

        var visual: (symbol: UInt32, foreground: UInt32) {
            switch scene {
            case .launch:
                return launchIndex == 0 ? (launchSymbol, shellColor) : (launchSymbol, white)
            case .bloom:
                let index = min(max(bloomColors.count - 1, 0), bloomColors.count - 1)
                return (inputSymbol, bloomColors[index])
            case .fall:
                return (inputSymbol, fallColors[min(fallIndex, fallColors.count - 1)])
            case .done:
                return (inputSymbol, fallColors[fallColors.count - 1])
            }
        }
    }

    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var shells: [[Int]] = []
    private var active: [Int] = []
    private var launchDelayRemaining = 0
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, fireworksConfiguration: .init())
    }

    public init(
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64,
        fireworksConfiguration: Configuration
    ) {
        self.canvas = canvas
        options = fireworksConfiguration
        rng = configuration.makeRNG(seed: seed)
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        if shells.isEmpty && active.isEmpty {
            isComplete = true
            return .complete
        }

        if !shells.isEmpty && launchDelayRemaining <= 0 {
            let group = shells.removeLast()
            for index in group {
                glyphs[index].visible = true
                active.append(index)
            }
            // QUIRK(src/effects/fireworks.rs:411-412; plan.md): delay is truncated toward zero.
            launchDelayRemaining = Int(Double(options.launchDelay) * rng.uniform(0.5, 1.5))
        }
        launchDelayRemaining -= 1

        active.sort()
        for index in active {
            move(index)
        }
        render(into: &frame)
        for index in active {
            stepScene(index)
        }
        active.removeAll { !glyphs[$0].isActive }

        if shells.isEmpty && active.isEmpty {
            isComplete = true
            return .complete
        }
        return .running
    }

    private mutating func build(input: InputText) {
        var created: [(characterID: Int, symbol: UInt32, coordinate: Coordinate)] = []
        for (index, pair) in zip(input.scalars, input.positions).enumerated() {
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

        let volume = max(1, PyCompat.roundHalfEven(options.fireworkVolume * Double(input.scalars.count)))
        let explodeDistance = min(15, max(1, PyCompat.roundHalfEven(Double(canvas.columns) * options.explodeDistance)))
        let launchSymbol = options.fireworkSymbol.unicodeScalars.first!.value
        let white = rgb(Color(hex: "FFFFFF"))

        let buildOrder = created.indices.sorted {
            let lhs = created[$0].coordinate
            let rhs = created[$1].coordinate
            if lhs.row != rhs.row { return lhs.row > rhs.row }
            return lhs.column < rhs.column
        }

        glyphs = Array(repeating: placeholderGlyph(), count: created.count)
        var currentShell: [Int] = []
        var originX = 0
        var origin = Coordinate(column: 0, row: 0)
        var explodeCoords: [Coordinate] = []

        for sourceIndex in buildOrder {
            let source = created[sourceIndex]
            if currentShell.count == volume || currentShell.isEmpty {
                originX = rng.integer(in: 0..<canvas.columns)
                shells.append(currentShell)
                currentShell = []
                let minRow = options.explodeAnywhere ? 1 : source.coordinate.row
                let originY = rng.integer(in: minRow..<(canvas.rows + 1))
                origin = Coordinate(column: originX, row: originY)
                explodeCoords = Geometry.coordinatesInEllipse(center: origin, diameter: explodeDistance)
            }

            let start = Coordinate(column: originX, row: 1)
            // QUIRK(src/effects/fireworks.rs:119-126; plan.md): Some(2) is path layer, hold is 0.
            var apex = makePath(speed: 0.35, easing: .outExpo, hold: 0, from: start, to: origin, controls: [])
            apex.activate(from: start)

            let explodeSpeed = rng.uniform(0.2, 0.4)
            let explodePoint = explodeCoords[rng.integer(in: 0..<explodeCoords.count)]
            let bloomControl = Geometry.extrapolateAlongRay(
                origin: origin,
                target: explodePoint,
                offsetFromTarget: Double(PyCompat.floorDivide(explodeDistance, 2))
            )
            let bloomPoint = Coordinate(column: bloomControl.column, row: max(1, bloomControl.row - 7))
            let explode = makePath(
                speed: explodeSpeed,
                easing: .outCirc,
                hold: 0,
                waypoints: [explodePoint, bloomPoint],
                controls: [[], [bloomControl]]
            )
            let inputPath = makePath(
                speed: 0.6,
                easing: .inOutQuart,
                hold: 0,
                from: bloomPoint,
                to: source.coordinate,
                controls: [Coordinate(column: bloomPoint.column, row: 1)]
            )

            glyphs[sourceIndex] = Glyph(
                characterID: source.characterID,
                inputCoordinate: source.coordinate,
                inputSymbol: source.symbol,
                launchSymbol: launchSymbol,
                shellColor: 0,
                white: white,
                bloomColors: [white],
                fallColors: [finalColors[source.coordinate]!],
                apex: apex,
                explode: explode,
                inputPath: inputPath,
                coordinate: start,
                layer: 2
            )
            currentShell.append(sourceIndex)
        }
        if !currentShell.isEmpty {
            shells.append(currentShell)
        }

        // QUIRK(src/effects/fireworks.rs:243-248; plan.md): one color per leftover shell, after waypoints.
        let whiteColor = Color(hex: "FFFFFF")
        for shell in shells {
            let shellColor = options.fireworkColors[rng.integer(in: 0..<options.fireworkColors.count)]
            let bloomSpectrum = try! Gradient(stops: [shellColor, whiteColor, shellColor], steps: 5).spectrum.map(rgb)
            for index in shell {
                let finalColor = color(glyphs[index].fallColors[0])
                let fallSpectrum = try! Gradient(stops: [shellColor, finalColor], steps: 15).spectrum.map(rgb)
                glyphs[index].shellColor = rgb(shellColor)
                glyphs[index].bloomColors = bloomSpectrum
                glyphs[index].fallColors = fallSpectrum.isEmpty ? [rgb(finalColor)] : fallSpectrum
            }
        }
    }

    private mutating func move(_ index: Int) {
        switch glyphs[index].activePath {
        case .apex:
            let result = glyphs[index].apex.move()
            glyphs[index].coordinate = result.coordinate
            if result.completed {
                glyphs[index].explode.activate(from: result.coordinate)
                glyphs[index].activePath = .explode
                glyphs[index].scene = .bloom
            }
        case .explode:
            let result = glyphs[index].explode.move()
            glyphs[index].coordinate = result.coordinate
            if result.completed {
                glyphs[index].inputPath.activate(from: result.coordinate)
                glyphs[index].activePath = .input
                glyphs[index].scene = .fall
                glyphs[index].fallIndex = 0
                glyphs[index].fallTicks = 0
            }
        case .input:
            let result = glyphs[index].inputPath.move()
            glyphs[index].coordinate = result.coordinate
            if result.completed {
                glyphs[index].activePath = .finished
                glyphs[index].layer = 0
            }
        case .finished:
            break
        }
    }

    private mutating func stepScene(_ index: Int) {
        switch glyphs[index].scene {
        case .launch:
            glyphs[index].launchTicks += 1
            let duration = glyphs[index].launchIndex == 0 ? 2 : 1
            if glyphs[index].launchTicks == duration {
                glyphs[index].launchTicks = 0
                glyphs[index].launchIndex = glyphs[index].launchIndex == 0 ? 1 : 0
            }
        case .bloom:
            let path = glyphs[index].activePath == .explode ? glyphs[index].explode : glyphs[index].apex
            let progress = Double(max(path.currentStep, 1)) / Double(max(path.maxSteps, 1))
            let last = max(glyphs[index].bloomColors.count - 1, 0)
            let frameIndex = min(max(PyCompat.roundHalfEven(Double(last) * progress), 0), last)
            glyphs[index].bloomColors = rotateBloom(glyphs[index].bloomColors, showing: frameIndex)
        case .fall:
            glyphs[index].fallTicks += 1
            if glyphs[index].fallTicks == 10 {
                glyphs[index].fallTicks = 0
                if glyphs[index].fallIndex + 1 < glyphs[index].fallColors.count {
                    glyphs[index].fallIndex += 1
                } else {
                    glyphs[index].scene = .done
                }
            }
        case .done:
            break
        }
    }

    private func rotateBloom(_ colors: [UInt32], showing index: Int) -> [UInt32] {
        colors
    }

    private func bloomVisual(for glyph: Glyph) -> UInt32 {
        let path = glyph.activePath == .explode ? glyph.explode : glyph.apex
        let progress = Double(max(path.currentStep, 1)) / Double(max(path.maxSteps, 1))
        let last = max(glyph.bloomColors.count - 1, 0)
        let frameIndex = min(max(PyCompat.roundHalfEven(Double(last) * progress), 0), last)
        return glyph.bloomColors[frameIndex]
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
                let visual: (UInt32, UInt32)
                if glyph.scene == .bloom {
                    visual = (glyph.inputSymbol, bloomVisual(for: glyph))
                } else {
                    visual = glyph.visual
                }
                if let winner = winners[cellIndex], (winner.layer, winner.characterID) > (glyph.layer, glyph.characterID) {
                    continue
                }
                winners[cellIndex] = (glyph.layer, glyph.characterID, visual)
            }
            for (index, winner) in winners {
                cells[index] = .init(codepoint: winner.visual.symbol, foreground: winner.visual.foreground, background: 0)
            }
        }
    }

    private func makePath(
        speed: Double,
        easing: Easing,
        hold: Int,
        from start: Coordinate,
        to end: Coordinate,
        controls: [Coordinate]
    ) -> MotionPath {
        var path = makePath(speed: speed, easing: easing, hold: hold, waypoints: [end], controls: [controls])
        path.activate(from: start)
        return path
    }

    private func makePath(
        speed: Double,
        easing: Easing,
        hold: Int,
        waypoints: [Coordinate],
        controls: [[Coordinate]]
    ) -> MotionPath {
        var segments: [Segment] = []
        var total = 0.0
        if waypoints.count >= 2 {
            for index in 1..<waypoints.count {
                let control = index < controls.count ? controls[index] : []
                let start = waypoints[index - 1]
                let end = waypoints[index]
                let distance = control.isEmpty
                    ? Geometry.lineLength(from: start, to: end)
                    : Geometry.bezierLength(from: start, controls: control, to: end)
                segments.append(Segment(start: start, end: end, controls: control, distance: distance))
                total += distance
            }
        }
        return MotionPath(
            speed: speed,
            easing: easing,
            holdTime: hold,
            segments: segments,
            totalDistance: total,
            holdRemaining: hold,
            firstWaypoint: waypoints.first,
            firstWaypointControls: controls.first ?? []
        )
    }

    private func placeholderGlyph() -> Glyph {
        let point = Coordinate(column: 1, row: 1)
        let empty = MotionPath(speed: 1, easing: nil, holdTime: 0, segments: [], totalDistance: 0, holdRemaining: 0, firstWaypoint: nil)
        return Glyph(
            characterID: 0,
            inputCoordinate: point,
            inputSymbol: 32,
            launchSymbol: 32,
            shellColor: 0,
            white: 0,
            bloomColors: [0],
            fallColors: [0],
            apex: empty,
            explode: empty,
            inputPath: empty,
            coordinate: point,
            activePath: .finished,
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
