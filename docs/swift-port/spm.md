# Swift Package Integration

Use the repository root as a Swift Package Manager package. The package exposes the native core/effects library product, the command-line executable, and SwiftUI renderer helpers for apps that want an embedded preview or gallery surface.

## Quick path

1. Add this repository as a Swift package dependency.
2. Choose the product that matches your integration surface.
3. Validate locally with `swift package describe` and `swift test` from the package root.

## Products

| Product | Type | Import or run | Use when |
|---|---|---|---|
| `ttfx-swift` | Library | `import TTFXCore`, `import TTFXEffects` | You need deterministic frame/effect primitives, the 37-effect registry, or direct effect execution. |
| `ttfx` | Executable | `swift run ttfx --help` | You want the native Swift command-line entrypoint and hidden parity-dump test path. |
| `TTFXSwiftUI` | Library | `import TTFXSwiftUI` | You want SwiftUI snapshot/gallery/renderer helpers for displaying native frames. |

The library product intentionally keeps module names explicit: core types live in `TTFXCore`, effect constructors and `EffectRegistry` live in `TTFXEffects`, and UI helpers live in `TTFXSwiftUI`.

## Supported platforms and tools

| Requirement | Declared support |
|---|---|
| Swift tools | SwiftPM `swift-tools-version: 6.2` |
| macOS | macOS 14 or later |
| iOS | iOS 17 or later for library and SwiftUI targets |
| External dependency | `swift-argument-parser` for the executable target only |

Rust and Cargo are not required to consume the Swift package. They are required only for parity tests and oracle regeneration checks that compare Swift output with the Rust implementation.

## Dependency snippet

```swift
.package(url: "https://github.com/omacom-io/ttfx.git", branch: "main")
```

Then depend on the product you need:

```swift
.target(
    name: "MyTarget",
    dependencies: [
        .product(name: "ttfx-swift", package: "ttfx")
    ]
)
```

Use `TTFXSwiftUI` instead when the target is a SwiftUI surface. The executable product is normally built or run from the command line rather than linked into another target.

## Local validation

Run these commands from the repository root before tagging or consuming a release candidate:

```sh
swift package describe
swift test
git diff --check
```

`swift test` includes parity-oriented coverage and may launch Rust/Cargo oracle checks in this repository. Avoid running multiple full suites concurrently.

## Notes for maintainers

- Keep `Package.swift` dependency changes narrow; the only external package currently needed is ArgumentParser for `TTFXCLI`.
- Keep the library modules importable without command-line dependencies.
- Keep supported platforms aligned between `Package.swift`, this document, and `docs/swift-port/README.md`.
