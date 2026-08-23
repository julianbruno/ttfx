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
}
