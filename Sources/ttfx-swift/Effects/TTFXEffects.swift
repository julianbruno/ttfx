import TTFXCore

public enum EffectRegistry {
    public static let names: [String] = [
        "beams", "binarypath", "blackhole", "bouncyballs", "bubbles", "burn",
        "colorshift", "crumble", "decrypt", "errorcorrect", "expand", "fireworks",
        "highlight", "laseretch", "matrix", "middleout", "orbittingvolley",
        "overflow", "pour", "print", "rain", "randomsequence", "rings", "scattered",
        "slice", "slide", "smoke", "spotlights", "spray", "swarm", "sweep",
        "synthgrid", "thunderstorm", "unstable", "vhstape", "waves", "wipe"
    ]

    public static func contains(_ name: String) -> Bool {
        names.contains(name)
    }

    public static func makeEffect(
        named name: String,
        configuration: EffectConfiguration,
        canvas: Canvas,
        input: InputText,
        seed: UInt64
    ) -> (any Effect)? {
        switch name {
        case "beams": BeamsEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "binarypath": BinaryPathEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "blackhole": BlackholeEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "bouncyballs": BouncyBallsEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "bubbles": BubblesEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "burn": BurnEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "colorshift": ColorShiftEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "crumble": CrumbleEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "decrypt": DecryptEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "errorcorrect": ErrorCorrectEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "expand": ExpandEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "fireworks": FireworksEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "highlight": HighlightEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "laseretch": LaserEtchEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "matrix": MatrixEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "middleout": MiddleoutEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "orbittingvolley": OrbittingVolleyEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "overflow": OverflowEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "pour": PourEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "print": PrintEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "rain": RainEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "randomsequence": RandomSequenceEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "rings": RingsEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "scattered": ScatteredEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "slice": SliceEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "slide": SlideEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "smoke": SmokeEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "spotlights": SpotlightsEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "spray": SprayEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "swarm": SwarmEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "sweep": SweepEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "synthgrid": SynthGridEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "thunderstorm": ThunderstormEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "unstable": UnstableEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "vhstape": VHSTapeEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "waves": WavesEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        case "wipe": WipeEffect(configuration: configuration, canvas: canvas, input: input, seed: seed)
        default: nil
        }
    }
}
