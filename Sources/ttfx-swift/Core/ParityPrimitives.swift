import Foundation

public enum PyCompat {
    public static func roundHalfEven(_ value: Double) -> Int {
        let floor = value.rounded(.down)
        let difference = value - floor
        if difference > 0.5 { return Int(floor) + 1 }
        if difference < 0.5 { return Int(floor) }
        let integer = Int(floor)
        return integer.isMultiple(of: 2) ? integer : integer + 1
    }

    public static func floorDivide(_ lhs: Int, _ rhs: Int) -> Int {
        precondition(rhs != 0, "division by zero")
        let quotient = lhs / rhs
        return lhs % rhs != 0 && (lhs < 0) != (rhs < 0) ? quotient - 1 : quotient
    }

    public static func modulo(_ lhs: Int, _ rhs: Int) -> Int {
        precondition(rhs != 0, "division by zero")
        let remainder = lhs % rhs
        return remainder != 0 && (remainder < 0) != (rhs < 0) ? remainder + rhs : remainder
    }
}

public struct Xoshiro256PlusPlus: Equatable, Sendable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.state.0 == rhs.state.0 && lhs.state.1 == rhs.state.1
            && lhs.state.2 == rhs.state.2 && lhs.state.3 == rhs.state.3
    }
    private var state: (UInt64, UInt64, UInt64, UInt64)

    public init(seed: UInt64) {
        var splitMix = seed
        func next(_ state: inout UInt64) -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            return value ^ (value >> 31)
        }
        self.state = (next(&splitMix), next(&splitMix), next(&splitMix), next(&splitMix))
    }

    public mutating func nextUInt64() -> UInt64 {
        let result = (state.0 &+ state.3).rotatedLeft(by: 23) &+ state.0
        let temporary = state.1 << 17
        state.2 ^= state.0
        state.3 ^= state.1
        state.1 ^= state.2
        state.0 ^= state.3
        state.2 ^= temporary
        state.3 = state.3.rotatedLeft(by: 45)
        return result
    }

    public mutating func random() -> Double {
        Double(nextUInt64() >> 11) * (1.0 / Double(UInt64(1) << 53))
    }

    public mutating func integer(in range: ClosedRange<Int>) -> Int {
        precondition(range.lowerBound <= range.upperBound, "empty integer range")
        return range.lowerBound + Int(randomBelow(UInt64(range.upperBound - range.lowerBound + 1)))
    }

    public mutating func integer(in range: Range<Int>) -> Int {
        precondition(range.lowerBound < range.upperBound, "empty integer range")
        return range.lowerBound + Int(randomBelow(UInt64(range.upperBound - range.lowerBound)))
    }

    public mutating func uniform(_ lower: Double, _ upper: Double) -> Double {
        lower + (upper - lower) * random()
    }

    public mutating func shuffle<T>(_ values: inout [T]) {
        guard values.count > 1 else { return }
        for index in stride(from: values.count - 1, through: 1, by: -1) {
            values.swapAt(index, Int(randomBelow(UInt64(index + 1))))
        }
    }

    private mutating func randomBelow(_ upperBound: UInt64) -> UInt64 {
        precondition(upperBound > 0, "randomBelow(0)")
        let bitCount = 64 - (upperBound - 1).leadingZeroBitCount
        while true {
            let value = nextUInt64() >> (64 - max(bitCount, 1))
            if value < upperBound { return value }
        }
    }
}

private extension UInt64 {
    func rotatedLeft(by count: UInt64) -> UInt64 {
        (self << count) | (self >> (64 - count))
    }
}

public struct Coordinate: Hashable, Equatable, Sendable {
    public let column: Int
    public let row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }
}

public enum Geometry {
    public static func coordinatesOnCircle(origin: Coordinate, radius: Int, limit: Int = 0, unique: Bool = true) -> [Coordinate] {
        guard radius != 0 else { return [] }
        let count = limit == 0 ? PyCompat.roundHalfEven(2 * .pi * Double(radius)) : limit
        let step = 2 * Double.pi / Double(count)
        var coordinates: [Coordinate] = []
        var seen = Set<Coordinate>()
        for index in 0..<count {
            let angle = step * Double(index)
            var x = Double(origin.column) + Double(radius) * cos(angle)
            x += x - Double(origin.column)
            let y = Double(origin.row) + Double(radius) * sin(angle)
            let coordinate = Coordinate(column: PyCompat.roundHalfEven(x), row: PyCompat.roundHalfEven(y))
            if !unique || seen.insert(coordinate).inserted { coordinates.append(coordinate) }
        }
        return coordinates
    }

    public static func coordinatesInEllipse(center: Coordinate, diameter: Int) -> [Coordinate] {
        guard diameter != 0 else { return [] }
        let aSquared = Double(diameter * diameter)
        let bSquared = Double(diameter * diameter) / 4
        var coordinates: [Coordinate] = []
        for column in (center.column - diameter)...(center.column + diameter) {
            let xComponent = Double((column - center.column) * (column - center.column)) / aSquared
            let maxYOffset = Int((bSquared * (1 - xComponent)).squareRoot())
            for row in (center.row - maxYOffset)...(center.row + maxYOffset) {
                coordinates.append(Coordinate(column: column, row: row))
            }
        }
        return coordinates
    }

    public static func coordinatesInRectangle(center: Coordinate, distance: Int) -> [Coordinate] {
        guard distance != 0 else { return [] }
        return (center.column - distance...center.column + distance).flatMap { column in
            (center.row - distance...center.row + distance).map { Coordinate(column: column, row: $0) }
        }
    }

    public static func coordinatesOnRectangle(center: Coordinate, halfWidth: Int, halfHeight: Int) -> [Coordinate] {
        guard halfWidth != 0, halfHeight != 0 else { return [] }
        var coordinates: [Coordinate] = []
        for column in (center.column - halfWidth)...(center.column + halfWidth) {
            if column == center.column - halfWidth || column == center.column + halfWidth {
                for row in (center.row - halfHeight)...(center.row + halfHeight) {
                    coordinates.append(Coordinate(column: column, row: row))
                }
            } else {
                coordinates.append(Coordinate(column: column, row: center.row - halfHeight))
                coordinates.append(Coordinate(column: column, row: center.row + halfHeight))
            }
        }
        return coordinates
    }

    public static func coordinateOnLine(from start: Coordinate, to end: Coordinate, t: Double) -> Coordinate {
        Coordinate(
            column: PyCompat.roundHalfEven((1 - t) * Double(start.column) + t * Double(end.column)),
            row: PyCompat.roundHalfEven((1 - t) * Double(start.row) + t * Double(end.row))
        )
    }

    public static func coordinateOnBezier(from start: Coordinate, controls: [Coordinate], to end: Coordinate, t: Double) -> Coordinate {
        guard !controls.isEmpty else { return coordinateOnLine(from: start, to: end, t: t) }
        var points = ([start] + controls + [end]).map { (Double($0.column), Double($0.row)) }
        var remaining = points.count
        while remaining > 1 {
            for index in 0..<(remaining - 1) {
                points[index] = ((1 - t) * points[index].0 + t * points[index + 1].0, (1 - t) * points[index].1 + t * points[index + 1].1)
            }
            remaining -= 1
        }
        return Coordinate(column: PyCompat.roundHalfEven(points[0].0), row: PyCompat.roundHalfEven(points[0].1))
    }

    // QUIRK(src/utils/geometry.rs:130-140; plan.md): non-doubled length, then lerp past the target.
    public static func extrapolateAlongRay(origin: Coordinate, target: Coordinate, offsetFromTarget: Double) -> Coordinate {
        let base = lineLength(from: origin, to: target, doubleRowDifference: false)
        let total = base + offsetFromTarget
        if total == 0 || origin == target { return target }
        let t = total / base
        return Coordinate(
            column: PyCompat.roundHalfEven((1 - t) * Double(origin.column) + t * Double(target.column)),
            row: PyCompat.roundHalfEven((1 - t) * Double(origin.row) + t * Double(target.row))
        )
    }

    public static func lineLength(from start: Coordinate, to end: Coordinate, doubleRowDifference: Bool = true) -> Double {
        hypot(Double(end.column - start.column), Double(end.row - start.row) * (doubleRowDifference ? 2 : 1))
    }

    public static func bezierLength(from start: Coordinate, controls: [Coordinate], to end: Coordinate) -> Double {
        var length = 0.0
        var previous = start
        for step in 1..<10 {
            let coordinate = coordinateOnBezier(from: start, controls: controls, to: end, t: Double(step) / 10)
            length += lineLength(from: previous, to: coordinate)
            previous = coordinate
        }
        return length
    }

    public static func normalizedDistanceFromCenter(
        bottom: Int,
        top: Int,
        left: Int,
        right: Int,
        coordinate: Coordinate
    ) throws -> Double {
        let rowOffset = bottom - 1
        let columnOffset = left - 1
        let normalizedRight = right - columnOffset
        let normalizedTop = top - rowOffset
        let column = coordinate.column - columnOffset
        let row = coordinate.row - rowOffset
        guard (left - columnOffset...normalizedRight).contains(column),
              (bottom - rowOffset...normalizedTop).contains(row)
        else {
            throw GradientError.invalidCoordinates
        }
        let centerX = Double(normalizedRight) / 2
        let centerY = Double(normalizedTop) / 2
        let maximum = hypot(Double(normalizedRight), Double(normalizedTop * 2))
        let distance = hypot(Double(column) - centerX, (Double(row) - centerY) * 2)
        return distance / (maximum / 2)
    }
}

public struct Color: Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        precondition(normalized.count >= 6, "invalid RGB hex value")
        red = UInt8(normalized.prefix(2), radix: 16)!
        green = UInt8(normalized.dropFirst(2).prefix(2), radix: 16)!
        blue = UInt8(normalized.dropFirst(4).prefix(2), radix: 16)!
    }

    public var hex: String { String(format: "%02x%02x%02x", red, green, blue) }
}

public enum GradientError: Error, Equatable, Sendable {
    case missingStops
    case invalidSteps
    case invalidCoordinates
}

public enum GradientDirection: Sendable {
    case vertical
    case horizontal
    case radial
    case diagonal
}

public struct CoordinateColor: Equatable, Sendable {
    public let coordinate: Coordinate
    public let color: Color
}

public struct CoordinateColorMapping: Equatable, Sendable {
    public let entries: [CoordinateColor]
}

public struct Gradient: Sendable {
    public let spectrum: [Color]

    public init(stops: [Color], steps: Int, loop: Bool = false) throws {
        guard steps > 0 else { throw GradientError.invalidSteps }
        try self.init(stops: stops, steps: [steps], loop: loop)
    }

    public init(stops: [Color], steps: [Int], loop: Bool = false) throws {
        guard !stops.isEmpty else { throw GradientError.missingStops }
        guard !steps.isEmpty, steps.allSatisfy({ $0 > 0 }) else { throw GradientError.invalidSteps }
        if stops.count == 1 {
            spectrum = Array(repeating: stops[0], count: steps[0])
            return
        }
        var colors = stops
        if loop { colors.append(stops[0]) }
        let pairCount = colors.count - 1
        var counts = Array(steps.prefix(pairCount))
        while counts.count < pairCount { counts.append(counts.last!) }
        var generated: [Color] = []
        for index in 0..<pairCount {
            let start = colors[index]
            let end = colors[index + 1]
            let count = counts[index]
            let redDelta = PyCompat.floorDivide(Int(end.red) - Int(start.red), count)
            let greenDelta = PyCompat.floorDivide(Int(end.green) - Int(start.green), count)
            let blueDelta = PyCompat.floorDivide(Int(end.blue) - Int(start.blue), count)
            for step in (generated.isEmpty ? 0 : 1)..<count {
                let red = min(max(Int(start.red) + redDelta * step, 0), 255)
                let green = min(max(Int(start.green) + greenDelta * step, 0), 255)
                let blue = min(max(Int(start.blue) + blueDelta * step, 0), 255)
                generated.append(Color(hex: String(format: "%02x%02x%02x", red, green, blue)))
            }
            generated.append(end)
        }
        spectrum = generated
    }

    public func color(at fraction: Double) -> Color {
        precondition((0...1).contains(fraction), "fraction outside 0...1")
        let index = min(Int(ceil(fraction * Double(spectrum.count))), spectrum.count) - 1
        return spectrum[max(index, 0)]
    }

    public func coordinateColorMapping(
        minRow: Int,
        maxRow: Int,
        minColumn: Int,
        maxColumn: Int,
        direction: GradientDirection
    ) throws -> CoordinateColorMapping {
        guard minRow >= 1, minColumn >= 1, maxRow >= minRow, maxColumn >= minColumn else {
            throw GradientError.invalidCoordinates
        }
        let rowOffset = minRow - 1
        let columnOffset = minColumn - 1
        var entries: [CoordinateColor] = []
        func append(_ column: Int, _ row: Int, _ fraction: Double) {
            entries.append(CoordinateColor(coordinate: .init(column: column, row: row), color: color(at: fraction)))
        }
        switch direction {
        case .vertical:
            for row in minRow...maxRow {
                let fraction = Double(row - rowOffset) / Double(maxRow - rowOffset)
                for column in minColumn...maxColumn { append(column, row, fraction) }
            }
        case .horizontal:
            for column in minColumn...maxColumn {
                let fraction = Double(column - columnOffset) / Double(maxColumn - columnOffset)
                for row in minRow...maxRow { append(column, row, fraction) }
            }
        case .radial:
            for row in minRow...maxRow {
                for column in minColumn...maxColumn {
                    let fraction = try Geometry.normalizedDistanceFromCenter(
                        bottom: minRow, top: maxRow, left: minColumn, right: maxColumn, coordinate: .init(column: column, row: row)
                    )
                    append(column, row, fraction)
                }
            }
        case .diagonal:
            for row in minRow...maxRow {
                for column in minColumn...maxColumn {
                    let fraction = Double((row - rowOffset) * 2 + column - columnOffset) / Double((maxRow - rowOffset) * 2 + maxColumn - columnOffset)
                    append(column, row, fraction)
                }
            }
        }
        return CoordinateColorMapping(entries: entries)
    }
}

public enum Easing: Sendable {
    case linear, inSine, outSine, inOutSine, inQuad, outQuad, inOutQuad, inCubic, outCubic, inOutCubic
    case inQuart, outQuart, inOutQuart, inQuint, outQuint, inOutQuint, inExpo, outExpo, inOutExpo
    case inCirc, outCirc, inOutCirc, inBack, outBack, inOutBack, inElastic, outElastic, inOutElastic
    case inBounce, outBounce, inOutBounce, cubicBezier(Double, Double, Double, Double)

    public func value(at x: Double) -> Double {
        return switch self {
        case .linear: x
        case .inSine: 1 - cos((x * .pi) / 2)
        case .outSine: sin((x * .pi) / 2)
        case .inOutSine: -(cos(.pi * x) - 1) / 2
        case .inQuad: x * x
        case .outQuad: 1 - (1 - x) * (1 - x)
        case .inOutQuad: x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
        case .inCubic: x * x * x
        case .outCubic: 1 - pow(1 - x, 3)
        case .inOutCubic: x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
        case .inQuart: pow(x, 4)
        case .outQuart: 1 - pow(1 - x, 4)
        case .inOutQuart: x < 0.5 ? 8 * pow(x, 4) : 1 - pow(-2 * x + 2, 4) / 2
        case .inQuint: pow(x, 5)
        case .outQuint: 1 - pow(1 - x, 5)
        case .inOutQuint: x < 0.5 ? 16 * pow(x, 5) : 1 - pow(-2 * x + 2, 5) / 2
        case .inExpo: x == 0 ? 0 : pow(2, 10 * x - 10)
        case .outExpo: x == 1 ? 1 : 1 - pow(2, -10 * x)
        case .inOutExpo:
            x == 0 ? 0 : x == 1 ? 1 : x < 0.5 ? pow(2, 20 * x - 10) / 2 : (2 - pow(2, -20 * x + 10)) / 2
        case .inCirc: 1 - sqrt(1 - pow(x, 2))
        case .outCirc: sqrt(1 - pow(x - 1, 2))
        case .inOutCirc: x < 0.5 ? (1 - sqrt(1 - pow(2 * x, 2))) / 2 : (sqrt(1 - pow(-2 * x + 2, 2)) + 1) / 2
        case .inBack: 2.70158 * x * x * x - 1.70158 * x * x
        case .outBack: 1 + 2.70158 * pow(x - 1, 3) + 1.70158 * pow(x - 1, 2)
        case .inOutBack:
            ({
                let c = 1.70158 * 1.525
                return x < 0.5 ? pow(2 * x, 2) * ((c + 1) * 2 * x - c) / 2 : (pow(2 * x - 2, 2) * ((c + 1) * (x * 2 - 2) + c) + 2) / 2
            })()
        case .inElastic: x == 0 ? 0 : x == 1 ? 1 : -pow(2, 10 * x - 10) * sin((x * 10 - 10.75) * (2 * .pi / 3))
        case .outElastic: x == 0 ? 0 : x == 1 ? 1 : pow(2, -10 * x) * sin((x * 10 - 0.75) * (2 * .pi / 3)) + 1
        case .inOutElastic:
            x == 0 ? 0 : x == 1 ? 1 : x < 0.5 ? -(pow(2, 20 * x - 10) * sin((20 * x - 11.125) * (2 * .pi / 4.5))) / 2 : (pow(2, -20 * x + 10) * sin((20 * x - 11.125) * (2 * .pi / 4.5))) / 2 + 1
        case .inBounce: 1 - Easing.outBounce.value(at: 1 - x)
        case .outBounce:
            ({
                let n = 7.5625, d = 2.75
                if x < 1 / d { return n * x * x }
                if x < 2 / d { return n * pow(x - 1.5 / d, 2) + 0.75 }
                if x < 2.5 / d { return n * pow(x - 2.25 / d, 2) + 0.9375 }
                return n * pow(x - 2.625 / d, 2) + 0.984375
            })()
        case .inOutBounce: x < 0.5 ? (1 - Easing.outBounce.value(at: 1 - 2 * x)) / 2 : (1 + Easing.outBounce.value(at: 2 * x - 1)) / 2
        case let .cubicBezier(x1, y1, x2, y2): ttfxCubicBezier(x, x1, y1, x2, y2)
        }
    }
}

private func ttfxCubicBezier(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
    func sample(_ t: Double, _ a: Double, _ b: Double) -> Double { 3 * a * pow(1 - t, 2) * t + 3 * b * (1 - t) * t * t + t * t * t }
    var lower = 0.0
    var upper = 1.0
    for _ in 0..<30 {
        let t = (lower + upper) / 2
        if sample(t, x1, x2) < x { lower = t } else { upper = t }
    }
    return sample((lower + upper) / 2, y1, y2)
}
