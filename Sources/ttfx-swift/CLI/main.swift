import ArgumentParser
import Foundation
import TTFXEffects

public enum ExistingColorHandling: String, ExpressibleByArgument, Equatable, Sendable {
    case always
    case dynamic
    case ignore
}

public enum CanvasAnchor: String, ExpressibleByArgument, Equatable, Sendable {
    case nw, n, ne, w, e, sw, s, se
    case center = "c"
}

public enum CompletionShell: String, ExpressibleByArgument, Equatable, Sendable {
    case bash
    case zsh
}

public struct TerminalColor: ExpressibleByArgument, Equatable, Sendable {
    public let rawValue: String

    public init?(argument: String) {
        if argument.count <= 3 {
            guard let code = Int(argument), (0...255).contains(code) else { return nil }
        } else {
            let hex = argument.hasPrefix("#") ? String(argument.dropFirst()) : argument
            guard hex.count == 6, hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        }
        self.rawValue = argument
    }
}

public struct TerminalOptions: ParsableArguments {
    @Option(name: .long, transform: positiveInt)
    public var tabWidth: Int = 4

    @Flag(name: .long)
    public var xtermColors: Bool = false

    @Flag(name: .long)
    public var noColor: Bool = false

    @Option(name: .long)
    public var terminalBackgroundColor: TerminalColor = TerminalColor(argument: "#000000")!

    @Option(name: .long)
    public var existingColorHandling: ExistingColorHandling = .ignore

    @Flag(name: .long)
    public var wrapText: Bool = false

    @Option(name: .long, transform: nonNegativeInt)
    public var frameRate: Int = 60

    @Option(name: .long, transform: canvasDimension)
    public var canvasWidth: Int = -1

    @Option(name: .long, transform: canvasDimension)
    public var canvasHeight: Int = -1

    @Option(name: .long)
    public var anchorCanvas: CanvasAnchor = .sw

    @Option(name: .long)
    public var anchorText: CanvasAnchor = .sw

    @Flag(name: .long)
    public var ignoreTerminalDimensions: Bool = false

    @Flag(name: .long)
    public var reuseCanvas: Bool = false

    @Flag(name: .customLong("no-eol"))
    public var noEOL: Bool = false

    @Flag(name: .long)
    public var noRestoreCursor: Bool = false

    public init() {}
}

public enum TTFXEffectRegistry {
    public static let names = EffectRegistry.names

    public static func contains(_ name: String) -> Bool {
        EffectRegistry.contains(name)
    }
}

@main
public struct TTFXCLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "ttfx",
        abstract: "Terminal text effects (Swift port of terminaltexteffects)",
        discussion: "Effects: \(TTFXEffectRegistry.names.joined(separator: ", "))"
    )

    @Flag(name: [.customShort("v"), .long], help: "Print the version and exit")
    public var version: Bool = false

    @Option(name: [.customShort("i"), .long])
    public var inputFile: String?

    @OptionGroup
    public var terminalOptions: TerminalOptions

    @Option(name: .long)
    public var seed: UInt64?

    @Option(name: .long)
    public var printCompletion: CompletionShell?

    @Flag(name: [.customShort("R"), .long])
    public var randomEffect: Bool = false

    @Option(name: .long, parsing: .upToNextOption)
    public var includeEffects: [String] = []

    @Option(name: .long, parsing: .upToNextOption)
    public var excludeEffects: [String] = []

    @Flag(name: .long, help: .hidden)
    public var m0Dump: Bool = false

    @Flag(name: .long, help: .hidden)
    public var parityDump: Bool = false

    @Option(name: .long, help: .hidden)
    public var maxFrames: UInt64?

    @Flag(name: .long, help: .hidden)
    public var virtualClock: Bool = false

    @Argument(help: "Effect to run. Use one of: \(TTFXEffectRegistry.names.joined(separator: ", "))")
    public var effectName: String?

    public init() {}

    public var selectedEffectName: String? {
        if randomEffect { return nil }
        return effectName
    }

    public mutating func validate() throws {
        try validateEffectFilters(includeEffects, option: "--include-effects")
        try validateEffectFilters(excludeEffects, option: "--exclude-effects")
        if !includeEffects.isEmpty, !excludeEffects.isEmpty {
            throw ValidationError("--include-effects conflicts with --exclude-effects")
        }
        if let effectName, !TTFXEffectRegistry.contains(effectName) {
            throw ValidationError("unknown effect '\(effectName)'")
        }
    }

    public func run() throws {
        if version {
            print("ttfx-swift")
            return
        }
        if let printCompletion {
            print(Self.completionScript(for: printCompletion))
            return
        }
        if randomEffect {
            let candidates = randomEffectCandidates()
            guard !candidates.isEmpty else {
                throw ValidationError("No effects available after filtering.")
            }
            print("Swift renderer pending for random effect selection")
            return
        }
        guard effectName != nil else {
            throw ValidationError("No effect specified.")
        }
        print("Swift ANSI rendering is implemented in Phase 3.2; CLI parsing selected '\(selectedEffectName!)'.")
    }

    public static func completionScript(for shell: CompletionShell) -> String {
        switch shell {
        case .bash:
            return "# bash completion for ttfx\n_ttfx_effects=\"\(TTFXEffectRegistry.names.joined(separator: " "))\""
        case .zsh:
            return "#compdef ttfx\n# zsh completion for ttfx\nlocal -a effects=(\(TTFXEffectRegistry.names.joined(separator: " ")))"
        }
    }

    public func randomEffectCandidates() -> [String] {
        var names = TTFXEffectRegistry.names
        if !includeEffects.isEmpty {
            names = names.filter { includeEffects.contains($0) }
        }
        if !excludeEffects.isEmpty {
            names = names.filter { !excludeEffects.contains($0) }
        }
        return names
    }
}

private func validateEffectFilters(_ names: [String], option: String) throws {
    for name in names where !TTFXEffectRegistry.contains(name) {
        throw ValidationError("\(option) contains unknown effect '\(name)'")
    }
}

private func positiveInt(_ value: String) throws -> Int {
    let parsed = try intValue(value)
    guard parsed > 0 else { throw ValidationError("\(parsed) is not > 0") }
    return parsed
}

private func nonNegativeInt(_ value: String) throws -> Int {
    let parsed = try intValue(value)
    guard parsed >= 0 else { throw ValidationError("\(parsed) is not >= 0") }
    return parsed
}

private func canvasDimension(_ value: String) throws -> Int {
    let parsed = try intValue(value)
    guard parsed >= -1 else { throw ValidationError("\(parsed) is not >= -1") }
    return parsed
}

private func intValue(_ value: String) throws -> Int {
    guard let parsed = Int(value) else {
        throw ValidationError("invalid int value: '\(value)'")
    }
    return parsed
}
