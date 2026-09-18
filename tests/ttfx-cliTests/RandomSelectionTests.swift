import Foundation
import Testing
import TTFXCore
@testable import TTFXCLI

@Suite(.serialized) struct RandomSelectionTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test(arguments: TTFXEffectRegistry.names)
    func singletonSelectionPreservesConsumedRNG(effect: String) throws {
        try compare(seed: 42, included: effect)
    }

    @Test(arguments: [UInt64(0), 7, 42, 123])
    func multipleCandidatesUseRegistryOrderAndContinuation(seed: UInt64) throws {
        try compare(seed: seed, included: "rings,decrypt,randomsequence,print")
    }

    @Test func omittedSeedUsesInjectedNativeEntropyAndExplicitSeedDoesNot() throws {
        let implicit = try TTFXCLI.parse(["--random-effect", "--include-effects", "decrypt"])
        let selection = try implicit.selectEffect(entropy: { 123 })
        #expect(selection.seed == 123)
        var expected = Xoshiro256PlusPlus(seed: 123)
        _ = expected.integer(in: 0..<1)
        #expect(selection.rng == expected)
        let explicit = try TTFXCLI.parse(["--seed", "42", "print"])
        let explicitSelection = try explicit.selectEffect(entropy: {
            Issue.record("Explicit seeds must not request entropy")
            return 0
        })
        #expect(explicitSelection.seed == 42)
    }

    private func compare(seed: UInt64, included: String) throws {
        let args = ["--parity-dump", "--virtual-clock", "--max-frames", "12", "--seed", String(seed),
            "--ignore-terminal-dimensions", "--canvas-width", "12", "--canvas-height", "6",
            "--random-effect", "--include-effects"] + included.split(separator: ",").map(String.init)
        let runner = ProcessRunner()
        let input = Data("TTFX\nRust + Swift\nVisual comparison".utf8)
        let environment = ProcessInfo.processInfo.environment
        let rust = try runner.run(executable: ProcessRunner.resolveExecutable("cargo"), arguments: ["run", "--quiet", "--"] + args,
            stdin: input, environment: environment, currentDirectory: root, timeout: 60)
        #if os(Windows)
        let swiftName = "ttfx.exe"
        #else
        let swiftName = "ttfx"
        #endif
        let swift = try runner.run(executable: root.appendingPathComponent(".build/debug/" + swiftName), arguments: args,
            stdin: input, environment: environment, currentDirectory: root, timeout: 20)
        let matches = swift.stdout == rust.stdout
        #expect(matches, "Random selection and continued RNG must match Rust: \(included), seed \(seed)")
    }
}

@Suite struct ProcessRunnerTests {
    @Test func runnerAcceptsLargeUnreadStdinWithoutPipeDeadlock() throws {
        let runner = ProcessRunner()
        let result = try runner.run(executable: ProcessRunner.resolveExecutable("swift"), arguments: ["--version"],
            stdin: Data(repeating: 65, count: 2 * 1_048_576), environment: ProcessInfo.processInfo.environment,
            currentDirectory: nil, timeout: 10)
        #expect(result.exitCode == 0)
        #expect(String(decoding: result.stdout, as: UTF8.self).contains("Swift version"))
    }

    @Test func runnerIsNotRestrictedToMacOS() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Sources/ttfx-swift/Core/ParityHarness.swift"), encoding: .utf8)
        #expect(!source.contains("#if os(macOS)"), "Oracle runner must use Foundation Process on Linux and Windows too")
    }
}
