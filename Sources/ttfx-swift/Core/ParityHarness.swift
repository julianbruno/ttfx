import Foundation

public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: Data
    public let stderr: Data
}

public enum ProcessRunnerError: Error, Sendable {
    case executableUnavailable(URL)
    case launchFailed(String)
    case timedOut(TimeInterval)
    case nonzeroExit(Int32, stdout: Data, stderr: Data)
    case unsupportedPlatform
}

public struct ProcessRunner: Sendable {
    public init() {}

    public static func resolveExecutable(_ name: String, environment: [String: String] = ProcessInfo.processInfo.environment) throws -> URL {
        #if os(Windows)
        let separator: Character = ";"
        let path = environment.first { $0.key.uppercased() == "PATH" }?.value ?? ""
        let pathExtensions = environment.first { $0.key.uppercased() == "PATHEXT" }?.value ?? ".EXE;.COM"
        let extensions = name.contains(".") ? [""] : pathExtensions.split(separator: ";").map(String.init)
        #else
        let separator: Character = ":"
        let path = environment["PATH"] ?? ""
        let extensions = [""]
        #endif
        for directory in path.split(separator: separator) {
            for suffix in extensions {
                let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name + suffix)
                if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
            }
        }
        throw ProcessRunnerError.executableUnavailable(URL(fileURLWithPath: name))
    }

    public func run(
        executable: URL,
        arguments: [String],
        stdin: Data,
        environment: [String: String],
        currentDirectory: URL?,
        timeout: TimeInterval
    ) throws -> ProcessResult {
        #if os(Linux) || os(Windows) || os(macOS)
        guard executable.isFileURL, FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw ProcessRunnerError.executableUnavailable(executable)
        }

        let process = Process()
        // A full effect can emit megabytes. Pipes must be drained concurrently;
        // temporary files avoid pipe-capacity deadlocks while retaining timeout
        // handling and both complete diagnostic streams.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stdoutURL = directory.appendingPathComponent("stdout")
        let stderrURL = directory.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)
        defer { try? stdout.close(); try? stderr.close() }
        let stdinURL = directory.appendingPathComponent("stdin")
        try stdin.write(to: stdinURL)
        let input = try FileHandle(forReadingFrom: stdinURL)
        defer { try? input.close() }
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = input
        process.environment = environment
        process.currentDirectoryURL = currentDirectory

        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.launchFailed(error.localizedDescription)
        }


        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.001)
        }
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            throw ProcessRunnerError.timedOut(timeout)
        }
        process.waitUntilExit()

        let result = ProcessResult(
            exitCode: process.terminationStatus,
            stdout: try Data(contentsOf: stdoutURL),
            stderr: try Data(contentsOf: stderrURL)
        )
        guard result.exitCode == 0 else {
            throw ProcessRunnerError.nonzeroExit(result.exitCode, stdout: result.stdout, stderr: result.stderr)
        }
        return result
        #else
        throw ProcessRunnerError.unsupportedPlatform
        #endif
    }
}

public enum FixtureGeneratorError: Error, Sendable {
    case notRepository(String)
    case invalidRevision
}

public struct ParityFixture: Equatable, Sendable {
    public let revision: String
    public let frames: [Data]
}

public enum FixtureGenerator {
    public static func pinnedRevision(repositoryRoot: String, runner: ProcessRunner = .init()) throws -> String {
        let root = URL(fileURLWithPath: repositoryRoot).standardizedFileURL
        do {
            _ = try runner.run(
                executable: try ProcessRunner.resolveExecutable("git"),
                arguments: ["-C", root.path, "rev-parse", "--git-dir"],
                stdin: Data(),
                environment: ProcessInfo.processInfo.environment,
                currentDirectory: nil,
                timeout: 5
            )
        } catch {
            throw FixtureGeneratorError.notRepository(root.path)
        }

        let manifestURL = root.appendingPathComponent("tests/fixtures/effects/manifest.json")
        guard let manifest = try? String(contentsOf: manifestURL, encoding: .utf8),
              let revision = recordedRevision(in: manifest)
        else {
            throw FixtureGeneratorError.invalidRevision
        }
        return revision
    }

    private static func recordedRevision(in manifest: String) -> String? {
        let marker = "\"revision\": \""
        guard let markerRange = manifest.range(of: marker) else { return nil }
        let afterMarker = manifest[markerRange.upperBound...]
        guard let end = afterMarker.firstIndex(of: "\"") else { return nil }
        let revision = String(afterMarker[..<end])
        guard revision.count == 40, revision.allSatisfy({ $0.isHexDigit }) else { return nil }
        return revision
    }

    public static func generate(
        repositoryRoot: String,
        oracle: URL,
        arguments: [String],
        stdin: Data,
        environment: [String: String],
        runner: ProcessRunner = .init()
    ) throws -> ParityFixture {
        let revision = try pinnedRevision(repositoryRoot: repositoryRoot, runner: runner)
        let result = try runner.run(
            executable: oracle,
            arguments: arguments,
            stdin: stdin,
            environment: environment,
            currentDirectory: URL(fileURLWithPath: repositoryRoot).standardizedFileURL,
            timeout: 30
        )
        return ParityFixture(revision: revision, frames: try FrameDumpDecoder.decode(result.stdout))
    }
}

public enum FrameDumpError: Error, Equatable, Sendable {
    case invalidLength
    case truncatedFrame
    case missingFrameTerminator
}

public enum FrameDumpDecoder {
    public static func decode(_ data: Data) throws -> [Data] {
        var offset = 0
        var frames: [Data] = []
        while offset < data.count {
            guard let lineEnd = data[offset...].firstIndex(of: 10),
                  let length = Int(String(decoding: data[offset..<lineEnd], as: UTF8.self))
            else {
                throw FrameDumpError.invalidLength
            }
            let frameStart = lineEnd + 1
            let frameEnd = frameStart + length
            guard frameEnd <= data.count else { throw FrameDumpError.truncatedFrame }
            frames.append(data[frameStart..<frameEnd])
            guard frameEnd < data.count else { throw FrameDumpError.missingFrameTerminator }
            guard data[frameEnd] == 10 else { throw FrameDumpError.missingFrameTerminator }
            offset = frameEnd + 1
        }
        return frames
    }
}

public struct ByteMismatch: Equatable, Sendable {
    public let offset: Int
    public let expected: UInt8?
    public let actual: UInt8?
}

public struct CellMismatch: Equatable, Sendable {
    public let tick: Int
    public let column: Int
    public let row: Int
    public let expected: Cell?
    public let actual: Cell?

    public init(tick: Int, column: Int, row: Int, expected: Cell?, actual: Cell?) {
        self.tick = tick
        self.column = column
        self.row = row
        self.expected = expected
        self.actual = actual
    }
}

public enum FrameParity {
    public static func firstMismatch(expected: Data, actual: Data) -> ByteMismatch? {
        let commonCount = min(expected.count, actual.count)
        for offset in 0..<commonCount where expected[offset] != actual[offset] {
            return ByteMismatch(offset: offset, expected: expected[offset], actual: actual[offset])
        }
        guard expected.count != actual.count else { return nil }
        return ByteMismatch(
            offset: commonCount,
            expected: commonCount < expected.count ? expected[commonCount] : nil,
            actual: commonCount < actual.count ? actual[commonCount] : nil
        )
    }

    public static func firstCellMismatch(expected: Frame, actual: Frame, tick: Int) -> CellMismatch? {
        let commonCount = min(expected.cells.count, actual.cells.count)
        for offset in 0..<commonCount where expected.cells[offset] != actual.cells[offset] {
            return CellMismatch(
                tick: tick,
                column: offset % expected.columns + 1,
                row: expected.rows - offset / expected.columns,
                expected: expected.cells[offset],
                actual: actual.cells[offset]
            )
        }
        guard expected.cells.count != actual.cells.count else { return nil }
        let offset = commonCount
        return CellMismatch(
            tick: tick,
            column: offset % expected.columns + 1,
            row: max(expected.rows - offset / expected.columns, 1),
            expected: offset < expected.cells.count ? expected.cells[offset] : nil,
            actual: offset < actual.cells.count ? actual.cells[offset] : nil
        )
    }
}
