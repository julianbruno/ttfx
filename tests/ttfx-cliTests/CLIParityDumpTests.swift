import Foundation
import Testing
import TTFXCore
@testable import TTFXCLI

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func runSwiftCLI(_ arguments: [String], stdin: String = "Swift\nTTE", timeout: TimeInterval = 20) throws -> ProcessResult {
    try ProcessRunner().run(
        executable: repositoryRoot().appendingPathComponent(".build/debug/ttfx"),
        arguments: arguments,
        stdin: Data(stdin.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: timeout
    )
}

private func runRustCLI(_ arguments: [String], stdin: String = "Swift\nTTE", timeout: TimeInterval = 60) throws -> ProcessResult {
    try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: ["cargo", "run", "--quiet", "--"] + arguments,
        stdin: Data(stdin.utf8),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: repositoryRoot(),
        timeout: timeout
    )
}

private let parityArguments = [
    "--parity-dump", "--max-frames", "12", "--seed", "42",
    "--ignore-terminal-dimensions", "--canvas-width", "12", "--canvas-height", "6"
]

@Suite(.serialized)
struct CLIParityDumpTests {
    @Test(arguments: ["print", "wipe", "expand"])
    func swiftParityDumpMatchesLiveRustForFocusedEffects(effect: String) throws {
        let arguments = parityArguments + [effect]

        let swift = try runSwiftCLI(arguments)
        let rust = try runRustCLI(arguments)

        #expect(swift.stdout == rust.stdout, "Swift CLI --parity-dump for \(effect) must match live Rust stdout")
        #expect(try FrameDumpDecoder.decode(swift.stdout).count == 12)
        #expect(String(decoding: swift.stderr, as: UTF8.self).contains("frames=12"))
    }

    @Test func swiftParityDumpDecodesForEveryRustEffectName() throws {
        for effect in TTFXEffectRegistry.names {
            let result = try runSwiftCLI([
                "--parity-dump", "--max-frames", "1", "--seed", "42",
                "--ignore-terminal-dimensions", "--canvas-width", "12", "--canvas-height", "6",
                effect
            ])
            let frames = try FrameDumpDecoder.decode(result.stdout)
            #expect(frames.count == 1, "\(effect) should emit one length-prefixed parity frame")
            #expect(!frames[0].isEmpty, "\(effect) should not emit an empty frame")
        }
    }
}
