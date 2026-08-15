import Foundation
import Testing
@testable import TTFXCore

private struct RustRNGTrace: Decodable {
    let revision: String
    let source: String
    let seed: UInt64
    let choice: Int
    let closedRange: Int
    let halfOpenRange: Int
    let shuffledValues: [Int]
    let requestTrace: [String]
    let valueTrace: [UInt64]
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

@Test func effectRequiredPathEasingsMatchRustFormulas() {
    #expect(abs(PathEasing.outExpo.apply(0.5) - 0.96875) < 0.000_000_000_001)
    #expect(abs(PathEasing.outCirc.apply(0.5) - 0.866_025_403_784_438_6) < 0.000_000_000_001)
    #expect(abs(PathEasing.inOutQuart.apply(0.25) - 0.03125) < 0.000_000_000_001)
    #expect(abs(PathEasing.inOutExpo.apply(0.25) - 0.015625) < 0.000_000_000_001)
    #expect(abs(PathEasing.outSine.apply(0.5) - 0.707_106_781_186_547_5) < 0.000_000_000_001)
    #expect(abs(PathEasing.inOutSine.apply(0.25) - 0.146_446_609_406_726_2) < 0.000_000_000_001)
}

@Test func charactersRetainIndependentPreexistingColors() throws {
    var runtime = AnimationRuntime(canvas: try .init(columns: 2, rows: 1))
    let first = runtime.addCharacter("A", at: .init(column: 1, row: 1), foreground: 0x112233, background: 0x445566)
    let second = runtime.addCharacter("B", at: .init(column: 2, row: 1), foreground: 0x778899)

    #expect(runtime.character(first).preexistingForeground == 0x112233)
    #expect(runtime.character(first).preexistingBackground == 0x445566)
    #expect(runtime.character(second).preexistingForeground == 0x778899)
    #expect(runtime.character(second).preexistingBackground == nil)
}

@Test func namedRandomOperationsMatchPinnedRustRangeChoiceAndShuffleTrace() throws {
    let root = repositoryRoot()
    let traceURL = root.appendingPathComponent("tests/fixtures/rng/rust-seed-42-range-choice-shuffle.json")
    let trace = try JSONDecoder().decode(RustRNGTrace.self, from: Data(contentsOf: traceURL))
    let currentRevision = try FixtureGenerator.pinnedRevision(repositoryRoot: root.path)
    var runtime = AnimationRuntime(canvas: try .init(columns: 1, rows: 1), seed: trace.seed)
    var values = [1, 2, 3, 4]

    let choice = runtime.randomChoice(named: "choice", from: [10, 20, 30])
    let closedRange = runtime.randomInteger(named: "closed", in: -2...2)
    let halfOpenRange = runtime.randomInteger(named: "halfOpen", in: 5..<9)
    runtime.randomShuffle(named: "shuffle", &values)

    #expect(trace.revision == currentRevision)
    #expect(trace.source == "src/utils/rng.rs:57-105; tools/parity/shim.py:57-83")
    #expect(choice == trace.choice)
    #expect(closedRange == trace.closedRange)
    #expect(halfOpenRange == trace.halfOpenRange)
    #expect(values == trace.shuffledValues)
    #expect(runtime.rngRequestTrace == trace.requestTrace)
    #expect(runtime.rngValueTrace == trace.valueTrace)
}
