#!/bin/sh
set -eu

mode=${1:---regenerate}
case "$mode" in
    --check|--regenerate) ;;
    *) printf '%s\n' "usage: $0 [--check|--regenerate]" >&2; exit 64 ;;
esac

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
cd "$root"

# Admitted Rust oracle pin shared with the RNG fixture; never current HEAD.
revision=6e24dac78e3011d89bd7ff24d1ad91dd89e11d8a
case "$revision" in *[!0-9a-f]*|'') printf '%s\n' "invalid Rust Git revision" >&2; exit 1 ;; esac
[ "${#revision}" -eq 40 ] || { printf '%s\n' "invalid Rust Git revision" >&2; exit 1; }

fixture_parent="tests/fixtures"
fixture_directory="$fixture_parent/effects"
staging=$(mktemp -d "$fixture_parent/.effects-staging.XXXXXX")
backup=""

cleanup() {
    [ -z "${staging:-}" ] || rm -rf "$staging"
    if [ -n "${backup:-}" ] && [ -d "$backup" ] && [ ! -d "$fixture_directory" ]; then
        mv "$backup" "$fixture_directory"
    fi
}
trap cleanup EXIT HUP INT TERM

dump() {
    name=$1
    shift
    printf 'Swift\nTTE' | cargo run --quiet -- --parity-dump --max-frames 32 --seed 42 --ignore-terminal-dimensions --canvas-width 12 --canvas-height 6 --frame-rate 60 "$name" "$@" > "$staging/$name.frames"
}

# Fixed options select real transitions within the 32-frame corpus; no frame is
# synthesized or omitted after the Rust renderer emits it.
dump print
dump slide
dump wipe --wipe-ease out_expo --final-gradient-steps 1 --final-gradient-frames 1
dump expand
dump rain
dump bubbles --bubble-speed 3 --bubble-delay 1
dump fireworks
dump swarm --swarm-size 1 --swarm-coordination 1 --swarm-area-count-range 1-1

{
    printf '%s\n' '{'
    printf '%s\n' '  "format": "ttfx-effect-oracle-v1",'
    printf '  "revision": "%s",\n' "$revision"
    printf '%s\n' '  "frameEncoding": "length-prefixed-utf8-terminal-frame-v1",'
    printf '%s\n' '  "fixtures": ['
    printf '%s\n' '    { "effect": "print", "input": "Swift\nTTE", "seed": 42, "canvas": { "columns": 12, "rows": 6 }, "frameFile": "print.frames" },'
    printf '%s\n' '    { "effect": "slide", "input": "Swift\nTTE", "seed": 42, "canvas": { "columns": 12, "rows": 6 }, "frameFile": "slide.frames" },'
    printf '%s\n' '    { "effect": "wipe", "input": "Swift\nTTE", "seed": 42, "canvas": { "columns": 12, "rows": 6 }, "frameFile": "wipe.frames" },'
    printf '%s\n' '    { "effect": "expand", "input": "Swift\nTTE", "seed": 42, "canvas": { "columns": 12, "rows": 6 }, "frameFile": "expand.frames" },'
    printf '%s\n' '    { "effect": "rain", "input": "Swift\nTTE", "seed": 42, "canvas": { "columns": 12, "rows": 6 }, "frameFile": "rain.frames" },'
    printf '%s\n' '    { "effect": "bubbles", "input": "Swift\nTTE", "seed": 42, "canvas": { "columns": 12, "rows": 6 }, "frameFile": "bubbles.frames" },'
    printf '%s\n' '    { "effect": "fireworks", "input": "Swift\nTTE", "seed": 42, "canvas": { "columns": 12, "rows": 6 }, "frameFile": "fireworks.frames" },'
    printf '%s\n' '    { "effect": "swarm", "input": "Swift\nTTE", "seed": 42, "canvas": { "columns": 12, "rows": 6 }, "frameFile": "swarm.frames" }'
    printf '%s\n' '  ]'
    printf '%s\n' '}'
} > "$staging/manifest.json"

if [ "$mode" = "--check" ]; then
    if [ -d "$fixture_directory" ] && cmp -s "$staging/manifest.json" "$fixture_directory/manifest.json" &&
        cmp -s "$staging/print.frames" "$fixture_directory/print.frames" &&
        cmp -s "$staging/slide.frames" "$fixture_directory/slide.frames" &&
        cmp -s "$staging/wipe.frames" "$fixture_directory/wipe.frames" &&
        cmp -s "$staging/expand.frames" "$fixture_directory/expand.frames" &&
        cmp -s "$staging/rain.frames" "$fixture_directory/rain.frames" &&
        cmp -s "$staging/bubbles.frames" "$fixture_directory/bubbles.frames" &&
        cmp -s "$staging/fireworks.frames" "$fixture_directory/fireworks.frames" &&
        cmp -s "$staging/swarm.frames" "$fixture_directory/swarm.frames"; then
        printf '%s\n' "Effect oracle fixtures are current."
        exit 0
    fi
    printf '%s\n' "Effect oracle fixtures are stale or pinned to a different Rust revision." >&2
    exit 1
fi

backup="$fixture_parent/.effects-backup-$$"
mv "$fixture_directory" "$backup"
if ! mv "$staging" "$fixture_directory"; then
    mv "$backup" "$fixture_directory"
    exit 1
fi
staging=""
rm -rf "$backup"
backup=""
printf '%s\n' "Effect oracle fixtures regenerated for $revision."
