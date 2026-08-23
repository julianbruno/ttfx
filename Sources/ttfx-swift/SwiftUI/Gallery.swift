import TTFXCore
import TTFXEffects

public struct TTFXGalleryDemo: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let title: String
    public let sampleText: String
    public let seed: UInt64
    public let canvas: TTFXGalleryCanvas

    public init(name: String, title: String, sampleText: String = "Swift\nTTFX", seed: UInt64 = 42, canvas: TTFXGalleryCanvas = .standard) {
        self.id = name
        self.name = name
        self.title = title
        self.sampleText = sampleText
        self.seed = seed
        self.canvas = canvas
    }

    public var configuration: EffectConfiguration {
        EffectConfiguration(text: sampleText, seed: seed)
    }
}

public struct TTFXGalleryCanvas: Equatable, Sendable {
    public let columns: Int
    public let rows: Int

    public static let standard = TTFXGalleryCanvas(columns: 24, rows: 8)

    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }

    public func makeCanvas() throws -> Canvas {
        try Canvas(columns: columns, rows: rows)
    }
}

public enum TTFXGallery {
    public static let demos: [TTFXGalleryDemo] = [
        "beams",
        "binarypath",
        "blackhole",
        "bouncyballs",
        "bubbles",
        "burn",
        "colorshift",
        "crumble",
        "decrypt",
        "errorcorrect",
        "expand",
        "fireworks",
        "highlight",
        "laseretch",
        "matrix",
        "middleout",
        "orbittingvolley",
        "overflow",
        "pour",
        "rain",
        "randomsequence",
        "rings",
        "scattered",
        "slice",
        "slide",
        "smoke",
        "spotlights",
        "spray",
        "swarm",
        "sweep",
        "synthgrid",
        "thunderstorm",
        "unstable",
        "vhstape",
        "waves",
        "wipe",
        "print"
    ].map { name in
        TTFXGalleryDemo(name: name, title: title(for: name))
    }

    private static func title(for name: String) -> String {
        switch name {
        case "vhstape": "VHS Tape"
        case "matrix2": "Matrix 2"
        default:
            name.split(separator: "-")
                .map { part in part.prefix(1).uppercased() + part.dropFirst() }
                .joined(separator: " ")
        }
    }
}
