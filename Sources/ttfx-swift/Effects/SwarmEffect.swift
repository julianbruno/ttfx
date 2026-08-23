import TTFXCore

public struct SwarmEffect: Effect {
    public struct Configuration: Sendable {
        public var baseColors: [Color]
        public var flashColor: Color
        public var swarmSize: Double
        public var swarmCoordination: Double
        public var swarmAreaCountRange: ClosedRange<Int>
        public var finalGradientStops: [Color]
        public var finalGradientSteps: [Int]
        public var finalGradientDirection: GradientDirection

        public init(
            baseColors: [Color] = [Color(hex: "31a0d4")],
            flashColor: Color = Color(hex: "f2ea79"),
            swarmSize: Double = 0.1,
            swarmCoordination: Double = 0.80,
            swarmAreaCountRange: ClosedRange<Int> = 2...4,
            finalGradientStops: [Color] = [Color(hex: "31b900"), Color(hex: "f0ff65")],
            finalGradientSteps: [Int] = [12],
            finalGradientDirection: GradientDirection = .horizontal
        ) {
            precondition(!baseColors.isEmpty, "base colors must not be empty")
            precondition(swarmSize >= 0, "swarm size must not be negative")
            precondition(swarmCoordination >= 0, "swarm coordination must not be negative")
            precondition(swarmAreaCountRange.lowerBound > 0, "swarm area count must be positive")
            self.baseColors = baseColors
            self.flashColor = flashColor
            self.swarmSize = swarmSize
            self.swarmCoordination = swarmCoordination
            self.swarmAreaCountRange = swarmAreaCountRange
            self.finalGradientStops = finalGradientStops
            self.finalGradientSteps = finalGradientSteps
            self.finalGradientDirection = finalGradientDirection
        }
    }

    private struct Segment {
        var start: Coordinate
        var end: Coordinate
        var distance: Double
    }

    private struct Path {
        let id: String
        let speed: Double
        let easing: Easing?
        var waypoints: [Coordinate]
        var segments: [Segment] = []
        var originDistance: Double?
        var totalDistance = 0.0
        var currentStep = 0
        var maxSteps = 0
        var lastDistance = 0.0

        mutating func activate(from origin: Coordinate) {
            guard let first = waypoints.first else { return }
            let originSegment = Segment(start: origin, end: first, distance: Geometry.lineLength(from: origin, to: first))
            if let previous = originDistance, !segments.isEmpty {
                totalDistance -= previous
                segments[0] = originSegment
            } else {
                segments.insert(originSegment, at: 0)
            }
            originDistance = originSegment.distance
            totalDistance += originSegment.distance
            currentStep = 0
            lastDistance = 0
            maxSteps = PyCompat.roundHalfEven(totalDistance / speed)
        }

        mutating func step() -> (coordinate: Coordinate, complete: Bool) {
            guard let last = segments.last else { return (waypoints.last ?? Coordinate(column: 1, row: 1), true) }
            if maxSteps == 0 || currentStep >= maxSteps || totalDistance == 0 {
                return (last.end, currentStep >= maxSteps)
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
            let t = segment.distance == 0 ? 0 : (easing == nil ? min(distanceToTravel / segment.distance, 1) : distanceToTravel / segment.distance)
            return (Geometry.coordinateOnLine(from: segment.start, to: segment.end, t: t), currentStep == maxSteps)
        }
    }

    private enum SceneKind { case flash, input, done }

    private struct Glyph {
        let characterID: Int
        let inputCoordinate: Coordinate
        let inputSymbol: UInt32
        var coordinate: Coordinate
        var paths: [Path]
        var activePathIndex: Int?
        var scene = SceneKind.done
        var layer = 0
        var visible = false
        var finalColors: [UInt32]
        var inputSceneIndex = 0
        var inputSceneTicks = 0
        var flashColors: [UInt32]
        var foreground: UInt32 = 0

        var activePathID: String? { activePathIndex.map { paths[$0].id } }
        var isActive: Bool { activePathIndex != nil || scene != .done }
    }

    private let canvas: Canvas
    private let options: Configuration
    private var rng: Xoshiro256PlusPlus
    private var glyphs: [Glyph] = []
    private var swarms: [[Int]] = []
    private var currentSwarm: [Int] = []
    private var active: Set<Int> = []
    private var callNext = true
    private var activeSwarmArea = "0_swarm_area"
    private var isComplete = false

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64) {
        self.init(configuration: configuration, canvas: canvas, input: input, seed: seed, swarmConfiguration: .init())
    }

    public init(configuration: EffectConfiguration, canvas: Canvas, input: InputText, seed: UInt64, swarmConfiguration: Configuration) {
        self.canvas = canvas
        options = swarmConfiguration
        rng = Xoshiro256PlusPlus(seed: seed)
        build(input: input)
    }

    public mutating func tick(into frame: inout Frame) -> TickStatus {
        guard !isComplete else { return .complete }
        guard !swarms.isEmpty || !active.isEmpty else {
            isComplete = true
            return .complete
        }
        if !swarms.isEmpty && callNext {
            callNext = false
            currentSwarm = swarms.removeLast()
            activeSwarmArea = "0_swarm_area"
            for index in currentSwarm {
                activatePath("0_swarm_area", for: index)
                glyphs[index].visible = true
                active.insert(index)
            }
        }
        if active.count < currentSwarm.count { callNext = true }
        if !currentSwarm.isEmpty {
            for index in currentSwarm {
                if let pathID = glyphs[index].activePathID,
                   pathID != activeSwarmArea,
                   pathID.contains("swarm_area"),
                   firstDigit(pathID) > firstDigit(activeSwarmArea) {
                    activeSwarmArea = pathID
                    for other in currentSwarm where other != index && rng.random() < options.swarmCoordination {
                        activatePath(activeSwarmArea, for: other)
                    }
                    break
                }
            }
        }
        for index in active.sorted(by: { glyphs[$0].characterID < glyphs[$1].characterID }) {
            stepGlyph(index)
        }
        active = active.filter { glyphs[$0].isActive }
        render(into: &frame)
        if swarms.isEmpty && active.isEmpty {
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
        guard !created.isEmpty else { isComplete = true; return }
        let bottom = created.map(\.coordinate.row).min()!
        let top = created.map(\.coordinate.row).max()!
        let left = created.map(\.coordinate.column).min()!
        let right = created.map(\.coordinate.column).max()!
        let finalGradient = try! Gradient(stops: options.finalGradientStops, steps: options.finalGradientSteps)
        let mapping = try! finalGradient.coordinateColorMapping(minRow: bottom, maxRow: top, minColumn: left, maxColumn: right, direction: options.finalGradientDirection)
        let finalColorsByCoord = Dictionary(uniqueKeysWithValues: mapping.entries.map { ($0.coordinate, Self.rgb($0.color)) })
        let swarmSize = max(PyCompat.roundHalfEven(Double(created.count) * options.swarmSize), 1)
        makeSwarms(created: created, swarmSize: swarmSize)

        glyphs = created.map { source in
            Glyph(
                characterID: source.characterID,
                inputCoordinate: source.coordinate,
                inputSymbol: source.symbol,
                coordinate: source.coordinate,
                paths: [],
                finalColors: (try! Gradient(stops: [options.flashColor, Color(rgb: finalColorsByCoord[source.coordinate]!)], steps: 10)).spectrum.map(Self.rgb),
                flashColors: []
            )
        }

        var circleCache: [Coordinate: [Coordinate]] = [:]
        for swarm in swarms {
            let base = options.baseColors[rng.integer(in: 0..<options.baseColors.count)]
            let swarmGradient = try! Gradient(stops: [base, options.flashColor], steps: 7)
            let flashColors = (swarmGradient.spectrum + Array(repeating: options.flashColor, count: 10) + swarmGradient.spectrum.reversed()).map(Self.rgb)
            let spawn = randomCoord(outside: true)
            var swarmAreaCoordinateMap: [(Coordinate, [Coordinate])] = []
            var swarmAreas: [Coordinate] = []
            let swarmAreaCount = rng.integer(in: options.swarmAreaCountRange)
            var lastFocus = spawn
            let radius = max(PyCompat.floorDivide(min(canvas.columns, canvas.rows), 2), 1)
            while swarmAreas.count < swarmAreaCount {
                var cached = circleCache[lastFocus] ?? Geometry.coordinatesOnCircle(origin: lastFocus, radius: radius, limit: 0, unique: true)
                rng.shuffle(&cached)
                circleCache[lastFocus] = cached
                let nextFocus = cached.first(where: coordIsInCanvas) ?? randomCoord(outside: false)
                swarmAreas.append(nextFocus)
                let areaCoords = Geometry.coordinatesInEllipse(center: lastFocus, diameter: max(PyCompat.floorDivide(min(canvas.columns, canvas.rows), 6), 1) * 2)
                if let existing = swarmAreaCoordinateMap.firstIndex(where: { $0.0 == lastFocus }) {
                    swarmAreaCoordinateMap[existing].1 = areaCoords
                } else {
                    swarmAreaCoordinateMap.append((lastFocus, areaCoords))
                }
                lastFocus = nextFocus
            }
            for index in swarm {
                glyphs[index].coordinate = spawn
                glyphs[index].flashColors = flashColors
                var paths: [Path] = []
                for (areaIndex, entry) in swarmAreaCoordinateMap.enumerated() {
                    let areaName = "\(areaIndex)_swarm_area"
                    let origin = entry.1[rng.integer(in: 0..<entry.1.count)]
                    paths.append(makePath(id: areaName, speed: 0.4, easing: .outSine, waypoints: [origin]))
                    for _ in 0..<2 {
                        let next = entry.1[rng.integer(in: 0..<entry.1.count)]
                        let pathID = "\(paths.count)"
                        let waypointID = "\(paths.count + 1)"
                        _ = waypointID
                        paths.append(makePath(id: pathID, speed: 0.18, easing: .inOutSine, waypoints: [next]))
                    }
                }
                paths.append(makePath(id: "\(paths.count)", speed: 0.45, easing: .inOutQuad, waypoints: [glyphs[index].inputCoordinate]))
                glyphs[index].paths = paths
            }
        }
    }

    private mutating func makeSwarms(created: [(characterID: Int, symbol: UInt32, coordinate: Coordinate)], swarmSize: Int) {
        var unswarmed = created.indices.sorted { lhs, rhs in
            let l = created[lhs].coordinate
            let r = created[rhs].coordinate
            if l.row != r.row { return l.row < r.row }
            if l.column != r.column { return l.column > r.column }
            return created[lhs].characterID > created[rhs].characterID
        }
        while !unswarmed.isEmpty {
            var next: [Int] = []
            for _ in 0..<swarmSize {
                guard let item = unswarmed.popLast() else { break }
                next.append(item)
            }
            swarms.append(next)
        }
        let final = swarms.removeLast()
        if final.count < PyCompat.floorDivide(swarmSize, 2), !swarms.isEmpty {
            swarms[swarms.count - 1].append(contentsOf: final)
        } else {
            swarms.append(final)
        }
    }

    private func makePath(id: String, speed: Double, easing: Easing, waypoints: [Coordinate]) -> Path {
        var path = Path(id: id, speed: speed, easing: easing, waypoints: waypoints)
        if waypoints.count > 1 {
            for pair in zip(waypoints, waypoints.dropFirst()) {
                let distance = Geometry.lineLength(from: pair.0, to: pair.1)
                path.segments.append(Segment(start: pair.0, end: pair.1, distance: distance))
                path.totalDistance += distance
            }
            path.maxSteps = PyCompat.roundHalfEven(path.totalDistance / speed)
        }
        return path
    }

    private mutating func activatePath(_ id: String, for index: Int) {
        guard let pathIndex = glyphs[index].paths.firstIndex(where: { $0.id == id }) else { return }
        glyphs[index].paths[pathIndex].activate(from: glyphs[index].coordinate)
        glyphs[index].activePathIndex = pathIndex
        glyphs[index].scene = .flash
        glyphs[index].layer = id == glyphs[index].paths.last?.id ? glyphs[index].layer : 1
        glyphs[index].inputSceneIndex = 0
        glyphs[index].inputSceneTicks = 0
        if !glyphs[index].flashColors.isEmpty {
            glyphs[index].foreground = glyphs[index].flashColors[0]
        }
    }

    private mutating func stepGlyph(_ index: Int) {
        if let activePath = glyphs[index].activePathIndex {
            let before = glyphs[index].coordinate
            let result = glyphs[index].paths[activePath].step()
            glyphs[index].coordinate = result.coordinate
            if !result.complete, glyphs[index].scene == .flash {
                let path = glyphs[index].paths[activePath]
                let total = max(path.totalDistance, 1)
                let remaining = max(path.totalDistance - path.lastDistance, 1)
                let reached = max(total - remaining, 1)
                let frameIndex = min(PyCompat.roundHalfEven((reached / total) * Double(glyphs[index].flashColors.count - 1)), glyphs[index].flashColors.count - 1)
                glyphs[index].foreground = glyphs[index].flashColors[frameIndex]
            }
            if result.complete {
                let completedID = glyphs[index].paths[activePath].id
                glyphs[index].activePathIndex = nil
                if completedID.contains("swarm_area") {
                    glyphs[index].scene = .done
                }
                if let next = glyphs[index].paths.indices.first(where: { $0 > activePath }) {
                    activatePath(glyphs[index].paths[next].id, for: index)
                } else {
                    glyphs[index].scene = .input
                    glyphs[index].layer = 0
                }
            }
            _ = before
        }
        if glyphs[index].scene == .input {
            let colorIndex = min(glyphs[index].inputSceneIndex, glyphs[index].finalColors.count - 1)
            glyphs[index].foreground = glyphs[index].finalColors[colorIndex]
            glyphs[index].inputSceneTicks += 1
            if glyphs[index].inputSceneTicks == 3 {
                glyphs[index].inputSceneTicks = 0
                glyphs[index].inputSceneIndex += 1
                if glyphs[index].inputSceneIndex >= glyphs[index].finalColors.count { glyphs[index].scene = .done }
            }
        }
    }

    private func render(into frame: inout Frame) {
        for index in glyphs.indices.sorted(by: { glyphs[$0].characterID < glyphs[$1].characterID }) where glyphs[index].visible {
            let glyph = glyphs[index]
            guard (1...canvas.columns).contains(glyph.coordinate.column), (1...canvas.rows).contains(glyph.coordinate.row) else { continue }
            let existing = frame[column: glyph.coordinate.column, row: glyph.coordinate.row]
            if existing.codepoint == 32 || glyph.layer >= 1 {
                frame[column: glyph.coordinate.column, row: glyph.coordinate.row] = Cell(codepoint: glyph.inputSymbol, foreground: glyph.foreground, background: 0)
            }
        }
    }

    private mutating func randomCoord(outside: Bool) -> Coordinate {
        if outside {
            let above = Coordinate(column: rng.integer(in: 1...canvas.columns), row: canvas.rows + 1)
            let below = Coordinate(column: rng.integer(in: 1...canvas.columns), row: 0)
            let left = Coordinate(column: 0, row: rng.integer(in: 1...canvas.rows))
            let right = Coordinate(column: canvas.columns + 1, row: rng.integer(in: 1...canvas.rows))
            return [above, below, left, right][rng.integer(in: 0..<4)]
        }
        return Coordinate(column: rng.integer(in: 1...canvas.columns), row: rng.integer(in: 1...canvas.rows))
    }

    private func coordIsInCanvas(_ coord: Coordinate) -> Bool {
        (1...canvas.columns).contains(coord.column) && (1...canvas.rows).contains(coord.row)
    }

    private func firstDigit(_ value: String) -> Int { Int(String(value.first!))! }

    private static func rgb(_ color: Color) -> UInt32 {
        (UInt32(color.red) << 16) | (UInt32(color.green) << 8) | UInt32(color.blue)
    }
}

private extension Color {
    init(rgb: UInt32) {
        self.init(hex: String(format: "%06x", rgb))
    }
}
