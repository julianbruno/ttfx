import ArgumentParser
import Foundation
import TTFXCore
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

    @Argument(parsing: .allUnrecognized, help: "Per-effect TTE flags after the effect name")
    public var effectArguments: [String] = []

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
        if let effectName {
            do {
                _ = try ParsedEffectSettings.parse(effectName: effectName, arguments: effectArguments)
            } catch let error as EffectOptionError {
                throw ValidationError(error.description)
            }
        } else if !effectArguments.isEmpty {
            throw ValidationError("unexpected arguments: \(effectArguments.joined(separator: " "))")
        }
    }

    public static func helpMessage(forEffect name: String) -> String {
        EffectFlagCatalog.help(for: name)
    }

    public static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if let effect = effectHelpRequest(in: arguments) {
            print(helpMessage(forEffect: effect))
            return
        }
        do {
            let command = try parse(arguments)
            try command.run()
        } catch {
            exit(withError: error)
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
        let selection = try selectEffect()
        if parityDump {
            try dumpParity(selection: selection)
            return
        }
        try runTerminalStream(selection: selection)
    }

    public static let completionOptionNames: [String] = [
        "--version",
        "--input-file",
        "--tab-width",
        "--xterm-colors",
        "--no-color",
        "--terminal-background-color",
        "--existing-color-handling",
        "--wrap-text",
        "--frame-rate",
        "--canvas-width",
        "--canvas-height",
        "--anchor-canvas",
        "--anchor-text",
        "--ignore-terminal-dimensions",
        "--reuse-canvas",
        "--no-eol",
        "--no-restore-cursor",
        "--seed",
        "--print-completion",
        "--random-effect",
        "--include-effects",
        "--exclude-effects",
        "--help"
    ]

    public static func completionScript(for shell: CompletionShell) -> String {
        let effects = TTFXEffectRegistry.names.joined(separator: " ")
        let options = completionOptionNames.joined(separator: " ")
        switch shell {
        case .bash:
            return """
            # bash completion for ttfx
            _ttfx() {
                local cur
                COMPREPLY=()
                cur="${COMP_WORDS[COMP_CWORD]}"

                if [[ "$cur" == -* ]]; then
                    COMPREPLY=( $(compgen -W "\(options)" -- "$cur") )
                else
                    COMPREPLY=( $(compgen -W "\(effects)" -- "$cur") )
                fi
                return 0
            }
            complete -F _ttfx ttfx
            """
        case .zsh:
            let zshOptions = completionOptionNames
                .map { "'\($0)'" }
                .joined(separator: " \\n    ")
            return """
            #compdef ttfx
            # zsh completion for ttfx
            local -a effects
            effects=(\(effects))
            _arguments \
                \(zshOptions) \
                '*:effect:($effects)'
            """
        }
    }



    static func runForTesting(arguments: [String], standardInput: Data) throws -> Data {
        let cli = try parse(arguments)
        return try cli.renderOutput(standardInput: standardInput)
    }

    func renderOutput(standardInput: Data) throws -> Data {
        let selection = try selectEffect()

        let text = try inputText(standardInput: standardInput)
        let columns = terminalOptions.canvasWidth > 0 ? terminalOptions.canvasWidth : inferredColumns(from: text)
        let rows = terminalOptions.canvasHeight > 0 ? terminalOptions.canvasHeight : inferredRows(from: text)
        let canvas = try Canvas(columns: columns, rows: rows)
        let configuration = EffectConfiguration(text: text, seed: selection.seed, frameRate: terminalOptions.frameRate, initialRNG: selection.rng)
        let input = canvas.ingest(text)
        var effect = try makeEffect(named: selection.name, configuration: configuration, canvas: canvas, input: input)
        var output = Data()
        var runtime = TerminalRuntime(columns: columns, rows: rows, options: terminalOptions,
            write: { output.append($0) })
        if !parityDump && !m0Dump { try runtime.prepare() }
        let limit = parityDump || m0Dump ? (maxFrames ?? UInt64.max) : UInt64.max
        var emitted: UInt64 = 0
        while emitted < limit {
            var frame = try Frame(columns: canvas.columns, rows: canvas.rows)
            let status = effect.tick(into: &frame)
            let bytes = terminalBytes(for: frame)
            if parityDump || m0Dump {
                output.append(Data("\(bytes.count)\n".utf8))
                output.append(bytes)
                output.append(10)
            } else {
                try runtime.printFrame(bytes, virtualClock: true)
            }
            emitted += 1
            if status == .complete { break }
        }
        if !parityDump && !m0Dump { try runtime.finish() }
        return output
    }

    struct Selection {
        let name: String
        let seed: UInt64
        let rng: Xoshiro256PlusPlus
    }

    func selectEffect(entropy: () -> UInt64 = { UInt64.random(in: .min ... .max) }) throws -> Selection {
        let resolvedSeed = seed ?? entropy()
        var rng = Xoshiro256PlusPlus(seed: resolvedSeed)
        if randomEffect {
            let candidates = randomEffectCandidates()
            guard !candidates.isEmpty else {
                throw ValidationError("No effects available after filtering.")
            }
            let name = candidates[rng.integer(in: 0..<candidates.count)]
            return Selection(name: name, seed: resolvedSeed, rng: rng)
        }
        guard let effectName else { throw ValidationError("No effect specified.") }
        return Selection(name: effectName, seed: resolvedSeed, rng: rng)
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

private let explicitBlackForegroundSentinel: UInt32 = 0xFFFF_FFFE

extension TTFXCLI {
    func runTerminalStream(selection: Selection) throws {
        let text = try inputText()
        let columns = terminalOptions.canvasWidth > 0 ? terminalOptions.canvasWidth : inferredColumns(from: text)
        let rows = terminalOptions.canvasHeight > 0 ? terminalOptions.canvasHeight : inferredRows(from: text)
        let canvas = try Canvas(columns: columns, rows: rows)
        let configuration = EffectConfiguration(text: text, seed: selection.seed, frameRate: terminalOptions.frameRate, initialRNG: selection.rng)
        let input = canvas.ingest(text)
        var effect = try makeEffect(named: selection.name, configuration: configuration, canvas: canvas, input: input)
        let terminal = NativeTerminal()
        terminal.installHandlers()
        defer { terminal.restoreHandlers() }
        var runtime = TerminalRuntime(columns: columns, rows: rows, options: terminalOptions, write: terminal.write)
        do { try runtime.prepare() }
        catch NativeTerminal.Error.brokenPipe { return }
        var finished = false
        defer { if !finished { try? runtime.finish() } }
        while !terminal.cancelled {
            var frame = try Frame(columns: canvas.columns, rows: canvas.rows)
            let status = effect.tick(into: &frame)
            if terminal.cancelled { break }
            do { try runtime.printFrame(terminalBytes(for: frame), virtualClock: virtualClock, cancelled: { terminal.cancelled }) }
            catch NativeTerminal.Error.brokenPipe { return }
            if status == .complete { break }
        }
        if terminal.cancelled {
            try? runtime.finish()
            finished = true
            terminal.terminateIfRequested()
            throw ExitCode(1)
        }
    }

    func dumpParity(selection: Selection) throws {
        let text = try inputText()
        let columns = terminalOptions.canvasWidth > 0 ? terminalOptions.canvasWidth : inferredColumns(from: text)
        let rows = terminalOptions.canvasHeight > 0 ? terminalOptions.canvasHeight : inferredRows(from: text)
        let canvas = try Canvas(columns: columns, rows: rows)
        let configuration = EffectConfiguration(text: text, seed: selection.seed, frameRate: terminalOptions.frameRate, initialRNG: selection.rng)
        let input = canvas.ingest(text)
        var effect = try makeEffect(named: selection.name, configuration: configuration, canvas: canvas, input: input)
        var emitted: UInt64 = 0
        let limit = maxFrames ?? UInt64.max
        while emitted < limit {
            var frame = try Frame(columns: canvas.columns, rows: canvas.rows)
            let status = effect.tick(into: &frame)
            writeParityFrame(frame)
            emitted += 1
            if status == .complete { break }
        }
        FileHandle.standardError.write(Data("frames=\(emitted)\n".utf8))
    }

    func inputText(standardInput: Data) throws -> String {
        if let inputFile {
            return String(decoding: try Data(contentsOf: URL(fileURLWithPath: inputFile)), as: UTF8.self)
        }
        return String(decoding: standardInput, as: UTF8.self)
    }

    func inputText() throws -> String {
        let data: Data
        if let inputFile {
            data = try Data(contentsOf: URL(fileURLWithPath: inputFile))
        } else {
            data = FileHandle.standardInput.readDataToEndOfFile()
        }
        return String(decoding: data, as: UTF8.self)
    }

    func makeEffect(named name: String, configuration: EffectConfiguration, canvas: Canvas, input: InputText) throws -> any Effect {
        let settings: ParsedEffectSettings
        do {
            settings = (!randomEffect && name == effectName)
                ? try ParsedEffectSettings.parse(effectName: name, arguments: effectArguments)
                : .empty
        } catch let error as EffectOptionError {
            throw ValidationError(error.description)
        }
        guard let effect = EffectRegistry.makeEffect(
            named: name,
            configuration: configuration,
            canvas: canvas,
            input: input,
            seed: configuration.seed,
            settings: settings
        ) else {
            throw ValidationError("unknown effect '\(name)'")
        }
        return effect
    }


    func writeParityFrame(_ frame: Frame) {
        let bytes = terminalBytes(for: frame)
        FileHandle.standardOutput.write(Data("\(bytes.count)\n".utf8))
        FileHandle.standardOutput.write(bytes)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    func terminalBytes(for frame: Frame) -> Data {
        var output = Data()
        for row in stride(from: frame.rows, through: 1, by: -1) {
            for column in 1...frame.columns {
                let cell = frame[column: column, row: row]
                if cell.foreground != 0 || cell.background == explicitBlackForegroundSentinel {
                    let red = cell.foreground >> 16
                    let green = (cell.foreground >> 8) & 0xFF
                    let blue = cell.foreground & 0xFF
                    output.append(Data("\u{1B}[38;2;\(red);\(green);\(blue)m".utf8))
                }
                output.append(Data(String(UnicodeScalar(cell.codepoint) ?? " ").utf8))
                if cell.foreground != 0 || cell.background == explicitBlackForegroundSentinel {
                    output.append(Data("\u{1B}[0m".utf8))
                }
            }
            if row != 1 { output.append(10) }
        }
        return output
    }

    func inferredColumns(from text: String) -> Int {
        max(1, text.split(separator: "\n", omittingEmptySubsequences: false).map(\.count).max() ?? 1)
    }

    func inferredRows(from text: String) -> Int {
        max(1, text.split(separator: "\n", omittingEmptySubsequences: false).count)
    }
}

private func effectHelpRequest(in arguments: [String]) -> String? {
    guard let effectIndex = arguments.firstIndex(where: { TTFXEffectRegistry.contains($0) }) else {
        return nil
    }
    let rest = arguments[(effectIndex + 1)...]
    guard rest.contains("-h") || rest.contains("--help") else { return nil }
    return arguments[effectIndex]
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
