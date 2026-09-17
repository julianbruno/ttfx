import TTFXCore

public struct EffectFlagSpec: Sendable, Equatable {
    public let name: String
    public let kind: EffectFlagKind
    public let defaultDescription: String
    public let help: String

    public init(name: String, kind: EffectFlagKind, defaultDescription: String, help: String = "") {
        self.name = name
        self.kind = kind
        self.defaultDescription = defaultDescription
        self.help = help
    }
}

public enum EffectFlagKind: Sendable, Equatable {
    case bool
    case int
    case float
    case string
    case strings
    case ints
    case color
    case colors
    case easing
    case gradientDirection
    case intRange
    case floatRange
    case choice([String])
}

public enum EffectFlagCatalog {
    public static let effectNames: [String] = [
        "beams", "binarypath", "blackhole", "bouncyballs", "bubbles", "burn", "colorshift", "crumble", "decrypt", "errorcorrect", "expand", "fireworks", "highlight", "laseretch", "matrix", "middleout", "orbittingvolley", "overflow", "pour", "print", "rain", "randomsequence", "rings", "scattered", "slice", "slide", "smoke", "spotlights", "spray", "swarm", "sweep", "synthgrid", "thunderstorm", "unstable", "vhstape", "waves", "wipe"
    ]

    public static func specs(for effect: String) -> [EffectFlagSpec] {
        switch effect {
        case "beams": [
            .init(name: "beam-row-symbols", kind: .strings, defaultDescription: "▂ ▁ _"),
            .init(name: "beam-column-symbols", kind: .strings, defaultDescription: "▌ ▍ ▎ ▏"),
            .init(name: "beam-delay", kind: .int, defaultDescription: "6"),
            .init(name: "beam-row-speed-range", kind: .intRange, defaultDescription: "15-60"),
            .init(name: "beam-column-speed-range", kind: .intRange, defaultDescription: "9-15"),
            .init(name: "beam-gradient-stops", kind: .colors, defaultDescription: "ffffff 00D1FF 8A008A"),
            .init(name: "beam-gradient-steps", kind: .ints, defaultDescription: "2 6"),
            .init(name: "beam-gradient-frames", kind: .int, defaultDescription: "2"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF ffffff"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-frames", kind: .int, defaultDescription: "4"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
            .init(name: "final-wipe-speed", kind: .int, defaultDescription: "3"),
        ]
        case "binarypath": [
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "00d500 007500"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "radial"),
            .init(name: "binary-colors", kind: .colors, defaultDescription: "044E29 157e38 45bf55 95ed87"),
            .init(name: "movement-speed", kind: .float, defaultDescription: "1.0"),
            .init(name: "active-binary-groups", kind: .float, defaultDescription: "0.08"),
        ]
        case "blackhole": [
            .init(name: "blackhole-color", kind: .color, defaultDescription: "ffffff"),
            .init(name: "star-colors", kind: .colors, defaultDescription: "ffcc0d ff7326 ff194d bf2669 702a8c 049dbf"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF ffffff"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "9"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "diagonal"),
        ]
        case "bouncyballs": [
            .init(name: "ball-colors", kind: .colors, defaultDescription: "d1f4a5 96e2a4 5acda9"),
            .init(name: "ball-symbols", kind: .strings, defaultDescription: "* o O 0 ."),
            .init(name: "ball-delay", kind: .int, defaultDescription: "4"),
            .init(name: "movement-speed", kind: .float, defaultDescription: "0.45"),
            .init(name: "movement-easing", kind: .easing, defaultDescription: "out_bounce"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "f8ffae 43c6ac"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "diagonal"),
        ]
        case "bubbles": [
            .init(name: "rainbow", kind: .bool, defaultDescription: "false"),
            .init(name: "bubble-colors", kind: .colors, defaultDescription: "d33aff 7395c4 43c2a7 02ff7f"),
            .init(name: "pop-color", kind: .color, defaultDescription: "ffffff"),
            .init(name: "bubble-speed", kind: .float, defaultDescription: "0.5"),
            .init(name: "bubble-delay", kind: .int, defaultDescription: "20"),
            .init(name: "pop-condition", kind: .choice(["row", "bottom", "anywhere"]), defaultDescription: "row"),
            .init(name: "movement-easing", kind: .easing, defaultDescription: "in_out_sine"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "d33aff 02ff7f"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "diagonal"),
        ]
        case "burn": [
            .init(name: "starting-color", kind: .color, defaultDescription: "837373"),
            .init(name: "burn-colors", kind: .colors, defaultDescription: "ffffff fff75d fe650d 8A003C 510100"),
            .init(name: "smoke-chance", kind: .float, defaultDescription: "0.5"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "00c3ff ffff1c"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "colorshift": [
            .init(name: "gradient-stops", kind: .colors, defaultDescription: "e81416 ffa500 faeb36 79c314 487de7 4b369d 70369d"),
            .init(name: "gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "gradient-frames", kind: .int, defaultDescription: "2"),
            .init(name: "no-travel", kind: .bool, defaultDescription: "false"),
            .init(name: "travel-direction", kind: .gradientDirection, defaultDescription: "radial"),
            .init(name: "reverse-travel-direction", kind: .bool, defaultDescription: "false"),
            .init(name: "no-loop", kind: .bool, defaultDescription: "false"),
            .init(name: "cycles", kind: .int, defaultDescription: "3"),
            .init(name: "skip-final-gradient", kind: .bool, defaultDescription: "false"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "e81416 ffa500 faeb36 79c314 487de7 4b369d 70369d"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "crumble": [
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "5CE1FF FF8C00"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "diagonal"),
        ]
        case "decrypt": [
            .init(name: "typing-speed", kind: .int, defaultDescription: "2"),
            .init(name: "ciphertext-colors", kind: .colors, defaultDescription: "008000 00cb00 00ff00"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "eda000"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "errorcorrect": [
            .init(name: "error-pairs", kind: .float, defaultDescription: "0.1"),
            .init(name: "swap-delay", kind: .int, defaultDescription: "6"),
            .init(name: "error-color", kind: .color, defaultDescription: "e74c3c"),
            .init(name: "correct-color", kind: .color, defaultDescription: "45bf55"),
            .init(name: "movement-speed", kind: .float, defaultDescription: "0.9"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF FFFFFF"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "expand": [
            .init(name: "expand-easing", kind: .easing, defaultDescription: "in_out_quart"),
            .init(name: "movement-speed", kind: .float, defaultDescription: "0.35"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF FFFFFF"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "fireworks": [
            .init(name: "explode-anywhere", kind: .bool, defaultDescription: "false"),
            .init(name: "firework-colors", kind: .colors, defaultDescription: "88F7E2 44D492 F5EB67 FFA15C FA233E"),
            .init(name: "firework-symbol", kind: .string, defaultDescription: "o"),
            .init(name: "firework-volume", kind: .float, defaultDescription: "0.05"),
            .init(name: "launch-delay", kind: .int, defaultDescription: "45"),
            .init(name: "explode-distance", kind: .float, defaultDescription: "0.2"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF FFFFFF"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "horizontal"),
        ]
        case "highlight": [
            .init(name: "highlight-brightness", kind: .float, defaultDescription: "1.75"),
            .init(name: "highlight-direction", kind: .choice(["column_left_to_right", "column_right_to_left", "row_top_to_bottom", "row_bottom_to_top", "diagonal_top_left_to_bottom_right", "diagonal_bottom_left_to_top_right", "diagonal_top_right_to_bottom_left", "diagonal_bottom_right_to_top_left", "center_to_outside", "outside_to_center"]), defaultDescription: "diagonal_bottom_left_to_top_right"),
            .init(name: "highlight-width", kind: .int, defaultDescription: "8"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF FFFFFF"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "laseretch": [
            .init(name: "etch-pattern", kind: .choice(["algorithm", "column_left_to_right", "column_right_to_left", "row_top_to_bottom", "row_bottom_to_top", "diagonal_top_left_to_bottom_right", "diagonal_bottom_left_to_top_right", "diagonal_top_right_to_bottom_left", "diagonal_bottom_right_to_top_left", "center_to_outside", "outside_to_center"]), defaultDescription: "algorithm"),
            .init(name: "etch-speed", kind: .int, defaultDescription: "1"),
            .init(name: "etch-delay", kind: .int, defaultDescription: "1"),
            .init(name: "cool-gradient-stops", kind: .colors, defaultDescription: "ffe680 ff7b00"),
            .init(name: "laser-gradient-stops", kind: .colors, defaultDescription: "ffffff 376cff"),
            .init(name: "spark-gradient-stops", kind: .colors, defaultDescription: "ffffff ffe680 ff7b00 1a0900"),
            .init(name: "spark-cooling-frames", kind: .int, defaultDescription: "7"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF ffffff"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "8"),
            .init(name: "final-gradient-frames", kind: .int, defaultDescription: "4"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "matrix": [
            .init(name: "highlight-color", kind: .color, defaultDescription: "dbffdb"),
            .init(name: "rain-color-gradient", kind: .colors, defaultDescription: "92be92 185318"),
            .init(name: "rain-symbols", kind: .strings, defaultDescription: "2 5 9 8 Z * ) : . \\ ,  ,  ,  ,  ,  ,  ,\n               ,  ,  ,  ,  ,  ,  ,  ,  ,  ,  ,  ,  ,  ,  ,  ,\n               ,  ,  ,  ,  ,  ,  ,  ,  ,  ,  ,  ,  ,  ,  ,  ,\n               , "),
            .init(name: "rain-fall-delay-range", kind: .intRange, defaultDescription: "2-15"),
            .init(name: "rain-column-delay-range", kind: .intRange, defaultDescription: "3-9"),
            .init(name: "rain-time", kind: .int, defaultDescription: "15"),
            .init(name: "symbol-swap-chance", kind: .float, defaultDescription: "0.005"),
            .init(name: "color-swap-chance", kind: .float, defaultDescription: "0.001"),
            .init(name: "resolve-delay", kind: .int, defaultDescription: "3"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "92be92 336b33"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-frames", kind: .int, defaultDescription: "3"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "radial"),
        ]
        case "middleout": [
            .init(name: "starting-color", kind: .color, defaultDescription: "ffffff"),
            .init(name: "expand-direction", kind: .choice(["vertical", "horizontal"]), defaultDescription: "vertical"),
            .init(name: "center-movement-speed", kind: .float, defaultDescription: "0.6"),
            .init(name: "full-movement-speed", kind: .float, defaultDescription: "0.6"),
            .init(name: "center-easing", kind: .easing, defaultDescription: "in_out_sine"),
            .init(name: "full-easing", kind: .easing, defaultDescription: "in_out_sine"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF FFFFFF"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "orbittingvolley": [
            .init(name: "top-launcher-symbol", kind: .string, defaultDescription: "█"),
            .init(name: "right-launcher-symbol", kind: .string, defaultDescription: "█"),
            .init(name: "bottom-launcher-symbol", kind: .string, defaultDescription: "█"),
            .init(name: "left-launcher-symbol", kind: .string, defaultDescription: "█"),
            .init(name: "launcher-movement-speed", kind: .float, defaultDescription: "0.8"),
            .init(name: "character-movement-speed", kind: .float, defaultDescription: "1.5"),
            .init(name: "volley-size", kind: .float, defaultDescription: "0.03"),
            .init(name: "launch-delay", kind: .int, defaultDescription: "30"),
            .init(name: "character-easing", kind: .easing, defaultDescription: "out_sine"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "FFA15C 44D492"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "radial"),
        ]
        case "overflow": [
            .init(name: "overflow-gradient-stops", kind: .colors, defaultDescription: "f2ebc0 8dbfb3 f2ebc0"),
            .init(name: "overflow-cycles-range", kind: .intRange, defaultDescription: "2-4"),
            .init(name: "overflow-speed", kind: .int, defaultDescription: "3"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF FFFFFF"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "pour": [
            .init(name: "pour-direction", kind: .choice(["up", "down", "left", "right"]), defaultDescription: "down"),
            .init(name: "pour-speed", kind: .int, defaultDescription: "2"),
            .init(name: "movement-speed-range", kind: .floatRange, defaultDescription: "0.4-0.6"),
            .init(name: "gap", kind: .int, defaultDescription: "1"),
            .init(name: "starting-color", kind: .color, defaultDescription: "ffffff"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF FFFFFF"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-frames", kind: .int, defaultDescription: "6"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
            .init(name: "movement-easing", kind: .easing, defaultDescription: "in_quad"),
        ]
        case "print": [
            .init(name: "print-head-return-speed", kind: .float, defaultDescription: "1.5"),
            .init(name: "print-speed", kind: .int, defaultDescription: "2"),
            .init(name: "print-head-easing", kind: .easing, defaultDescription: "in_out_quad"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "02b8bd c1f0e3 00ffa0"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "diagonal"),
        ]
        case "rain": [
            .init(name: "rain-colors", kind: .colors, defaultDescription: "00315C 004C8F 0075DB 3F91D9 78B9F2 9AC8F5 B8D8F8 E3EFFC"),
            .init(name: "movement-speed", kind: .floatRange, defaultDescription: "0.33-0.57"),
            .init(name: "rain-symbols", kind: .strings, defaultDescription: "o . , * |"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "488bff b2e7de 57eaf7"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "diagonal"),
            .init(name: "movement-easing", kind: .easing, defaultDescription: "in_quart"),
        ]
        case "randomsequence": [
            .init(name: "speed", kind: .float, defaultDescription: "0.007"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF FFFFFF"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-frames", kind: .int, defaultDescription: "8"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "rings": [
            .init(name: "ring-colors", kind: .colors, defaultDescription: "ab48ff e7b2b2 fffebd"),
            .init(name: "ring-gap", kind: .float, defaultDescription: "0.1"),
            .init(name: "spin-duration", kind: .int, defaultDescription: "200"),
            .init(name: "spin-speed", kind: .floatRange, defaultDescription: "0.25-1.0"),
            .init(name: "disperse-duration", kind: .int, defaultDescription: "200"),
            .init(name: "spin-disperse-cycles", kind: .int, defaultDescription: "3"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "ab48ff e7b2b2 fffebd"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "scattered": [
            .init(name: "movement-speed", kind: .float, defaultDescription: "0.5"),
            .init(name: "movement-easing", kind: .easing, defaultDescription: "in_out_back"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "ff9048 ab9dff bdffea"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-frames", kind: .int, defaultDescription: "9"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "slice": [
            .init(name: "slice-direction", kind: .string, defaultDescription: "vertical"),
            .init(name: "movement-speed", kind: .float, defaultDescription: "0.25"),
            .init(name: "movement-easing", kind: .easing, defaultDescription: "in_out_expo"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF FFFFFF"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "diagonal"),
        ]
        case "slide": [
            .init(name: "movement-speed", kind: .float, defaultDescription: "0.8"),
            .init(name: "grouping", kind: .choice(["row", "column", "diagonal"]), defaultDescription: "row"),
            .init(name: "gap", kind: .int, defaultDescription: "2"),
            .init(name: "reverse-direction", kind: .bool, defaultDescription: "false"),
            .init(name: "merge", kind: .bool, defaultDescription: "false"),
            .init(name: "movement-easing", kind: .easing, defaultDescription: "in_out_quad"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "833ab4 fd1d1d fcb045"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-frames", kind: .int, defaultDescription: "6"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "smoke": [
            .init(name: "starting-color", kind: .color, defaultDescription: "7A7A7A"),
            .init(name: "smoke-symbols", kind: .strings, defaultDescription: "░ ▒ ▓ ▒ ░"),
            .init(name: "smoke-gradient-stops", kind: .colors, defaultDescription: "242424 FFFFFF"),
            .init(name: "use-whole-canvas", kind: .bool, defaultDescription: "false"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF FFFFFF"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "spotlights": [
            .init(name: "beam-width-ratio", kind: .float, defaultDescription: "2.0"),
            .init(name: "beam-falloff", kind: .float, defaultDescription: "0.3"),
            .init(name: "search-duration", kind: .int, defaultDescription: "550"),
            .init(name: "search-speed-range", kind: .floatRange, defaultDescription: "0.35-0.75"),
            .init(name: "spotlight-count", kind: .int, defaultDescription: "3"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "ab48ff e7b2b2 fffebd"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "spray": [
            .init(name: "spray-position", kind: .choice(["n", "ne", "e", "se", "s", "sw", "w", "nw", "center"]), defaultDescription: "e"),
            .init(name: "spray-volume", kind: .float, defaultDescription: "0.005"),
            .init(name: "movement-speed-range", kind: .floatRange, defaultDescription: "0.6-1.4"),
            .init(name: "movement-easing", kind: .easing, defaultDescription: "out_expo"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF FFFFFF"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "swarm": [
            .init(name: "base-color", kind: .colors, defaultDescription: "31a0d4"),
            .init(name: "flash-color", kind: .color, defaultDescription: "f2ea79"),
            .init(name: "swarm-size", kind: .float, defaultDescription: "0.1"),
            .init(name: "swarm-coordination", kind: .float, defaultDescription: "0.80"),
            .init(name: "swarm-area-count-range", kind: .intRange, defaultDescription: "2-4"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "31b900 f0ff65"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "horizontal"),
        ]
        case "sweep": [
            .init(name: "sweep-symbols", kind: .strings, defaultDescription: "█ ▓ ▒ ░"),
            .init(name: "first-sweep-direction", kind: .choice(["column_left_to_right", "column_right_to_left", "row_top_to_bottom", "row_bottom_to_top", "diagonal_top_left_to_bottom_right", "diagonal_bottom_left_to_top_right", "diagonal_top_right_to_bottom_left", "diagonal_bottom_right_to_top_left", "center_to_outside", "outside_to_center"]), defaultDescription: "column_right_to_left"),
            .init(name: "second-sweep-direction", kind: .choice(["column_left_to_right", "column_right_to_left", "row_top_to_bottom", "row_bottom_to_top", "diagonal_top_left_to_bottom_right", "diagonal_bottom_left_to_top_right", "diagonal_top_right_to_bottom_left", "diagonal_bottom_right_to_top_left", "center_to_outside", "outside_to_center"]), defaultDescription: "column_left_to_right"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF ffffff"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "8"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "synthgrid": [
            .init(name: "grid-gradient-stops", kind: .colors, defaultDescription: "CC00CC ffffff"),
            .init(name: "grid-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "grid-gradient-direction", kind: .gradientDirection, defaultDescription: "diagonal"),
            .init(name: "text-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF FFFFFF"),
            .init(name: "text-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "text-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
            .init(name: "grid-row-symbol", kind: .string, defaultDescription: "─"),
            .init(name: "grid-column-symbol", kind: .string, defaultDescription: "│"),
            .init(name: "text-generation-symbols", kind: .strings, defaultDescription: "░ ▒ ▓"),
            .init(name: "max-active-blocks", kind: .float, defaultDescription: "0.1"),
        ]
        case "thunderstorm": [
            .init(name: "lightning-color", kind: .color, defaultDescription: "68A3E8"),
            .init(name: "glowing-text-color", kind: .color, defaultDescription: "EF5411"),
            .init(name: "text-glow-time", kind: .int, defaultDescription: "6"),
            .init(name: "raindrop-symbols", kind: .strings, defaultDescription: "\\\\ . ,"),
            .init(name: "spark-symbols", kind: .strings, defaultDescription: "* . '"),
            .init(name: "spark-glow-color", kind: .color, defaultDescription: "ff4d00"),
            .init(name: "spark-glow-time", kind: .int, defaultDescription: "18"),
            .init(name: "storm-time", kind: .int, defaultDescription: "12"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF FFFFFF"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-frames", kind: .int, defaultDescription: "3"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "unstable": [
            .init(name: "unstable-color", kind: .color, defaultDescription: "ff9200"),
            .init(name: "explosion-ease", kind: .easing, defaultDescription: "out_expo"),
            .init(name: "explosion-speed", kind: .float, defaultDescription: "1.0"),
            .init(name: "reassembly-ease", kind: .easing, defaultDescription: "out_expo"),
            .init(name: "reassembly-speed", kind: .float, defaultDescription: "1.0"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "8A008A 00D1FF FFFFFF"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "vhstape": [
            .init(name: "glitch-line-colors", kind: .colors, defaultDescription: "ffffff ff0000 00ff00 0000ff ffffff"),
            .init(name: "glitch-wave-colors", kind: .colors, defaultDescription: "ffffff ff0000 00ff00 0000ff ffffff"),
            .init(name: "noise-colors", kind: .colors, defaultDescription: "1e1e1f 3c3b3d 6d6c70 a2a1a6 cbc9cf ffffff"),
            .init(name: "glitch-line-chance", kind: .float, defaultDescription: "0.05"),
            .init(name: "noise-chance", kind: .float, defaultDescription: "0.004"),
            .init(name: "total-glitch-time", kind: .int, defaultDescription: "600"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "ab48ff e7b2b2 fffebd"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        case "waves": [
            .init(name: "wave-symbols", kind: .strings, defaultDescription: "▁ ▂ ▃ ▄ ▅ ▆ ▇ █ ▇ ▆ ▅ ▄ ▃ ▂ ▁"),
            .init(name: "wave-gradient-stops", kind: .colors, defaultDescription: "f0ff65 ffb102 31a0d4 ffb102 f0ff65"),
            .init(name: "wave-gradient-steps", kind: .ints, defaultDescription: "6"),
            .init(name: "wave-count", kind: .int, defaultDescription: "7"),
            .init(name: "wave-length", kind: .int, defaultDescription: "2"),
            .init(name: "wave-direction", kind: .choice(["column_left_to_right", "column_right_to_left", "row_top_to_bottom", "row_bottom_to_top", "diagonal_top_left_to_bottom_right", "diagonal_bottom_left_to_top_right", "diagonal_top_right_to_bottom_left", "diagonal_bottom_right_to_top_left", "center_to_outside", "outside_to_center"]), defaultDescription: "column_left_to_right"),
            .init(name: "wave-easing", kind: .easing, defaultDescription: "in_out_sine"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "ffb102 31a0d4 f0ff65"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "diagonal"),
        ]
        case "wipe": [
            .init(name: "wipe-direction", kind: .choice(["column_left_to_right", "column_right_to_left", "row_top_to_bottom", "row_bottom_to_top", "diagonal_top_left_to_bottom_right", "diagonal_bottom_left_to_top_right", "diagonal_top_right_to_bottom_left", "diagonal_bottom_right_to_top_left", "center_to_outside", "outside_to_center"]), defaultDescription: "diagonal_top_left_to_bottom_right"),
            .init(name: "wipe-delay", kind: .int, defaultDescription: "0"),
            .init(name: "wipe-ease", kind: .easing, defaultDescription: "in_out_circ"),
            .init(name: "final-gradient-stops", kind: .colors, defaultDescription: "833ab4 fd1d1d fcb045"),
            .init(name: "final-gradient-steps", kind: .ints, defaultDescription: "12"),
            .init(name: "final-gradient-frames", kind: .int, defaultDescription: "3"),
            .init(name: "final-gradient-direction", kind: .gradientDirection, defaultDescription: "vertical"),
        ]
        default: []
        }
    }

    public static func help(for effect: String) -> String {
        let specs = specs(for: effect)
        guard !specs.isEmpty else { return "Unknown effect '\(effect)'." }
        var lines = ["OVERVIEW: \(effect) effect options", "", "OPTIONS:"]
        for spec in specs {
            lines.append("  --\(spec.name)  (default: \(spec.defaultDescription))")
        }
        return lines.joined(separator: "\n")
    }
}

