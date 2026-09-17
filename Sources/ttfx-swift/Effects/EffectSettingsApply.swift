import TTFXCore

extension WipeEffect.Direction {
    public init?(tteName: String) {
        switch tteName {
        case "diagonal_top_left_to_bottom_right": self = .diagonalTopLeftToBottomRight
        case "diagonal_bottom_right_to_top_left": self = .diagonalBottomRightToTopLeft
        case "diagonal_bottom_left_to_top_right": self = .diagonalBottomLeftToTopRight
        case "diagonal_top_right_to_bottom_left": self = .diagonalTopRightToBottomLeft
        case "row_bottom_to_top": self = .rowBottomToTop
        case "row_top_to_bottom": self = .rowTopToBottom
        case "column_left_to_right": self = .columnLeftToRight
        case "column_right_to_left": self = .columnRightToLeft
        case "center_to_outside": self = .centerToOutside
        case "outside_to_center": self = .outsideToCenter
        default: return nil
        }
    }
}

extension HighlightEffect.Direction {
    public init?(tteName: String) {
        self.init(raw: WipeEffect.Direction(tteName: tteName))
    }

    private init?(raw: WipeEffect.Direction?) {
        guard let raw else { return nil }
        switch raw {
        case .diagonalTopLeftToBottomRight: self = .diagonalTopLeftToBottomRight
        case .diagonalBottomRightToTopLeft: self = .diagonalBottomRightToTopLeft
        case .diagonalBottomLeftToTopRight: self = .diagonalBottomLeftToTopRight
        case .diagonalTopRightToBottomLeft: self = .diagonalTopRightToBottomLeft
        case .rowBottomToTop: self = .rowBottomToTop
        case .rowTopToBottom: self = .rowTopToBottom
        case .columnLeftToRight: self = .columnLeftToRight
        case .columnRightToLeft: self = .columnRightToLeft
        case .centerToOutside: self = .centerToOutside
        case .outsideToCenter: self = .outsideToCenter
        }
    }
}

extension SweepEffect.Direction {
    public init?(tteName: String) {
        guard let raw = WipeEffect.Direction(tteName: tteName) else { return nil }
        switch raw {
        case .diagonalTopLeftToBottomRight: self = .diagonalTopLeftToBottomRight
        case .diagonalBottomRightToTopLeft: self = .diagonalBottomRightToTopLeft
        case .diagonalBottomLeftToTopRight: self = .diagonalBottomLeftToTopRight
        case .diagonalTopRightToBottomLeft: self = .diagonalTopRightToBottomLeft
        case .rowBottomToTop: self = .rowBottomToTop
        case .rowTopToBottom: self = .rowTopToBottom
        case .columnLeftToRight: self = .columnLeftToRight
        case .columnRightToLeft: self = .columnRightToLeft
        case .centerToOutside: self = .centerToOutside
        case .outsideToCenter: self = .outsideToCenter
        }
    }
}

extension WavesEffect.Direction {
    public init?(tteName: String) {
        switch tteName {
        case "column_left_to_right": self = .columnLeftToRight
        case "column_right_to_left": self = .columnRightToLeft
        case "row_top_to_bottom": self = .rowTopToBottom
        case "row_bottom_to_top": self = .rowBottomToTop
        case "center_to_outside": self = .centerToOutside
        case "outside_to_center": self = .outsideToCenter
        default: return nil
        }
    }
}

extension SliceEffect.Direction {
    public init?(tteName: String) {
        switch tteName {
        case "vertical": self = .vertical
        case "horizontal": self = .horizontal
        case "diagonal": self = .diagonal
        default: return nil
        }
    }
}

extension SprayEffect.Position {
    public init?(tteName: String) {
        switch tteName {
        case "n": self = .n
        case "ne": self = .ne
        case "e": self = .e
        case "se": self = .se
        case "s": self = .s
        case "sw": self = .sw
        case "w": self = .w
        case "nw": self = .nw
        case "center", "c": self = .center
        default: return nil
        }
    }
}

extension BubblesEffect.PopCondition {
    public init?(tteName: String) {
        switch tteName {
        case "row": self = .row
        case "bottom": self = .bottom
        case "anywhere": self = .anywhere
        default: return nil
        }
    }
}

extension PourEffect.PourDirection {
    public init?(tteName: String) {
        switch tteName {
        case "up": self = .up
        case "down": self = .down
        case "left": self = .left
        case "right": self = .right
        default: return nil
        }
    }
}

extension MiddleoutEffect.ExpandDirection {
    public init?(tteName: String) {
        switch tteName {
        case "vertical": self = .vertical
        case "horizontal": self = .horizontal
        default: return nil
        }
    }
}

extension SlideEffect.Grouping {
    public init?(tteName: String) {
        switch tteName {
        case "row": self = .row
        case "column": self = .column
        case "diagonal": self = .diagonal
        default: return nil
        }
    }
}

extension SlideEffect.MovementEasing {
    public init?(tteName: String) {
        switch tteName {
        case "linear": self = .linear
        case "in_out_quad": self = .inOutQuad
        case "out_expo": self = .outExpo
        case "out_circ": self = .outCirc
        case "in_out_quart": self = .inOutQuart
        case "in_out_expo": self = .inOutExpo
        case "out_sine": self = .outSine
        case "in_out_sine": self = .inOutSine
        default: return nil
        }
    }
}

extension LaserEtchEffect.Configuration.EtchPattern {
    public init?(tteName: String) {
        switch tteName {
        case "algorithm": self = .algorithm
        case "row_top_to_bottom": self = .rowTopToBottom
        case "row_bottom_to_top": self = .rowBottomToTop
        case "column_left_to_right": self = .columnLeftToRight
        case "column_right_to_left": self = .columnRightToLeft
        case "diagonal_top_left_to_bottom_right": self = .diagonalTopLeftToBottomRight
        case "diagonal_bottom_left_to_top_right": self = .diagonalBottomLeftToTopRight
        case "diagonal_top_right_to_bottom_left": self = .diagonalTopRightToBottomLeft
        case "diagonal_bottom_right_to_top_left": self = .diagonalBottomRightToTopLeft
        case "center_to_outside": self = .centerToOutside
        case "outside_to_center": self = .outsideToCenter
        default: return nil
        }
    }
}

extension BeamsEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "beams" || !settings.values.isEmpty else { return }
        if let value = settings.strings("beam-row-symbols") { beamRowSymbols = value }
        if let value = settings.strings("beam-column-symbols") { beamColumnSymbols = value }
        if let value = settings.int("beam-delay") { beamDelay = value }
        if let value = settings.intRange("beam-row-speed-range") { beamRowSpeedRange = value.0...value.1 }
        if let value = settings.intRange("beam-column-speed-range") { beamColumnSpeedRange = value.0...value.1 }
        if let value = settings.colors("beam-gradient-stops") { beamGradientStops = value }
        if let value = settings.ints("beam-gradient-steps") { beamGradientSteps = value }
        if let value = settings.int("beam-gradient-frames") { beamGradientFrames = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.int("final-gradient-frames") { finalGradientFrames = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
        if let value = settings.int("final-wipe-speed") { finalWipeSpeed = value }
    }
}

extension BinaryPathEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "binarypath" || !settings.values.isEmpty else { return }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
        if let value = settings.colors("binary-colors") { binaryColors = value }
        if let value = settings.double("movement-speed") { movementSpeed = value }
        if let value = settings.double("active-binary-groups") { activeBinaryGroups = value }
    }
}

extension BlackholeEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "blackhole" || !settings.values.isEmpty else { return }
        if let value = settings.color("blackhole-color") { blackholeColor = value }
        if let value = settings.colors("star-colors") { starColors = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension BouncyBallsEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "bouncyballs" || !settings.values.isEmpty else { return }
        if let value = settings.colors("ball-colors") { ballColors = value }
        if let value = settings.strings("ball-symbols") { ballSymbols = value }
        if let value = settings.int("ball-delay") { ballDelay = value }
        if let value = settings.double("movement-speed") { movementSpeed = value }
        if let value = settings.easing("movement-easing") { movementEasing = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension BubblesEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "bubbles" || !settings.values.isEmpty else { return }
        if let value = settings.bool("rainbow") { rainbow = value }
        if let value = settings.colors("bubble-colors") { bubbleColors = value }
        if let value = settings.color("pop-color") { popColor = value }
        if let value = settings.double("bubble-speed") { bubbleSpeed = value }
        if let value = settings.int("bubble-delay") { bubbleDelay = value }
        if let value = settings.string("pop-condition"), let parsed = BubblesEffect.PopCondition(tteName: value) { popCondition = parsed }
        if let value = settings.easing("movement-easing") { movementEasing = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension BurnEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "burn" || !settings.values.isEmpty else { return }
        if let value = settings.color("starting-color") { startingColor = value }
        if let value = settings.colors("burn-colors") { burnColors = value }
        if let value = settings.double("smoke-chance") { smokeChance = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension ColorShiftEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "colorshift" || !settings.values.isEmpty else { return }
        if let value = settings.colors("gradient-stops") { gradientStops = value }
        if let value = settings.ints("gradient-steps") { gradientSteps = value }
        if let value = settings.int("gradient-frames") { gradientFrames = value }
        if let value = settings.bool("no-travel") { noTravel = value }
        if let value = settings.gradientDirection("travel-direction") { travelDirection = value }
        if let value = settings.bool("reverse-travel-direction") { reverseTravelDirection = value }
        if let value = settings.bool("no-loop") { noLoop = value }
        if let value = settings.int("cycles") { cycles = value }
        if let value = settings.bool("skip-final-gradient") { skipFinalGradient = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension CrumbleEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "crumble" || !settings.values.isEmpty else { return }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension DecryptEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "decrypt" || !settings.values.isEmpty else { return }
        if let value = settings.int("typing-speed") { typingSpeed = value }
        if let value = settings.colors("ciphertext-colors") { ciphertextColors = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension ErrorCorrectEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "errorcorrect" || !settings.values.isEmpty else { return }
        if let value = settings.double("error-pairs") { errorPairs = value }
        if let value = settings.int("swap-delay") { swapDelay = value }
        if let value = settings.color("error-color") { errorColor = value }
        if let value = settings.color("correct-color") { correctColor = value }
        if let value = settings.double("movement-speed") { movementSpeed = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension ExpandEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "expand" || !settings.values.isEmpty else { return }
        if let value = settings.easing("expand-easing") { movementEasing = value }
        if let value = settings.double("movement-speed") { movementSpeed = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension FireworksEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "fireworks" || !settings.values.isEmpty else { return }
        if let value = settings.bool("explode-anywhere") { explodeAnywhere = value }
        if let value = settings.colors("firework-colors") { fireworkColors = value }
        if let value = settings.string("firework-symbol") { fireworkSymbol = value }
        if let value = settings.double("firework-volume") { fireworkVolume = value }
        if let value = settings.int("launch-delay") { launchDelay = value }
        if let value = settings.double("explode-distance") { explodeDistance = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension HighlightEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "highlight" || !settings.values.isEmpty else { return }
        if let value = settings.double("highlight-brightness") { highlightBrightness = value }
        if let value = settings.string("highlight-direction"), let parsed = HighlightEffect.Direction(tteName: value) { highlightDirection = parsed }
        if let value = settings.int("highlight-width") { highlightWidth = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension LaserEtchEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "laseretch" || !settings.values.isEmpty else { return }
        if let value = settings.string("etch-pattern"), let parsed = LaserEtchEffect.Configuration.EtchPattern(tteName: value) { etchPattern = parsed }
        if let value = settings.int("etch-speed") { etchSpeed = value }
        if let value = settings.int("etch-delay") { etchDelay = value }
        if let value = settings.colors("cool-gradient-stops") { coolGradientStops = value }
        if let value = settings.colors("laser-gradient-stops") { laserGradientStops = value }
        if let value = settings.colors("spark-gradient-stops") { sparkGradientStops = value }
        if let value = settings.int("spark-cooling-frames") { sparkCoolingFrames = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.int("final-gradient-frames") { finalGradientFrames = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension MatrixEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "matrix" || !settings.values.isEmpty else { return }
        if let value = settings.color("highlight-color") { highlightColor = value }
        if let value = settings.colors("rain-color-gradient") { rainColorGradient = value }
        if let value = settings.strings("rain-symbols") { rainSymbols = value }
        if let value = settings.intRange("rain-fall-delay-range") { rainFallDelayRange = value.0...value.1 }
        if let value = settings.intRange("rain-column-delay-range") { rainColumnDelayRange = value.0...value.1 }
        if let value = settings.int("rain-time") { rainTime = value }
        if let value = settings.double("symbol-swap-chance") { symbolSwapChance = value }
        if let value = settings.double("color-swap-chance") { colorSwapChance = value }
        if let value = settings.int("resolve-delay") { resolveDelay = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.int("final-gradient-frames") { finalGradientFrames = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension MiddleoutEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "middleout" || !settings.values.isEmpty else { return }
        if let value = settings.color("starting-color") { startingColor = value }
        if let value = settings.string("expand-direction"), let parsed = MiddleoutEffect.ExpandDirection(tteName: value) { expandDirection = parsed }
        if let value = settings.double("center-movement-speed") { centerMovementSpeed = value }
        if let value = settings.double("full-movement-speed") { fullMovementSpeed = value }
        if let value = settings.easing("center-easing") { centerEasing = value }
        if let value = settings.easing("full-easing") { fullEasing = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension OrbittingVolleyEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "orbittingvolley" || !settings.values.isEmpty else { return }
        if let value = settings.string("top-launcher-symbol") { topLauncherSymbol = value }
        if let value = settings.string("right-launcher-symbol") { rightLauncherSymbol = value }
        if let value = settings.string("bottom-launcher-symbol") { bottomLauncherSymbol = value }
        if let value = settings.string("left-launcher-symbol") { leftLauncherSymbol = value }
        if let value = settings.double("launcher-movement-speed") { launcherMovementSpeed = value }
        if let value = settings.double("character-movement-speed") { characterMovementSpeed = value }
        if let value = settings.double("volley-size") { volleySize = value }
        if let value = settings.int("launch-delay") { launchDelay = value }
        if let value = settings.easing("character-easing") { characterEasing = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension OverflowEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "overflow" || !settings.values.isEmpty else { return }
        if let value = settings.colors("overflow-gradient-stops") { overflowGradientStops = value }
        if let value = settings.intRange("overflow-cycles-range") { overflowCyclesRange = value.0...value.1 }
        if let value = settings.int("overflow-speed") { overflowSpeed = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension PourEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "pour" || !settings.values.isEmpty else { return }
        if let value = settings.string("pour-direction"), let parsed = PourEffect.PourDirection(tteName: value) { pourDirection = parsed }
        if let value = settings.int("pour-speed") { pourSpeed = value }
        if let value = settings.floatRange("movement-speed-range") { movementSpeedRange = value.0...value.1 }
        if let value = settings.int("gap") { gap = value }
        if let value = settings.color("starting-color") { startingColor = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.int("final-gradient-frames") { finalGradientFrames = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
        if let value = settings.easing("movement-easing") { movementEasing = value }
    }
}

extension PrintEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "print" || !settings.values.isEmpty else { return }
        if let value = settings.double("print-head-return-speed") { printHeadReturnSpeed = value }
        if let value = settings.int("print-speed") { printSpeed = value }
        if let value = settings.easing("print-head-easing") { printHeadEasing = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension RainEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "rain" || !settings.values.isEmpty else { return }
        if let value = settings.colors("rain-colors") { rainColors = value }
        if let value = settings.floatRange("movement-speed") { movementSpeed = value }
        if let value = settings.strings("rain-symbols") { rainSymbols = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
        if let value = settings.easing("movement-easing") { movementEasing = value }
    }
}

extension RandomSequenceEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "randomsequence" || !settings.values.isEmpty else { return }
        if let value = settings.double("speed") { speed = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.int("final-gradient-frames") { finalGradientFrames = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension RingsEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "rings" || !settings.values.isEmpty else { return }
        if let value = settings.colors("ring-colors") { ringColors = value }
        if let value = settings.double("ring-gap") { ringGap = value }
        if let value = settings.int("spin-duration") { spinDuration = value }
        if let value = settings.floatRange("spin-speed") { spinSpeed = value.0...value.1 }
        if let value = settings.int("disperse-duration") { disperseDuration = value }
        if let value = settings.int("spin-disperse-cycles") { spinDisperseCycles = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension ScatteredEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "scattered" || !settings.values.isEmpty else { return }
        if let value = settings.double("movement-speed") { movementSpeed = value }
        if let value = settings.easing("movement-easing") { movementEasing = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.int("final-gradient-frames") { finalGradientFrames = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension SliceEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "slice" || !settings.values.isEmpty else { return }
        if let value = settings.string("slice-direction"), let parsed = SliceEffect.Direction(tteName: value) { direction = parsed }
        if let value = settings.double("movement-speed") { movementSpeed = value }
        if let value = settings.easing("movement-easing") { movementEasing = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension SlideEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "slide" || !settings.values.isEmpty else { return }
        if let value = settings.double("movement-speed") { movementSpeed = value }
        if let value = settings.string("grouping"), let parsed = SlideEffect.Grouping(tteName: value) { grouping = parsed }
        if let value = settings.int("gap") { gap = value }
        if let value = settings.bool("reverse-direction") { reverseDirection = value }
        if let value = settings.bool("merge") { merge = value }
        if let value = settings.string("movement-easing"), let parsed = SlideEffect.MovementEasing(tteName: value) { movementEasing = parsed }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.int("final-gradient-frames") { finalGradientFrames = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension SmokeEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "smoke" || !settings.values.isEmpty else { return }
        if let value = settings.color("starting-color") { startingColor = value }
        if let value = settings.strings("smoke-symbols") { smokeSymbols = value }
        if let value = settings.colors("smoke-gradient-stops") { smokeGradientStops = value }
        if let value = settings.bool("use-whole-canvas") { useWholeCanvas = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension SpotlightsEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "spotlights" || !settings.values.isEmpty else { return }
        if let value = settings.double("beam-width-ratio") { beamWidthRatio = value }
        if let value = settings.double("beam-falloff") { beamFalloff = value }
        if let value = settings.int("search-duration") { searchDuration = value }
        if let value = settings.floatRange("search-speed-range") { searchSpeedRange = value.0...value.1 }
        if let value = settings.int("spotlight-count") { spotlightCount = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension SprayEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "spray" || !settings.values.isEmpty else { return }
        if let value = settings.string("spray-position"), let parsed = SprayEffect.Position(tteName: value) { position = parsed }
        if let value = settings.double("spray-volume") { volume = value }
        if let value = settings.floatRange("movement-speed-range") { movementSpeedRange = value.0...value.1 }
        if let value = settings.easing("movement-easing") { movementEasing = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension SwarmEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "swarm" || !settings.values.isEmpty else { return }
        if let value = settings.colors("base-color") { baseColors = value }
        if let value = settings.color("flash-color") { flashColor = value }
        if let value = settings.double("swarm-size") { swarmSize = value }
        if let value = settings.double("swarm-coordination") { swarmCoordination = value }
        if let value = settings.intRange("swarm-area-count-range") { swarmAreaCountRange = value.0...value.1 }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension SweepEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "sweep" || !settings.values.isEmpty else { return }
        if let value = settings.strings("sweep-symbols") { sweepSymbols = value }
        if let value = settings.string("first-sweep-direction"), let parsed = SweepEffect.Direction(tteName: value) { firstSweepDirection = parsed }
        if let value = settings.string("second-sweep-direction"), let parsed = SweepEffect.Direction(tteName: value) { secondSweepDirection = parsed }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension SynthGridEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "synthgrid" || !settings.values.isEmpty else { return }
        if let value = settings.colors("grid-gradient-stops") { gridGradientStops = value }
        if let value = settings.ints("grid-gradient-steps") { gridGradientSteps = value }
        if let value = settings.gradientDirection("grid-gradient-direction") { gridGradientDirection = value }
        if let value = settings.colors("text-gradient-stops") { textGradientStops = value }
        if let value = settings.ints("text-gradient-steps") { textGradientSteps = value }
        if let value = settings.gradientDirection("text-gradient-direction") { textGradientDirection = value }
        if let value = settings.string("grid-row-symbol") { gridRowSymbol = value }
        if let value = settings.string("grid-column-symbol") { gridColumnSymbol = value }
        if let value = settings.strings("text-generation-symbols") { textGenerationSymbols = value }
        if let value = settings.double("max-active-blocks") { maxActiveBlocks = value }
    }
}

extension ThunderstormEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "thunderstorm" || !settings.values.isEmpty else { return }
        if let value = settings.color("lightning-color") { lightningColor = value }
        if let value = settings.color("glowing-text-color") { glowingTextColor = value }
        if let value = settings.int("text-glow-time") { textGlowTime = value }
        if let value = settings.strings("raindrop-symbols") { raindropSymbols = value }
        if let value = settings.strings("spark-symbols") { sparkSymbols = value }
        if let value = settings.color("spark-glow-color") { sparkGlowColor = value }
        if let value = settings.int("spark-glow-time") { sparkGlowTime = value }
        if let value = settings.int("storm-time") { stormTime = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.int("final-gradient-frames") { finalGradientFrames = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension UnstableEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "unstable" || !settings.values.isEmpty else { return }
        if let value = settings.color("unstable-color") { unstableColor = value }
        if let value = settings.easing("explosion-ease") { explosionEasing = value }
        if let value = settings.double("explosion-speed") { explosionSpeed = value }
        if let value = settings.easing("reassembly-ease") { reassemblyEasing = value }
        if let value = settings.double("reassembly-speed") { reassemblySpeed = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension VHSTapeEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "vhstape" || !settings.values.isEmpty else { return }
        if let value = settings.colors("glitch-line-colors") { glitchLineColors = value }
        if let value = settings.colors("glitch-wave-colors") { glitchWaveColors = value }
        if let value = settings.colors("noise-colors") { noiseColors = value }
        if let value = settings.double("glitch-line-chance") { glitchLineChance = value }
        if let value = settings.double("noise-chance") { noiseChance = value }
        if let value = settings.int("total-glitch-time") { totalGlitchTime = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension WavesEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "waves" || !settings.values.isEmpty else { return }
        if let value = settings.strings("wave-symbols") { waveSymbols = value }
        if let value = settings.colors("wave-gradient-stops") { waveGradientStops = value }
        if let value = settings.ints("wave-gradient-steps") { waveGradientSteps = value }
        if let value = settings.int("wave-count") { waveCount = value }
        if let value = settings.int("wave-length") { waveLength = value }
        if let value = settings.string("wave-direction"), let parsed = WavesEffect.Direction(tteName: value) { waveDirection = parsed }
        if let value = settings.easing("wave-easing") { waveEasing = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

extension WipeEffect.Configuration {
    public mutating func apply(_ settings: ParsedEffectSettings) {
        guard settings.effectName == "wipe" || !settings.values.isEmpty else { return }
        if let value = settings.string("wipe-direction"), let parsed = WipeEffect.Direction(tteName: value) { direction = parsed }
        if let value = settings.int("wipe-delay") { delay = value }
        if let value = settings.easing("wipe-ease") { easing = value }
        if let value = settings.colors("final-gradient-stops") { finalGradientStops = value }
        if let value = settings.ints("final-gradient-steps") { finalGradientSteps = value }
        if let value = settings.int("final-gradient-frames") { finalGradientFrames = value }
        if let value = settings.gradientDirection("final-gradient-direction") { finalGradientDirection = value }
    }
}

