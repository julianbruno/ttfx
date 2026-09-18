import Foundation

/// Injected monotonic time keeps pacing independent of OS handles and effect time.
struct TerminalClock {
    var now: () -> Double
    var sleep: (Double) -> Void

    static var continuous: Self {
        Self(now: { ProcessInfo.processInfo.systemUptime }, sleep: { Thread.sleep(forTimeInterval: $0) })
    }
}

struct TerminalRuntime {
    let columns: Int
    let rows: Int
    let options: TerminalOptions
    var clock: TerminalClock
    var write: (Data) throws -> Void
    private var lastPrinted: Double

    init(columns: Int, rows: Int, options: TerminalOptions, clock: TerminalClock = .continuous,
         write: @escaping (Data) throws -> Void) {
        self.columns = columns
        self.rows = rows
        self.options = options
        self.clock = clock
        self.write = write
        self.lastPrinted = clock.now()
    }

    var repaint: String { "\u{1B}8\u{1B}7\u{1B}[\(rows)A" }

    func prepare() throws {
        var bytes = "\u{1B}[?25l"
        if options.reuseCanvas { bytes += repaint }
        bytes += String(repeating: String(repeating: " ", count: columns) + "\n", count: rows)
        bytes += "\u{1B}7"
        try write(Data(bytes.utf8))
    }

    mutating func printFrame(_ bytes: Data, virtualClock: Bool, cancelled: () -> Bool = { false }) throws {
        if options.frameRate > 0 && !virtualClock {
            let remaining = 1 / Double(options.frameRate) - (clock.now() - lastPrinted)
            if remaining > 0 { clock.sleep(remaining) }
            lastPrinted = clock.now()
        }
        guard !cancelled() else { return }
        try write(Data(repaint.utf8) + bytes)
    }

    func finish() throws {
        let cursor = options.noRestoreCursor ? "" : "\u{1B}[?25h"
        try write(Data((cursor + (options.noEOL ? "" : "\n")).utf8))
    }
}
