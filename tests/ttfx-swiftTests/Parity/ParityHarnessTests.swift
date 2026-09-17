import Foundation
import Testing
@testable import TTFXCore

@Test func processRunnerPassesArgumentsLiterallyAndCapturesStreams() throws {
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/usr/bin/printf"),
        arguments: ["%s", "literal;$(not-a-command)"],
        stdin: Data(),
        environment: [:],
        currentDirectory: nil,
        timeout: 1
    )

    #expect(result.exitCode == 0)
    #expect(result.stdout == Data("literal;$(not-a-command)".utf8))
    #expect(result.stderr.isEmpty)
}

@Test func processRunnerCapturesOutputLargerThanAPipeBuffer() throws {
    let result = try ProcessRunner().run(
        executable: URL(fileURLWithPath: "/bin/dd"),
        arguments: ["if=/dev/zero", "bs=1048576", "count=2"], stdin: Data(),
        environment: [:], currentDirectory: nil, timeout: 5)
    #expect(result.stdout.count == 2 * 1_048_576)
    #expect(!result.stderr.isEmpty)
}

@Test func processRunnerRejectsMissingNonExecutableTimeoutAndNonzeroOracles() throws {
    let runner = ProcessRunner()
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    FileManager.default.createFile(atPath: temporary.path, contents: Data(), attributes: [.posixPermissions: 0o600])
    defer { try? FileManager.default.removeItem(at: temporary) }

    #expect(throws: ProcessRunnerError.self) {
        try runner.run(executable: URL(fileURLWithPath: "/missing/ttfx"), arguments: [], stdin: Data(), environment: [:], currentDirectory: nil, timeout: 1)
    }
    #expect(throws: ProcessRunnerError.self) {
        try runner.run(executable: temporary, arguments: [], stdin: Data(), environment: [:], currentDirectory: nil, timeout: 1)
    }
    #expect(throws: ProcessRunnerError.self) {
        try runner.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["1"], stdin: Data(), environment: [:], currentDirectory: nil, timeout: 0.01)
    }
    #expect(throws: ProcessRunnerError.self) {
        try runner.run(executable: URL(fileURLWithPath: "/usr/bin/false"), arguments: [], stdin: Data(), environment: [:], currentDirectory: nil, timeout: 1)
    }
}

@Test func fixtureToolsPinGitRevisionsAndRejectTruncatedFrames() throws {
    let absoluteRoot = FileManager.default.currentDirectoryPath
    let relativeRevision = try FixtureGenerator.pinnedRevision(repositoryRoot: ".")
    let absoluteRevision = try FixtureGenerator.pinnedRevision(repositoryRoot: absoluteRoot)
    let nonRepository = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: nonRepository, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: nonRepository) }

    #expect(relativeRevision == absoluteRevision)
    #expect(throws: FixtureGeneratorError.self) {
        try FixtureGenerator.pinnedRevision(repositoryRoot: nonRepository.path)
    }
    #expect(throws: FrameDumpError.self) {
        try FrameDumpDecoder.decode(Data("4\nabc\n".utf8))
    }
}

@Test func fixtureGeneratorRecordsThePinnedRevisionAndDecodedFrames() throws {
    let fixture = try FixtureGenerator.generate(
        repositoryRoot: FileManager.default.currentDirectoryPath,
        oracle: URL(fileURLWithPath: "/usr/bin/printf"),
        arguments: ["%s", "2\nok\n"],
        stdin: Data(),
        environment: [:]
    )

    #expect(fixture.revision.count == 40)
    #expect(fixture.frames == [Data("ok".utf8)])
}
