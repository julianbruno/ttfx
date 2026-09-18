# README executive brief

## Outcome
Lead the root README with a short, realistic executive brief for the native Swift port, retain real inline comparisons, and move the existing technical material to a final reference section.

## Problem and scope
The current README mixes repeated Swift status, Rust product positioning, benchmarks, and setup before readers see the overall native-port offering. Change README.md and this ledger only; preserve assets, executable behavior, commands, attribution, and measured evidence.

## Constraints
- English artifacts; no exaggerated readiness, performance, or universal-parity claims.
- Swift is a WIP port of Rust ttfx, itself a port of Python TerminalTextEffects.
- Keep the hero and all 37 labeled Rust-left/Swift-Metal-right inline GIFs and full-video links.
- TDD always, from explicit user/project configuration. This is passive prose: no behavior changes or invented RED. Functional runtime checks are N/A.
- RDD remains off. Parent owns commits; no push, merge, or PR creation.
- Delivery strategy ask-on-risk; established chain preference stacked-to-main. Reordering may exceed 400 authored changed lines without new behavior; no PR is created here.

## Tasks and acceptance
- [x] T01: Write a concise executive brief, clear current capabilities and limitations, hero, and simple entry points.
- [x] T02: Preserve the complete inline catalog and reorganize all existing technical commands, parity scope, capture/UI details, Rust-only evidence, credits, and license into the final reference section.

## Checks
- Compare fenced code blocks and essential evidence against base README.
- Validate local Markdown link paths and root heading anchors.
- Confirm 37 unique catalog entries and unchanged preview/video paths.
- Run git diff --check and inspect the resulting heading order.

## Evidence and next step
T01/T02 implemented and structurally checked. Original 12/12 fenced code blocks preserved; one minimal quick-start block added. All 37 unique catalog entries, captions, preview paths, and MP4 links remain byte-identical. Local destinations and anchors validated (97 after restoring the direct architecture link). Essential parity, capture, Rust benchmark/fidelity, and attribution facts preserved; technical reference follows the catalog. git diff --check passed.

Authored README diff: approximately 750 additions/deletions due to reordering; no generated/source changes. Runtime harness and RED/GREEN are N/A for passive prose. RDD off, no review lifecycle. Rollback boundary: README.md and this ledger only. Parent structural readback and git diff --check passed. T01/T02 share work-unit commit b19cf7e927d82f62d04ce768daa8f51d020f7812. No PR/push/merge; local delivery complete.
