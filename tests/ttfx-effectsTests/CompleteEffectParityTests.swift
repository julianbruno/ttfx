import Foundation
import Testing
import TTFXCore
import TTFXEffects

/// Full native-effect runs against the current Rust implementation. Deliberately
/// uses ordinary multiline inputs rather than the historic tiny-canvas fixtures.
@Suite(.serialized)
struct CompleteEffectParityTests {
    @Test(arguments: EffectRegistry.names, [0, 1, 2])
    func completeNativeRunMatchesRust(effectName: String, independent: Int) throws {
        let text = ["TTFX\nRust + Swift\nVisual comparison", "Native Swift\n A B C\nParity!", "Parity 2026\nSWIFT + RUST\n  Two spaces"][independent]
        let seed: UInt64 = [42, 7, 123][independent]
        let canvas = try Canvas(columns: [24, 16, 18][independent], rows: [8, 6, 7][independent])
        try assertCompleteRun(effectName: effectName, text: text, seed: seed, canvas: canvas, frameRate: 25)
    }

    @Test(arguments: ["matrix", "thunderstorm"], [60, 17, 0])
    func timedEffectsUseTheRequestedFrameRate(effectName: String, frameRate: Int) throws {
        try assertCompleteRun(effectName: effectName, text: "Clock test\nRust Swift", seed: 23,
            canvas: Canvas(columns: 16, rows: 6), frameRate: frameRate)
    }

    private func assertCompleteRun(effectName: String, text: String, seed: UInt64, canvas: Canvas, frameRate: Int) throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let limit = 10_000
        let result = try ProcessRunner().run(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["cargo", "run", "--quiet", "--", "--parity-dump",
                "--max-frames", String(limit), "--seed", String(seed),
                "--ignore-terminal-dimensions", "--canvas-width", String(canvas.columns),
                "--canvas-height", String(canvas.rows), "--frame-rate", String(frameRate), effectName],
            stdin: Data(text.utf8), environment: ProcessInfo.processInfo.environment,
            currentDirectory: root, timeout: 60)
        let expected = try FrameDumpDecoder.decode(result.stdout)
        try #require(expected.count < limit, "Rust run truncated: \(effectName)")
        var effect = try #require(EffectRegistry.makeEffect(named: effectName,
            configuration: .init(text: text, seed: seed, frameRate: frameRate), canvas: canvas,
            input: canvas.ingest(text), seed: seed))
        var firstMismatch: String?
        var actualCount = 0
        var completed = false
        for tick in 0..<limit {
            var frame = try Frame(columns: canvas.columns, rows: canvas.rows)
            let status = effect.tick(into: &frame)
            actualCount += 1
            if firstMismatch == nil, tick < expected.count {
                let actual = Self.terminalBytes(frame)
                if actual != expected[tick] {
                    let offset = zip(actual, expected[tick]).enumerated().first { $0.element.0 != $0.element.1 }?.offset ?? min(actual.count, expected[tick].count)
                    firstMismatch = "first differing frame \(tick + 1), ANSI byte \(offset), Rust \(expected[tick].count) bytes / Swift \(actual.count) bytes"
                }
            }
            if status == .complete { completed = true; break }
        }
        #expect(completed, "Swift run truncated: \(effectName)")
        #expect(actualCount == expected.count,
            "\(effectName) seed \(seed): Rust \(expected.count), Swift \(actualCount) frames")
        #expect(firstMismatch == nil, "\(effectName) seed \(seed): \(firstMismatch ?? "")")
    }

    private static func terminalBytes(_ frame: Frame) -> Data {
        var text = ""
        for row in stride(from: frame.rows, through: 1, by: -1) {
            for column in 1...frame.columns {
                let cell = frame[column: column, row: row]
                let colored = cell.foreground != 0 || cell.background == 0xFFFF_FFFE
                if colored {
                    text += "\u{1B}[38;2;\(cell.foreground >> 16);\((cell.foreground >> 8) & 255);\(cell.foreground & 255)m"
                }
                text.unicodeScalars.append(UnicodeScalar(cell.codepoint)!)
                if colored { text += "\u{1B}[0m" }
            }
            if row > 1 { text += "\n" }
        }
        return Data(text.utf8)
    }
}
