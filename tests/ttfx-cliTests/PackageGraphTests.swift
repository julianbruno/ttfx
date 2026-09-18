import Foundation
import Testing

@Suite struct PackageGraphTests {
    private func graph(cliOnly: Bool) throws -> [String: Any] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let process = Process()
        #if os(Windows)
        let executable = "swift.exe"
        let separator: Character = ";"
        #else
        let executable = "swift"
        let separator: Character = ":"
        #endif
        let environment = ProcessInfo.processInfo.environment
        let candidates = (environment["PATH"] ?? "").split(separator: separator)
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent(executable) }
        guard let swiftExecutable = candidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }) else {
            throw URLError(.fileDoesNotExist)
        }
        process.executableURL = swiftExecutable
        process.currentDirectoryURL = root
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("ttfx-graph-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: scratch) }
        process.arguments = ["package", "--scratch-path", scratch.path, "describe", "--type", "json"]
        var modifiedEnvironment = environment
        modifiedEnvironment["TTFX_CLI_ONLY"] = cliOnly ? "1" : "0"
        process.environment = modifiedEnvironment
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.standardError
        try process.run()
        let bytes = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        return try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    }

    @Test func cliOnlyGraphExcludesGraphicalProductsAndTests() throws {
        let description = try graph(cliOnly: true)
        let targets = try #require(description["targets"] as? [[String: Any]])
        let names = Set(targets.compactMap { $0["name"] as? String })
        #expect(names == ["TTFXCore", "TTFXEffects", "TTFXCLI", "TTFXCoreTests", "TTFXEffectsTests", "TTFXCLITests"])
        let products = try #require(description["products"] as? [[String: Any]])
        #expect(Set(products.compactMap { $0["name"] as? String }) == ["ttfx", "ttfx-swift"])
        let cli = try #require(targets.first { $0["name"] as? String == "TTFXCLI" })
        #expect(Set(cli["target_dependencies"] as? [String] ?? []) == ["TTFXCore", "TTFXEffects"])
        #expect(cli["product_dependencies"] as? [String] == ["ArgumentParser"])
    }

    @Test func normalGraphPreservesGraphicalProductsAndTests() throws {
        let description = try graph(cliOnly: false)
        let products = try #require(description["products"] as? [[String: Any]])
        #expect(Set(products.compactMap { $0["name"] as? String }) == [
            "ttfx", "ttfx-swift", "TTFXSwiftUI", "TTFXGalleryApp", "TTFXVideoCapture", "TTFXComparisonApp"
        ])
        let targets = try #require(description["targets"] as? [[String: Any]])
        let names = Set(targets.compactMap { $0["name"] as? String })
        #expect(names.isSuperset(of: ["TTFXComparisonTests", "TTFXSwiftUITests", "TTFXGalleryAppTests"]))
    }
}
