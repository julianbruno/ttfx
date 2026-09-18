import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif os(Windows)
import WinSDK
import Synchronization
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
    static var inputIsInteractive: Bool { isatty(STDIN_FILENO) == 1 }
    func dimensions() -> TerminalDimensions? {
        var size = winsize()
        guard ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &size) == 0, size.ws_col > 0, size.ws_row > 0 else { return nil }
        return TerminalDimensions(columns: Int(size.ws_col), rows: Int(size.ws_row))
    }

    func installHandlers() throws {
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
#elseif os(Windows)
private let consoleCancellation = Atomic<UInt32>(0)
private let consoleControl: @convention(c) (DWORD) -> WindowsBool = { event in
    // Close/logoff/shutdown retain OS default termination: console writes are
    // not reliable from those callbacks. Ctrl-C/Break are cooperative only.
    guard event == DWORD(CTRL_C_EVENT) || event == DWORD(CTRL_BREAK_EVENT) else { return false }
    consoleCancellation.store(1, ordering: .sequentiallyConsistent)
    return true
}

final class NativeTerminal {
    enum Error: Swift.Error { case brokenPipe, writeFailed(DWORD), setupFailed(DWORD) }
    private let handle = GetStdHandle(DWORD(bitPattern: -11))
    private var originalMode: DWORD?
    private var registered = false
    var cancelled: Bool { consoleCancellation.load(ordering: .sequentiallyConsistent) != 0 }
    var interactive: Bool {
        var mode: DWORD = 0
        return GetConsoleMode(handle, &mode)
    }
    static var inputIsInteractive: Bool {
        var mode: DWORD = 0
        return GetConsoleMode(GetStdHandle(DWORD(bitPattern: -10)), &mode)
    }
    func dimensions() -> TerminalDimensions? {
        var info = CONSOLE_SCREEN_BUFFER_INFO()
        guard GetConsoleScreenBufferInfo(handle, &info) else { return nil }
        return TerminalDimensions(columns: Int(info.srWindow.Right - info.srWindow.Left + 1),
            rows: Int(info.srWindow.Bottom - info.srWindow.Top + 1))
    }
    func installHandlers() throws {
        consoleCancellation.store(0, ordering: .sequentiallyConsistent)
        var mode: DWORD = 0
        if GetConsoleMode(handle, &mode) {
            guard SetConsoleMode(handle, mode | DWORD(ENABLE_PROCESSED_OUTPUT) | DWORD(ENABLE_VIRTUAL_TERMINAL_PROCESSING)) else {
                throw Error.setupFailed(GetLastError())
            }
            originalMode = mode
        }
        if SetConsoleCtrlHandler(consoleControl, true) {
            registered = true
        } else if interactive {
            let error = GetLastError()
            restoreHandlers()
            throw Error.setupFailed(error)
        }
        // A detached redirected process may have no console control channel.
        // Its file/pipe output remains usable without a registered handler.
    }
    func restoreHandlers() {
        if registered { _ = SetConsoleCtrlHandler(consoleControl, false); registered = false }
        if let originalMode { _ = SetConsoleMode(handle, originalMode); self.originalMode = nil }
    }
    func terminateIfRequested() {}
    func write(_ bytes: Data) throws {
        if interactive {
            let units = Array(String(decoding: bytes, as: UTF8.self).utf16)
            try units.withUnsafeBufferPointer { buffer in
                var offset = 0
                while offset < buffer.count {
                    var written: DWORD = 0
                    let count = DWORD(min(buffer.count - offset, 16_384))
                    guard WriteConsoleW(handle, buffer.baseAddress!.advanced(by: offset), count, &written, nil), written > 0 else {
                        throw Error.writeFailed(GetLastError())
                    }
                    offset += Int(written)
                }
            }
        } else {
            try bytes.withUnsafeBytes { buffer in
                var offset = 0
                while offset < buffer.count {
                    var written: DWORD = 0
                    let count = DWORD(min(buffer.count - offset, 65_536))
                    guard WriteFile(handle, buffer.baseAddress!.advanced(by: offset), count, &written, nil), written > 0 else {
                        let error = GetLastError()
                        if error == DWORD(ERROR_BROKEN_PIPE) || error == DWORD(ERROR_NO_DATA) { throw Error.brokenPipe }
                        throw Error.writeFailed(error)
                    }
                    offset += Int(written)
                }
            }
        }
    }
}
#else
final class NativeTerminal {
    enum Error: Swift.Error { case brokenPipe }
    var cancelled: Bool { false }
    var interactive: Bool { false }
    static var inputIsInteractive: Bool { false }
    func dimensions() -> TerminalDimensions? { nil }
    func installHandlers() throws {}
    func restoreHandlers() {}
    func terminateIfRequested() {}
    func write(_ bytes: Data) throws { try FileHandle.standardOutput.write(contentsOf: bytes) }
}
#endif
