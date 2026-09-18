# Your first ttfx animation: macOS, Ubuntu, and Windows

Start with a short text animation in your terminal. You do not need to know Swift or Rust: the tools below download the project and build its executable.

## Choose your platform

| Computer | Path in this guide | What is established today |
|---|---|---|
| macOS 14 or newer | Native **Swift CLI**; optional gallery afterward | Swift CLI and Apple apps have local macOS evidence. Swift 6.2 or newer is required. |
| Ubuntu | **Rust CLI**, the reference implementation | Repository CI includes Rust Ubuntu tests/builds; this guide's installation was not rerun on Ubuntu. |
| Windows | **Rust CLI inside Ubuntu/WSL**, not a native Windows app | Linux route based on Microsoft's WSL instructions; not locally verified on Windows/WSL. |

**These are different implementations.** The Swift port is the focus of this repository's current Apple-platform work. The CLI-only graph and POSIX/Windows terminal adapters are now implemented, with local macOS lifecycle proof. Native Ubuntu/Windows compilation and runtime verification remain pending, so the Rust/WSL reference paths stay the beginner defaults. A three-OS CI definition is not successful CI evidence. SwiftUI/Metal gallery and comparison apps are not Ubuntu or Windows apps.

## Before you start

- You need internet access and permission to install development tools.
- Copy only the commands inside the code blocks, one line at a time, and press Enter. Do not type the headings or the word `sh`.
- `cd` changes the folder you are working in. `printf` supplies text; `|` sends it into ttfx.
- Installation and first builds can take several minutes. A password prompt may show no characters while you type; that is normal.

## macOS: run native Swift

### 1. Open Terminal and prepare the tools

Open **Applications → Utilities → Terminal**. Install Apple's command-line tools if they are not already installed:

```sh
xcode-select --install
```

Finish the installation dialog. An “already installed” message is fine. Check the tools:

```sh
git --version
swift --version
```

The Swift version must be **6.2 or newer**, as required by this repository's package. If Swift is missing or older, follow [Swift's official macOS installation guide](https://www.swift.org/install/macos/) to install a current toolchain, then reopen Terminal and check again. Full Xcode and XcodeGen are not required for this CLI-only path. Apple's [command-line tools documentation](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/) explains the developer tools installation.

### 2. Download and build

Run in Terminal:

```sh
cd ~
git clone https://github.com/julianbruno/ttfx.git
cd ttfx
export TTFX_CLI_ONLY=1
swift build --product ttfx
```

`git clone` creates a `ttfx` folder in your home folder; the public HTTPS download does not require a GitHub account. The first build downloads Swift package dependencies. Wait for a successful build before continuing.

### 3. Play your first animation

```sh
printf 'Hello\nTTFX' | ./.build/debug/ttfx --canvas-width 12 --canvas-height 6 print
```

You should see two lines appear with a print-head animation, then return to the terminal prompt. The explicit executable path selects **Swift**, even if another `ttfx` is installed.

Explore another effect and its options:

```sh
printf 'Hello\nTTFX' | ./.build/debug/ttfx --canvas-width 12 --canvas-height 6 decrypt
./.build/debug/ttfx print --help
```

Global options such as canvas size go **before** the effect name; effect-specific options go **after** it. For example:

```sh
printf 'Hello\nTTFX' | ./.build/debug/ttfx --canvas-width 12 --canvas-height 6 print --print-speed 5
```

To return another day, open Terminal, run `cd ~/ttfx`, and reuse the animation command. Rebuild after changing or updating the source.

Before building any graphical product in this terminal, run `unset TTFX_CLI_ONLY` to restore the default app package graph.

**Want windows instead of a terminal animation?** Continue with the [gallery setup](swift-port/README.md#gallery-app-macos-and-ios-simulator) (full Xcode and XcodeGen), or the [macOS comparison app guide](swift-port/video-comparison.md). Those are separate, optional setup paths.

## Ubuntu: run the Rust reference

### 1. Open Terminal and install prerequisites

Press **Ctrl+Alt+T**, then run:

```sh
sudo apt update
sudo apt install -y build-essential curl git ca-certificates
```

`sudo` asks for your Ubuntu password and installs system packages. `build-essential` supplies the compiler/linker needed to build Rust programs. This prerequisite is described in the [official Rust installation chapter](https://doc.rust-lang.org/book/ch01-01-installation.html).

### 2. Install Rust

Use the installer from [Rust's official installation page](https://rust-lang.org/tools/install/):

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
. "$HOME/.cargo/env"
cargo --version
```

The first command downloads and executes Rust's official installer; read its prompts and accept the standard installation if appropriate. Do not substitute an untrusted script. `cargo` is Rust's build tool; the last command should print its version.

### 3. Download, build, and animate

Run in the Ubuntu terminal:

```sh
cd ~
git clone https://github.com/julianbruno/ttfx.git
cd ttfx
cargo build --release
printf 'Hello\nTTFX' | ./target/release/ttfx --canvas-width 12 --canvas-height 6 print
```

Wait for the build to finish successfully. The animation should print `Hello` and `TTFX`, then finish. This executable is **Rust**, not Swift.

For more effects/options:

```sh
./target/release/ttfx --help
./target/release/ttfx print --help
printf 'Hello\nTTFX' | ./target/release/ttfx --canvas-width 12 --canvas-height 6 decrypt
```

Press **Ctrl+C** to interrupt a Rust animation. On a later visit, run `cd ~/ttfx` and reuse the `./target/release/ttfx` command; rebuilding is only needed after source changes.

The same Rust build/run commands work on macOS after installing Apple's command-line tools and Rust. Keep the explicit paths: Rust uses `./target/release/ttfx`, Swift uses `./.build/debug/ttfx`.

## Windows: use Ubuntu inside WSL

This route runs the **Linux Rust CLI** on Windows. It does not install a native Windows Swift executable, Metal gallery, or comparison app.

### 1. Install Ubuntu/WSL from PowerShell

For Windows 11 or Windows 10 version 2004/build 19041 or newer, open **PowerShell as administrator** (right-click → Run as administrator):

```powershell
wsl --install -d Ubuntu
```

Restart when requested. These steps follow [Microsoft's WSL installation guide](https://learn.microsoft.com/en-us/windows/wsl/install). For older Windows versions or a failed installation, use that guide rather than continuing with the Linux commands in PowerShell.

### 2. Open Ubuntu and create your Linux account

Open **Ubuntu** from Start, or select its profile in Windows Terminal. Complete its first-run username/password setup. The Linux password is separate from your Windows login and is invisible while typed. See [Microsoft's WSL environment setup](https://learn.microsoft.com/en-us/windows/wsl/setup/environment).

### 3. Follow the Ubuntu section above

Run **all Ubuntu commands inside the Ubuntu terminal**, not PowerShell. Start with its prerequisites, install Rust there, then clone/build/run there. Keep the repository under `~/ttfx` in the Linux home folder, not under `C:\`, to avoid mixing Windows and Linux tool paths.

Next time, open Ubuntu, run `cd ~/ttfx`, and run the Rust animation again. Native Windows and WSL installations were **not tested on this macOS documentation host**.

## Experimental native Swift on Ubuntu and Windows

**For contributors, not a verified beginner support promise.** Native terminal adapters exist; these hosts have not yet compiled or exercised this project locally. You can try the CLI-only graph without Apple GUI frameworks. Keep the Rust/WSL paths above if you want the reference implementation.

First install Git and **Swift 6.2 or newer**, then check `git --version` and `swift --version`. Follow [Swift's Ubuntu installation guide](https://www.swift.org/install/linux/ubuntu/) for your Ubuntu release. On Windows, follow [Swift's official Windows installation guide](https://www.swift.org/install/windows/), including its Visual Studio C++ tools/Windows SDK prerequisites; installing only the Swift executable is not enough. Reopen your terminal after installation. No installer steps were executed for this guide.

Use your existing checkout, or clone it once with the HTTPS command in the macOS section. Run the following from the `ttfx` folder:

### macOS / Ubuntu terminal

```sh
export TTFX_CLI_ONLY=1
swift build --product ttfx
swift test --filter 'TerminalRuntimeTests|TerminalLayoutTests|NativeTerminalPolicyTests|PackageGraphTests'
printf 'Hello Swift' | swift run --skip-build ttfx --seed 42 print
```

### Native Windows PowerShell

```powershell
$env:TTFX_CLI_ONLY = '1'
swift build --product ttfx
swift test --filter 'TerminalRuntimeTests|TerminalLayoutTests|NativeTerminalPolicyTests|PackageGraphTests'
"Hello Swift" | swift run --skip-build ttfx --seed 42 print
```

Stop if the build fails; do not interpret a documented command as a tested Windows/Ubuntu result. Record your OS, Swift version, terminal and error when reporting it. These focused tests do not need Rust; the broader oracle suites require Rust/cargo. For GUI work on macOS, unset `TTFX_CLI_ONLY` or set it to `0`.

The native CLI supports repaint, pacing, cursor cleanup, cancellation and settled resize, but full Rust CLI compatibility is still partial. Input ANSI `always`/`dynamic` colors, terminal-background mixing, hidden-mode/parser details and comprehensive non-default effect parity remain pending. Read the [native terminal status](swift-port/native-terminal-runtime.md) before treating it as a production replacement.

## If something goes wrong

| Symptom | What to do |
|---|---|
| `cargo: command not found` | Reopen the Ubuntu/macOS terminal after Rust installation, or run `. "$HOME/.cargo/env"` there. Do not use that shell command in PowerShell. |
| Swift missing/too old | Install a Swift 6.2+ toolchain using the official macOS guide, then check `swift --version`. |
| `No such file or directory` for the executable | Run `cd ~/ttfx`, confirm the build succeeded, and use the path for the implementation you built. |
| `destination path 'ttfx' already exists` | If it is your existing checkout, use `cd ~/ttfx`; do not clone again or delete the folder. |
| `NO INPUT.` or no text | Supply text with the complete `printf ... | ...` example. Running only the effect name supplies no input. |
| Escaped characters or strange layout | Run directly in a normal terminal, not a text editor or redirected output file. Enlarge the terminal and retry the small example. |
| Clone asks for credentials | Confirm you copied the public `https://github.com/julianbruno/ttfx.git` URL; no SSH setup is needed. |
| SwiftUI/Metal build errors on Ubuntu/Windows | Do not use the Apple app setup there. Set the CLI-only variable shown below when experimenting with native Swift; GUI products are Apple-only. Native Ubuntu/Windows validation remains pending. |

## What was actually checked

On **2026-09-17**, existing local macOS Rust and Swift binaries accepted `--help` and the exact `print` commands above, exited successfully, and emitted animation bytes. Output redirection checked execution, not visual appearance. Guide shell blocks were syntax-checked without running installers; repository links were checked. Native macOS lifecycle/pacing/resize/cancellation and focused tests were subsequently checked as documented in the native terminal status. Experimental Ubuntu/Windows commands were reviewed, not run; no fresh installation or all-platform parity test was performed. See the [Swift status and measured parity scope](swift-port/README.md) for deeper technical evidence.
