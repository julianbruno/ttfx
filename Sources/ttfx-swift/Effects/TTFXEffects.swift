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
        seed: UInt64,
        settings: ParsedEffectSettings = .empty
    ) -> (any Effect)? {
        switch name {
        case "beams":
            var options = BeamsEffect.Configuration()
            options.apply(settings)
            return BeamsEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, beamsConfiguration: options)
        case "binarypath":
            var options = BinaryPathEffect.Configuration()
            options.apply(settings)
            return BinaryPathEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, binaryPathConfiguration: options)
        case "blackhole":
            var options = BlackholeEffect.Configuration()
            options.apply(settings)
            return BlackholeEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, blackholeConfiguration: options)
        case "bouncyballs":
            var options = BouncyBallsEffect.Configuration()
            options.apply(settings)
            return BouncyBallsEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, bouncyBallsConfiguration: options)
        case "bubbles":
            var options = BubblesEffect.Configuration()
            options.apply(settings)
            return BubblesEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, bubblesConfiguration: options)
        case "burn":
            var options = BurnEffect.Configuration()
            options.apply(settings)
            return BurnEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, burnConfiguration: options)
        case "colorshift":
            var options = ColorShiftEffect.Configuration()
            options.apply(settings)
            return ColorShiftEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, colorShiftConfiguration: options)
        case "crumble":
            var options = CrumbleEffect.Configuration()
            options.apply(settings)
            return CrumbleEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, crumbleConfiguration: options)
        case "decrypt":
            var options = DecryptEffect.Configuration()
            options.apply(settings)
            return DecryptEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, decryptConfiguration: options)
        case "errorcorrect":
            var options = ErrorCorrectEffect.Configuration()
            options.apply(settings)
            return ErrorCorrectEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, errorCorrectConfiguration: options)
        case "expand":
            var options = ExpandEffect.Configuration()
            options.apply(settings)
            return ExpandEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, expandConfiguration: options)
        case "fireworks":
            var options = FireworksEffect.Configuration()
            options.apply(settings)
            return FireworksEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, fireworksConfiguration: options)
        case "highlight":
            var options = HighlightEffect.Configuration()
            options.apply(settings)
            return HighlightEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, highlightConfiguration: options)
        case "laseretch":
            var options = LaserEtchEffect.Configuration()
            options.apply(settings)
            return LaserEtchEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, laserEtchConfiguration: options)
        case "matrix":
            var options = MatrixEffect.Configuration()
            options.apply(settings)
            return MatrixEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, matrixConfiguration: options)
        case "middleout":
            var options = MiddleoutEffect.Configuration()
            options.apply(settings)
            return MiddleoutEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, middleoutConfiguration: options)
        case "orbittingvolley":
            var options = OrbittingVolleyEffect.Configuration()
            options.apply(settings)
            return OrbittingVolleyEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, orbittingVolleyConfiguration: options)
        case "overflow":
            var options = OverflowEffect.Configuration()
            options.apply(settings)
            return OverflowEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, overflowConfiguration: options)
        case "pour":
            var options = PourEffect.Configuration()
            options.apply(settings)
            return PourEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, pourConfiguration: options)
        case "print":
            var options = PrintEffect.Configuration()
            options.apply(settings)
            return PrintEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, printConfiguration: options)
        case "rain":
            var options = RainEffect.Configuration()
            options.apply(settings)
            return RainEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, rainConfiguration: options)
        case "randomsequence":
            var options = RandomSequenceEffect.Configuration()
            options.apply(settings)
            return RandomSequenceEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, randomSequenceConfiguration: options)
        case "rings":
            var options = RingsEffect.Configuration()
            options.apply(settings)
            return RingsEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, ringsConfiguration: options)
        case "scattered":
            var options = ScatteredEffect.Configuration()
            options.apply(settings)
            return ScatteredEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, scatteredConfiguration: options)
        case "slice":
            var options = SliceEffect.Configuration()
            options.apply(settings)
            return SliceEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, sliceConfiguration: options)
        case "slide":
            var options = SlideEffect.Configuration()
            options.apply(settings)
            return SlideEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, slideConfiguration: options)
        case "smoke":
            var options = SmokeEffect.Configuration()
            options.apply(settings)
            return SmokeEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, smokeConfiguration: options)
        case "spotlights":
            var options = SpotlightsEffect.Configuration()
            options.apply(settings)
            return SpotlightsEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, spotlightsConfiguration: options)
        case "spray":
            var options = SprayEffect.Configuration()
            options.apply(settings)
            return SprayEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, sprayConfiguration: options)
        case "swarm":
            var options = SwarmEffect.Configuration()
            options.apply(settings)
            return SwarmEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, swarmConfiguration: options)
        case "sweep":
            var options = SweepEffect.Configuration()
            options.apply(settings)
            return SweepEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, sweepConfiguration: options)
        case "synthgrid":
            var options = SynthGridEffect.Configuration()
            options.apply(settings)
            return SynthGridEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, synthGridConfiguration: options)
        case "thunderstorm":
            var options = ThunderstormEffect.Configuration()
            options.apply(settings)
            return ThunderstormEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, thunderstormConfiguration: options)
        case "unstable":
            var options = UnstableEffect.Configuration()
            options.apply(settings)
            return UnstableEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, unstableConfiguration: options)
        case "vhstape":
            var options = VHSTapeEffect.Configuration()
            options.apply(settings)
            return VHSTapeEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, vhsTapeConfiguration: options)
        case "waves":
            var options = WavesEffect.Configuration()
            options.apply(settings)
            return WavesEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, wavesConfiguration: options)
        case "wipe":
            var options = WipeEffect.Configuration()
            options.apply(settings)
            return WipeEffect(configuration: configuration, canvas: canvas, input: input, seed: seed, wipeConfiguration: options)
        default:
            return nil
        }
    }
}
