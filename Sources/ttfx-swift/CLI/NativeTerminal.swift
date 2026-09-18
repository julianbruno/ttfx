import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

#if canImport(Darwin) || canImport(Glibc)
// A handler only stores a sig_atomic_t-sized flag; all rendering and teardown
// happens on the synchronous driver, never from a signal callback.
nonisolated(unsafe) private var requestedSignal: sig_atomic_t = 0
private func terminalSignal(_ signal: Int32) { requestedSignal = signal }

final class NativeTerminal {
    enum Error: Swift.Error { case brokenPipe, writeFailed(Int32) }
    private var previous: [(Int32, sig_t?)] = []
    var cancelled: Bool { requestedSignal != 0 }
    var interactive: Bool { isatty(STDOUT_FILENO) == 1 }

    func installHandlers() {
        requestedSignal = 0
        previous.append((SIGINT, signal(SIGINT, terminalSignal)))
        previous.append((SIGPIPE, signal(SIGPIPE, SIG_IGN)))
        if interactive { previous.append((SIGTERM, signal(SIGTERM, terminalSignal))) }
    }

    func restoreHandlers() {
        for (number, handler) in previous { _ = signal(number, handler) }
        previous.removeAll()
    }

    func terminateIfRequested() {
        guard requestedSignal == SIGTERM else { return }
        _ = signal(SIGTERM, SIG_DFL)
        _ = raise(SIGTERM)
    }

    func write(_ bytes: Data) throws {
        try bytes.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                #if canImport(Darwin)
                let count = Darwin.write(STDOUT_FILENO, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                #else
                let count = Glibc.write(STDOUT_FILENO, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                #endif
                if count > 0 { offset += count; continue }
                if count < 0 && errno == EINTR { continue }
                if count < 0 && errno == EPIPE { throw Error.brokenPipe }
                throw Error.writeFailed(errno)
            }
        }
    }
}
#else
final class NativeTerminal {
    enum Error: Swift.Error { case brokenPipe }
    var cancelled: Bool { false }
    func installHandlers() {}
    func restoreHandlers() {}
    func terminateIfRequested() {}
    func write(_ bytes: Data) throws { try FileHandle.standardOutput.write(contentsOf: bytes) }
}
#endif
