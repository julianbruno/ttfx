# Inline Rust versus Swift Metal animations

## Outcome
Focus the root README on the native Swift port of Rust ttfx and display all 37 real comparison animations inline.

## Problem and scope
The root README duplicates a Rust-only Omarchy animation catalog and links the new comparisons without displaying them. Remove only those README images/catalog references, retain upstream credit and accurately scoped Rust claims, and add compact animated previews of the existing labeled Rust/Metal videos. Original Rust GIF assets remain untouched.

## Constraints
English artifacts. Branch: `codex/inline-comparison-animations`. No remote operations, merge, or delegate commit. RDD off. TDD always for behavior; this passive documentation/media change has no source behavior or meaningful RED test. Use structural checks and real media decoding, not invented TDD evidence.

## Tasks
- [x] T01 Generate 37 original-speed inline GIF previews and record regeneration/provenance; verify coverage, frame timing, dimensions, decode and labels.
- [x] T02 Remove Omarchy README animations, emphasize port lineage, embed all 37 comparisons and verify links/diff.

## Acceptance and checks
Every registry effect appears once in the final comparison catalog with a labeled animation and optional full MP4 link. GIF previews are first at most six seconds at 25 fps, not full-length claims. Preserve all full MP4 files. Validate each GIF through ffprobe and error-fatal ffmpeg decode; inspect one frame visually. Check all local README media/link targets and `git diff --check`. Remote GitHub rendering remains unverified.

## Delivery
Forecast: approximately 200 authored changed lines (generated preview/provenance data excluded); two coherent work units. Strategy: ask-on-risk; existing chain preference stacked-to-main if needed. Parent owns commits and records identities before closing tasks. Rollback is limited to this task document, root README changes, new/replaced comparison GIF previews, and comparison regeneration/provenance metadata.

## Progress
T01 outcomes observed: 37 GIF previews generated in 16.3 seconds, 15,903,970 bytes total. Each has 576 × 174 dimensions, expected min(source frames, 150) decoded frames, duration frames/25, and error-fatal FFmpeg decode passed. A decrypt frame inspected at /tmp/ttfx-inline-preview.png has readable Rust (ANSI replay) and Swift Metal labels. Regeneration and detailed per-preview provenance updated. Parent readback and visual label inspection passed; work-unit commit follows.

T02 outcomes observed: root README no longer references docs/effects Omarchy animations; all 37 comparison headings and image embeds match provenance order, all local Markdown targets exist, and git diff --check passes. Root title/introduction emphasize the Swift port of Rust; Rust performance/fidelity sections explicitly retain Rust scope. Parent structural readback and git diff --check passed; work-unit commit follows.

Explored root README, comparison regeneration guide and existing provenance. Existing full videos are labeled 768 × 232, Rust left / Swift Metal right. Choose 576 × 174 previews to retain readable panel labels and limit download size. Conversion expected to take 1–3 minutes and roughly 5–15 MB; verify actual totals afterward. No app/runtime test rerun needed because no behavior changes.

## Next step
Commit the verified coherent media/documentation unit; record its identity. No behavior tests rerun (passive docs/media only); remote GitHub rendering unverified.
