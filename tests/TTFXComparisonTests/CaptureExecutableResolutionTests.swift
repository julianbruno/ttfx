import Foundation
import Testing
@testable import TTFXVideoCapture

struct CaptureExecutableResolutionTests {
    private func fixture(_ body: (URL, URL, URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let capture = root.appendingPathComponent("DerivedData/Build/Products/Debug/TTFXVideoCapture")
        let fallback = root.appendingPathComponent(".build/debug/ttfx")
        try FileManager.default.createDirectory(at: capture.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root, capture, fallback)
    }

    private func executable(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    @Test func derivedDataFallsBackToRepositoryDebugCLI() throws {
        try fixture { root, capture, fallback in
            try executable(fallback)
            #expect(try TTFXVideoCapture.resolveSwiftCLI(override: nil, captureExecutable: capture, repository: root) == fallback.path)
        }
    }

    @Test func executableSiblingTakesPrecedence() throws {
        try fixture { root, capture, fallback in
            let sibling = capture.deletingLastPathComponent().appendingPathComponent("ttfx")
            try executable(sibling)
            try executable(fallback)
            #expect(try TTFXVideoCapture.resolveSwiftCLI(override: nil, captureExecutable: capture, repository: root) == sibling.path)
        }
    }

    @Test func explicitOverrideIsStrict() throws {
        try fixture { root, capture, fallback in
            try executable(fallback)
            let explicit = root.appendingPathComponent("custom/ttfx")
            try executable(explicit)
            #expect(try TTFXVideoCapture.resolveSwiftCLI(override: explicit.path, captureExecutable: capture, repository: root) == explicit.path)
            #expect(throws: (any Error).self) {
                try TTFXVideoCapture.resolveSwiftCLI(override: root.appendingPathComponent("missing").path, captureExecutable: capture, repository: root)
            }
        }
    }

    @Test func missingCLIHasBuildGuidance() throws {
        try fixture { root, capture, _ in
            do {
                _ = try TTFXVideoCapture.resolveSwiftCLI(override: nil, captureExecutable: capture, repository: root)
                Issue.record("Expected a missing executable error")
            } catch {
                #expect(error.localizedDescription.contains("swift build --product ttfx"))
                #expect(error.localizedDescription.contains("--swift-cli"))
            }
        }
    }

    @Test func nonExecutableSiblingFallsBackButExplicitDoesNot() throws {
        try fixture { root, capture, fallback in
            let sibling = capture.deletingLastPathComponent().appendingPathComponent("ttfx")
            try Data().write(to: sibling)
            try executable(fallback)
            #expect(try TTFXVideoCapture.resolveSwiftCLI(override: nil, captureExecutable: capture, repository: root) == fallback.path)
            #expect(throws: (any Error).self) {
                try TTFXVideoCapture.resolveSwiftCLI(override: sibling.path, captureExecutable: capture, repository: root)
            }
        }
    }

    @Test func preflightRejectsMissingAndDirectoryDependencies() throws {
        try fixture { root, _, fallback in
            try executable(fallback)
            try TTFXVideoCapture.validateExecutable(fallback.path, label: "Rust", guidance: "cargo build --release")
            #expect(throws: (any Error).self) {
                try TTFXVideoCapture.validateExecutable(root.path, label: "ffmpeg", guidance: "--ffmpeg")
            }
            #expect(throws: (any Error).self) {
                try TTFXVideoCapture.validateExecutable(root.appendingPathComponent("missing").path, label: "Rust", guidance: "cargo build --release")
            }
        }
    }
}
