import Foundation
import Testing
@testable import TTFXCLI

@Suite struct TerminalRuntimeTests {
    @Test func redirectedStreamUsesTerminalLifecycle() throws {
        let cli = try TTFXCLI.parse(["--seed", "42", "--frame-rate", "0", "print"])
        let output = try cli.renderOutput(standardInput: Data("Hi".utf8))
        #expect(output.starts(with: Data("\u{1B}[?25l  \n\u{1B}7\u{1B}8\u{1B}7\u{1B}[1A".utf8)))
        #expect(output.suffix(7) == Data("\u{1B}[?25h\n".utf8))
    }
}

extension TerminalRuntimeTests {
    @Test func pacingSleepsRemainderWithoutCatchup() throws {
        var time = 10.0
        var sleeps: [Double] = []
        let clock = TerminalClock(now: { time }, sleep: { sleeps.append($0); time += $0 })
        var options = TerminalOptions()
        options.frameRate = 10
        var runtime = TerminalRuntime(columns: 2, rows: 1, options: options, clock: clock, write: { _ in })
        try runtime.printFrame(Data(), virtualClock: false)
        time += 0.03
        try runtime.printFrame(Data(), virtualClock: false)
        time += 1
        try runtime.printFrame(Data(), virtualClock: false)
        try runtime.printFrame(Data(), virtualClock: false)
        #expect(sleeps.count == 3)
        #expect(abs(sleeps[0] - 0.1) < 0.000001)
        #expect(abs(sleeps[1] - 0.07) < 0.000001)
        #expect(abs(sleeps[2] - 0.1) < 0.000001)
    }

    @Test func zeroRateAndVirtualClockNeverSleep() throws {
        for virtual in [false, true] {
            var options = TerminalOptions()
            options.frameRate = virtual ? 60 : 0
            var slept = false
            var runtime = TerminalRuntime(columns: 1, rows: 1, options: options,
                clock: TerminalClock(now: { 0 }, sleep: { _ in slept = true }), write: { _ in })
            try runtime.printFrame(Data(), virtualClock: virtual)
            #expect(!slept)
        }
    }

    @Test func reuseAndTeardownFlags() throws {
        var options = TerminalOptions()
        options.reuseCanvas = true
        options.noEOL = true
        options.noRestoreCursor = true
        var output = Data()
        let runtime = TerminalRuntime(columns: 2, rows: 1, options: options, write: { output.append($0) })
        try runtime.prepare()
        try runtime.finish()
        #expect(output == Data("\u{1B}[?25l\u{1B}8\u{1B}7\u{1B}[1A  \n\u{1B}7".utf8))
    }
}

extension TerminalRuntimeTests {
    @Test func cancellationDuringPacingDoesNotPaintAnotherFrame() throws {
        var cancelled = false
        var output = Data()
        var options = TerminalOptions()
        options.frameRate = 60
        var runtime = TerminalRuntime(columns: 1, rows: 1, options: options,
            clock: TerminalClock(now: { 0 }, sleep: { _ in cancelled = true }), write: { output.append($0) })
        try runtime.printFrame(Data("frame".utf8), virtualClock: false, cancelled: { cancelled })
        #expect(output.isEmpty)
    }
}
