import ArgumentParser
import Testing
@testable import TTFXCLI

@Suite struct CLIParsingTests {
    private let expectedGlobalOptions = [
        "--version",
        "--input-file",
        "--tab-width",
        "--xterm-colors",
        "--no-color",
        "--terminal-background-color",
        "--existing-color-handling",
        "--wrap-text",
        "--frame-rate",
        "--canvas-width",
        "--canvas-height",
        "--anchor-canvas",
        "--anchor-text",
        "--ignore-terminal-dimensions",
        "--reuse-canvas",
        "--no-eol",
        "--no-restore-cursor",
        "--seed",
        "--print-completion",
        "--random-effect",
        "--include-effects",
        "--exclude-effects",
        "--help"
    ]

    @Test func parsesRustGlobalTerminalOptionsAndEffectName() throws {
        let cli = try TTFXCLI.parse([
            "--input-file", "input.txt",
            "--tab-width", "8",
            "--xterm-colors",
            "--no-color",
            "--terminal-background-color", "#112233",
            "--existing-color-handling", "dynamic",
            "--wrap-text",
            "--frame-rate", "24",
            "--canvas-width", "80",
            "--canvas-height", "24",
            "--anchor-canvas", "ne",
            "--anchor-text", "c",
            "--ignore-terminal-dimensions",
            "--reuse-canvas",
            "--no-eol",
            "--no-restore-cursor",
            "--seed", "42",
            "print"
        ])

        #expect(cli.inputFile == "input.txt")
        #expect(cli.terminalOptions.tabWidth == 8)
        #expect(cli.terminalOptions.xtermColors)
        #expect(cli.terminalOptions.noColor)
        #expect(cli.terminalOptions.terminalBackgroundColor == TerminalColor(argument: "#112233")!)
        #expect(cli.terminalOptions.existingColorHandling == .dynamic)
        #expect(cli.terminalOptions.wrapText)
        #expect(cli.terminalOptions.frameRate == 24)
        #expect(cli.terminalOptions.canvasWidth == 80)
        #expect(cli.terminalOptions.canvasHeight == 24)
        #expect(cli.terminalOptions.anchorCanvas == .ne)
        #expect(cli.terminalOptions.anchorText == .center)
        #expect(cli.terminalOptions.ignoreTerminalDimensions)
        #expect(cli.terminalOptions.reuseCanvas)
        #expect(cli.terminalOptions.noEOL)
        #expect(cli.terminalOptions.noRestoreCursor)
        #expect(cli.seed == 42)
        #expect(cli.selectedEffectName == "print")
    }

    @Test func parsesRandomEffectFiltersAndHiddenParityFlags() throws {
        let cli = try TTFXCLI.parse([
            "--random-effect",
            "--include-effects", "rain", "wipe",
            "--m0-dump",
            "--parity-dump",
            "--max-frames", "12",
            "--virtual-clock"
        ])

        #expect(cli.randomEffect)
        #expect(cli.includeEffects == ["rain", "wipe"])
        #expect(cli.excludeEffects.isEmpty)
        #expect(cli.m0Dump)
        #expect(cli.parityDump)
        #expect(cli.maxFrames == 12)
        #expect(cli.virtualClock)
    }

    @Test func helpExposesRustNamesAndHidesParityHarnessFlags() throws {
        let help = TTFXCLI.helpMessage()

        #expect(help.contains("OVERVIEW: Terminal text effects"))
        #expect(help.contains("USAGE: ttfx"))
        for option in expectedGlobalOptions {
            #expect(help.contains(option), "help should expose global option \(option)")
        }
        for effect in TTFXEffectRegistry.names {
            #expect(help.contains(effect), "help should list effect \(effect)")
        }
        #expect(!help.contains("--parity-dump"))
        #expect(!help.contains("--m0-dump"))
    }

    @Test func bashCompletionIncludesStableCommandGlobalOptionsAndAllEffects() {
        let script = TTFXCLI.completionScript(for: .bash)

        #expect(script.contains("complete -F _ttfx ttfx"))
        for option in expectedGlobalOptions {
            #expect(script.contains(option), "bash completion should include global option \(option)")
        }
        #expect(TTFXEffectRegistry.names.count == 37)
        for effect in TTFXEffectRegistry.names {
            #expect(script.contains(effect), "bash completion should include effect \(effect)")
        }
        #expect(!script.contains("--parity-dump"))
        #expect(!script.contains("--m0-dump"))
    }

    @Test func zshCompletionIncludesStableCommandGlobalOptionsAndAllEffects() {
        let script = TTFXCLI.completionScript(for: .zsh)

        #expect(script.contains("#compdef ttfx"))
        #expect(script.contains("_arguments"))
        for option in expectedGlobalOptions {
            #expect(script.contains(option), "zsh completion should include global option \(option)")
        }
        #expect(TTFXEffectRegistry.names.count == 37)
        for effect in TTFXEffectRegistry.names {
            #expect(script.contains(effect), "zsh completion should include effect \(effect)")
        }
        #expect(!script.contains("--parity-dump"))
        #expect(!script.contains("--m0-dump"))
    }

    @Test func rejectsInvalidColorAndUnknownFilterNames() throws {
        #expect(throws: (any Error).self) {
            _ = try TTFXCLI.parse(["--terminal-background-color", "not-a-color"])
        }
        #expect(throws: (any Error).self) {
            _ = try TTFXCLI.parse(["--random-effect", "--exclude-effects", "missing"])
        }
    }

    @Test func registryProvidesAllRustEffectSubcommandNames() {
        #expect(TTFXEffectRegistry.names == [
            "beams", "binarypath", "blackhole", "bouncyballs", "bubbles", "burn",
            "colorshift", "crumble", "decrypt", "errorcorrect", "expand", "fireworks",
            "highlight", "laseretch", "matrix", "middleout", "orbittingvolley",
            "overflow", "pour", "print", "rain", "randomsequence", "rings", "scattered",
            "slice", "slide", "smoke", "spotlights", "spray", "swarm", "sweep",
            "synthgrid", "thunderstorm", "unstable", "vhstape", "waves", "wipe"
        ])
    }
}
