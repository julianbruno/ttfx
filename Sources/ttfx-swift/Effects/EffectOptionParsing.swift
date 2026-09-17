import TTFXCore

public enum EffectOptionError: Error, Equatable, CustomStringConvertible {
    case unknownFlag(effect: String, flag: String)
    case missingValue(flag: String)
    case invalidValue(flag: String, value: String, expected: String)
    case unexpectedArgument(String)

    public var description: String {
        switch self {
        case let .unknownFlag(effect, flag):
            "unknown \(effect) flag '\(flag)'"
        case let .missingValue(flag):
            "missing value for --\(flag)"
        case let .invalidValue(flag, value, expected):
            "invalid value '\(value)' for --\(flag) (expected \(expected))"
        case let .unexpectedArgument(value):
            "unexpected argument '\(value)'"
        }
    }
}

public enum EffectOptionValue: Sendable, Equatable {
    case bool(Bool)
    case int(Int)
    case float(Double)
    case string(String)
    case strings([String])
    case ints([Int])
}

public struct ParsedEffectSettings: Sendable, Equatable {
    public let effectName: String
    public var values: [String: EffectOptionValue]

    public static let empty = ParsedEffectSettings(effectName: "", values: [:])

    public init(effectName: String, values: [String: EffectOptionValue] = [:]) {
        self.effectName = effectName
        self.values = values
    }

    public func bool(_ flag: String) -> Bool? {
        if case let .bool(value) = values[flag] { return value }
        return nil
    }

    public func int(_ flag: String) -> Int? {
        if case let .int(value) = values[flag] { return value }
        return nil
    }

    public func double(_ flag: String) -> Double? {
        switch values[flag] {
        case let .float(value): value
        case let .int(value): Double(value)
        default: nil
        }
    }

    public func string(_ flag: String) -> String? {
        if case let .string(value) = values[flag] { return value }
        return nil
    }

    public func strings(_ flag: String) -> [String]? {
        switch values[flag] {
        case let .strings(value): value
        case let .string(value): [value]
        default: nil
        }
    }

    public func ints(_ flag: String) -> [Int]? {
        if case let .ints(value) = values[flag] { return value }
        if let value = int(flag) { return [value] }
        return nil
    }

    public func color(_ flag: String) -> Color? {
        string(flag).flatMap(Color.parseCLI)
    }

    public func colors(_ flag: String) -> [Color]? {
        strings(flag)?.compactMap(Color.parseCLI)
    }

    public func easing(_ flag: String) -> Easing? {
        string(flag).flatMap(Easing.init(tteName:))
    }

    public func gradientDirection(_ flag: String) -> GradientDirection? {
        string(flag).flatMap(GradientDirection.init(tteName:))
    }

    public func intRange(_ flag: String) -> (Int, Int)? {
        string(flag).flatMap(parseIntRange)
    }

    public func floatRange(_ flag: String) -> (Double, Double)? {
        string(flag).flatMap(parseFloatRange)
    }

    public static func parse(effectName: String, arguments: [String]) throws -> ParsedEffectSettings {
        let specs = EffectFlagCatalog.specs(for: effectName)
        guard !specs.isEmpty else {
            if arguments.isEmpty { return .init(effectName: effectName) }
            throw EffectOptionError.unknownFlag(effect: effectName, flag: arguments[0])
        }
        let byName = Dictionary(uniqueKeysWithValues: specs.map { ($0.name, $0) })
        var values: [String: EffectOptionValue] = [:]
        var index = 0
        while index < arguments.count {
            let token = arguments[index]
            if token == "--" {
                index += 1
                continue
            }
            guard token.hasPrefix("--") else {
                throw EffectOptionError.unexpectedArgument(token)
            }
            let name = String(token.dropFirst(2))
            guard let spec = byName[name] else {
                throw EffectOptionError.unknownFlag(effect: effectName, flag: token)
            }
            index += 1
            let parsed: EffectOptionValue
            switch spec.kind {
            case .bool:
                if index < arguments.count, !arguments[index].hasPrefix("--"), let boolValue = parseBool(arguments[index]) {
                    parsed = .bool(boolValue)
                    index += 1
                } else {
                    parsed = .bool(true)
                }
            case .int:
                parsed = .int(try takeInt(flag: name, arguments: arguments, index: &index))
            case .float:
                parsed = .float(try takeDouble(flag: name, arguments: arguments, index: &index))
            case .string, .easing, .gradientDirection, .intRange, .floatRange, .color, .choice(_):
                parsed = .string(try takeOne(flag: name, arguments: arguments, index: &index))
            case .strings, .colors:
                parsed = .strings(try takeMany(flag: name, arguments: arguments, index: &index))
            case .ints:
                let raw = try takeMany(flag: name, arguments: arguments, index: &index)
                var ints: [Int] = []
                for item in raw {
                    guard let value = Int(item) else {
                        throw EffectOptionError.invalidValue(flag: name, value: item, expected: "int")
                    }
                    ints.append(value)
                }
                parsed = .ints(ints)
            }
            if case let .choice(options) = spec.kind, case let .string(value) = parsed, !options.contains(value) {
                throw EffectOptionError.invalidValue(flag: name, value: value, expected: options.joined(separator: ", "))
            }
            if spec.kind == .easing, case let .string(value) = parsed, Easing(tteName: value) == nil {
                throw EffectOptionError.invalidValue(flag: name, value: value, expected: "easing name")
            }
            if spec.kind == .gradientDirection, case let .string(value) = parsed, GradientDirection(tteName: value) == nil {
                throw EffectOptionError.invalidValue(flag: name, value: value, expected: "horizontal, vertical, diagonal, radial")
            }
            if spec.kind == .color, case let .string(value) = parsed, Color.parseCLI(value) == nil {
                throw EffectOptionError.invalidValue(flag: name, value: value, expected: "color")
            }
            if spec.kind == .colors, case let .strings(raw) = parsed {
                for item in raw where Color.parseCLI(item) == nil {
                    throw EffectOptionError.invalidValue(flag: name, value: item, expected: "color")
                }
            }
            if spec.kind == .intRange, case let .string(value) = parsed, parseIntRange(value) == nil {
                throw EffectOptionError.invalidValue(flag: name, value: value, expected: "int-int range")
            }
            if spec.kind == .floatRange, case let .string(value) = parsed, parseFloatRange(value) == nil {
                throw EffectOptionError.invalidValue(flag: name, value: value, expected: "float-float range")
            }
            values[name] = parsed
        }
        return ParsedEffectSettings(effectName: effectName, values: values)
    }
}

extension Color {
    public static func parseCLI(_ argument: String) -> Color? {
        if argument.count <= 3, let code = Int(argument), (0...255).contains(code) {
            let rgb = xtermRGB(UInt8(code))
            return Color(hex: String(format: "%02x%02x%02x", rgb.0, rgb.1, rgb.2))
        }
        let hex = argument.hasPrefix("#") ? String(argument.dropFirst()) : argument
        guard hex.count == 6, hex.allSatisfy(\.isHexDigit) else { return nil }
        return Color(hex: hex)
    }
}

extension Easing {
    public init?(tteName: String) {
        switch tteName.lowercased() {
        case "linear": self = .linear
        case "in_sine": self = .inSine
        case "out_sine": self = .outSine
        case "in_out_sine": self = .inOutSine
        case "in_quad": self = .inQuad
        case "out_quad": self = .outQuad
        case "in_out_quad": self = .inOutQuad
        case "in_cubic": self = .inCubic
        case "out_cubic": self = .outCubic
        case "in_out_cubic": self = .inOutCubic
        case "in_quart": self = .inQuart
        case "out_quart": self = .outQuart
        case "in_out_quart": self = .inOutQuart
        case "in_quint": self = .inQuint
        case "out_quint": self = .outQuint
        case "in_out_quint": self = .inOutQuint
        case "in_expo": self = .inExpo
        case "out_expo": self = .outExpo
        case "in_out_expo": self = .inOutExpo
        case "in_circ": self = .inCirc
        case "out_circ": self = .outCirc
        case "in_out_circ": self = .inOutCirc
        case "in_back": self = .inBack
        case "out_back": self = .outBack
        case "in_out_back": self = .inOutBack
        case "in_elastic": self = .inElastic
        case "out_elastic": self = .outElastic
        case "in_out_elastic": self = .inOutElastic
        case "in_bounce": self = .inBounce
        case "out_bounce": self = .outBounce
        case "in_out_bounce": self = .inOutBounce
        default: return nil
        }
    }
}

extension GradientDirection {
    public init?(tteName: String) {
        switch tteName {
        case "horizontal": self = .horizontal
        case "vertical": self = .vertical
        case "diagonal": self = .diagonal
        case "radial": self = .radial
        default: return nil
        }
    }
}

private func takeOne(flag: String, arguments: [String], index: inout Int) throws -> String {
    guard index < arguments.count, !arguments[index].hasPrefix("--") else {
        throw EffectOptionError.missingValue(flag: flag)
    }
    let value = arguments[index]
    index += 1
    return value
}

private func takeMany(flag: String, arguments: [String], index: inout Int) throws -> [String] {
    var values: [String] = []
    while index < arguments.count, !arguments[index].hasPrefix("--") {
        values.append(arguments[index])
        index += 1
    }
    guard !values.isEmpty else { throw EffectOptionError.missingValue(flag: flag) }
    return values
}

private func takeInt(flag: String, arguments: [String], index: inout Int) throws -> Int {
    let raw = try takeOne(flag: flag, arguments: arguments, index: &index)
    guard let value = Int(raw) else {
        throw EffectOptionError.invalidValue(flag: flag, value: raw, expected: "int")
    }
    return value
}

private func takeDouble(flag: String, arguments: [String], index: inout Int) throws -> Double {
    let raw = try takeOne(flag: flag, arguments: arguments, index: &index)
    guard let value = Double(raw) else {
        throw EffectOptionError.invalidValue(flag: flag, value: raw, expected: "float")
    }
    return value
}

private func parseBool(_ value: String) -> Bool? {
    switch value.lowercased() {
    case "true", "1", "yes": true
    case "false", "0", "no": false
    default: nil
    }
}

private func parseIntRange(_ value: String) -> (Int, Int)? {
    let parts = value.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 2, let lower = Int(parts[0]), let upper = Int(parts[1]) else { return nil }
    return (lower, upper)
}

private func parseFloatRange(_ value: String) -> (Double, Double)? {
    let parts = value.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 2, let lower = Double(parts[0]), let upper = Double(parts[1]) else { return nil }
    return (lower, upper)
}

private func xtermRGB(_ code: UInt8) -> (UInt8, UInt8, UInt8) {
    let basic: [(UInt8, UInt8, UInt8)] = [
        (0, 0, 0), (128, 0, 0), (0, 128, 0), (128, 128, 0),
        (0, 0, 128), (128, 0, 128), (0, 128, 128), (192, 192, 192),
        (128, 128, 128), (255, 0, 0), (0, 255, 0), (255, 255, 0),
        (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255),
    ]
    if code < 16 { return basic[Int(code)] }
    if code < 232 {
        let levels: [UInt8] = [0, 95, 135, 175, 215, 255]
        let index = Int(code) - 16
        return (levels[index / 36], levels[(index / 6) % 6], levels[index % 6])
    }
    let level = UInt8(8 + 10 * (Int(code) - 232))
    return (level, level, level)
}
