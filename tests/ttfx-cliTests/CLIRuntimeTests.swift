import Foundation
import Testing
import TTFXCore
import TTFXEffects
@testable import TTFXCLI

@Suite struct CLIRuntimeTests {
    @Test func everyRegistryEffectEmitsOneNativeParityDumpFrame() throws {
        for effectName in TTFXEffectRegistry.names {
            let output = try TTFXCLI.runForTesting(
                arguments: [
                    "--parity-dump",
                    "--max-frames", "1",
                    "--canvas-width", "1",
                    "--canvas-height", "1",
                    "--seed", "1",
                    effectName,
                ],
                standardInput: Data("A".utf8)
            )

            let frames = try decodeLengthPrefixedFrames(output)
            #expect(frames.count == 1, "\(effectName) should emit exactly one parity-dump frame")
            #expect(!frames[0].isEmpty, "\(effectName) should emit a non-empty frame payload")
        }
    }

    @Test func printSpeedFlagChangesParityDumpOutput() throws {
        let speedCLI = try TTFXCLI.parse([
            "--parity-dump", "--max-frames", "32", "--seed", "1",
            "--canvas-width", "12", "--canvas-height", "6",
            "print", "--print-speed", "5"
        ])
        #expect(speedCLI.effectArguments == ["--print-speed", "5"])
        let settings = try ParsedEffectSettings.parse(effectName: "print", arguments: speedCLI.effectArguments)
        #expect(settings.int("print-speed") == 5)
        var printOptions = PrintEffect.Configuration()
        printOptions.apply(settings)
        #expect(printOptions.printSpeed == 5)
        let defaultOutput = try TTFXCLI.runForTesting(
            arguments: [
                "--parity-dump", "--max-frames", "32", "--seed", "1",
                "--canvas-width", "12", "--canvas-height", "6",
                "print"
            ],
            standardInput: Data("Swift\nTTE".utf8)
        )
        let speedOutput = try TTFXCLI.runForTesting(
            arguments: [
                "--parity-dump", "--max-frames", "32", "--seed", "1",
                "--canvas-width", "12", "--canvas-height", "6",
                "print", "--print-speed", "5"
            ],
            standardInput: Data("Swift\nTTE".utf8)
        )
        #expect(!defaultOutput.isEmpty)
        #expect(!speedOutput.isEmpty)
        #expect(defaultOutput != speedOutput)
    }
}

private func decodeLengthPrefixedFrames(_ data: Data) throws -> [Data] {
    var offset = 0
    var frames: [Data] = []
    while offset < data.count {
        guard let lineEnd = data[offset...].firstIndex(of: 10),
              let length = Int(String(decoding: data[offset..<lineEnd], as: UTF8.self))
        else {
            struct InvalidLength: Error {}
            throw InvalidLength()
        }
        let frameStart = lineEnd + 1
        let frameEnd = frameStart + length
        guard frameEnd <= data.count else {
            struct TruncatedFrame: Error {}
            throw TruncatedFrame()
        }
        frames.append(data[frameStart..<frameEnd])
        guard frameEnd < data.count, data[frameEnd] == 10 else {
            struct MissingTerminator: Error {}
            throw MissingTerminator()
        }
        offset = frameEnd + 1
    }
    return frames
}
