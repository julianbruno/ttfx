import Foundation
import Testing
import TTFXCore
import TTFXEffects

private struct EffectOracleManifest: Decodable {
    struct Fixture: Decodable {
        let effect: String
        let input: String
        let seed: UInt64
        let canvas: Canvas
        let frameFile: String

        struct Canvas: Decodable {
            let columns: Int
            let rows: Int
        }
    }

    let format: String
    let revision: String
    let frameEncoding: String
    let fixtures: [Fixture]
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func visibleText(in frame: Data) -> String {
    var output = String.UnicodeScalarView()
    let scalars = Array(String(decoding: frame, as: UTF8.self).unicodeScalars)
    var index = 0

    while index < scalars.count {
        if scalars[index] == "\u{1B}", index + 1 < scalars.count, scalars[index + 1] == "[" {
            index += 2
            while index < scalars.count {
                let scalar = scalars[index]
                index += 1
                if scalar.value >= 0x40 && scalar.value <= 0x7E { break }
            }
        } else {
            output.append(scalars[index])
            index += 1
        }
    }

    return String(output)
}

private func runGeneratorCheck(at root: URL) throws -> (status: Int32, stdout: String, stderr: String) {
    let process = Process()
    let stdout = Pipe()
    let stderr = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = [root.appendingPathComponent("tools/swift-parity/generate-effect-oracles.sh").path, "--check"]
    process.currentDirectoryURL = root
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()
    return (
        process.terminationStatus,
        String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
        String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    )
}

private func sha256(of file: URL) throws -> String {
    let process = Process()
    let stdout = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/shasum")
    process.arguments = ["-a", "256", file.path]
    process.standardOutput = stdout
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0, "shasum must calculate the oracle generator hash")
    let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    guard let hash = output.split(whereSeparator: \.isWhitespace).first else {
        throw NSError(domain: "EffectOracleFixtureTests", code: 1)
    }
    return String(hash)
}

@Test func effectOracleFixturesHavePinnedProvenanceAndBehavioralContent() throws {
    let root = repositoryRoot()
    let fixtureDirectory = root.appendingPathComponent("tests/fixtures/effects")
    let manifestData = try Data(contentsOf: fixtureDirectory.appendingPathComponent("manifest.json"))
    let manifest = try JSONDecoder().decode(EffectOracleManifest.self, from: manifestData)
    let currentRevision = try FixtureGenerator.pinnedRevision(repositoryRoot: root.path)
    let expectedEffects = ["print", "slide", "wipe", "expand", "rain", "bubbles", "fireworks", "swarm"]
    let expectedFrameCounts = ["print": 32, "slide": 32, "wipe": 32, "expand": 18, "rain": 32, "bubbles": 32, "fireworks": 32, "swarm": 32]

    #expect(manifest.format == "ttfx-effect-oracle-v1")
    #expect(manifest.revision == currentRevision)
    #expect(manifest.frameEncoding == "length-prefixed-utf8-terminal-frame-v1")
    #expect(manifest.fixtures.map(\.effect) == expectedEffects)

    for fixture in manifest.fixtures {
        #expect(fixture.input == "Swift\nTTE")
        #expect(fixture.seed == 42)
        #expect(fixture.canvas.columns == 12)
        #expect(fixture.canvas.rows == 6)
        #expect(fixture.frameFile == "\(fixture.effect).frames")

        let dump = try Data(contentsOf: fixtureDirectory.appendingPathComponent(fixture.frameFile))
        let frames = try FrameDumpDecoder.decode(dump)
        #expect(frames.count == expectedFrameCounts[fixture.effect])
        let visibleFrames = frames.map(visibleText(in:))
        #expect(visibleFrames.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "\(fixture.effect) must contain a visible behavioral frame")
        #expect(Set(visibleFrames).count > 1, "\(fixture.effect) must contain a visible transition")
    }
}

@Test func effectOracleGeneratorCheckIsDeterministicAndReportsCurrentFixtures() throws {
    let result = try runGeneratorCheck(at: repositoryRoot())
    #expect(result.status == 0)
    #expect(result.stdout == "Effect oracle fixtures are current.\n")
}

@Test func effectOracleGeneratorMatchesRecordedUntrackedHashBaseline() throws {
    let generator = repositoryRoot().appendingPathComponent("tools/swift-parity/generate-effect-oracles.sh")
    #expect(
        try sha256(of: generator) == "d3f7843d92277de439d1ff7ad747ef4597546b6191a9b8bb988fb547a6737c15",
        "The untracked generator baseline is recorded in native-swift-port apply progress; update its provenance deliberately when the generator changes."
    )
}
