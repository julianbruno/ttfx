# TTE v0.15 ajustes → Swift

Comparar los 37 efectos de [terminaltexteffects](https://github.com/ChrisBuilds/terminaltexteffects) v0.15 y sus ajustes (flags CLI) con este puerto Swift, y cablear esos settings para que Swift los respete.

Completado el 2026-09-16 / 2026-09-17.

## Tareas

- [x] Inventariar los 37 nombres TTE y cada flag per-effect (nombre, default TTE/Rust, si Swift lo expone)
- [x] Darle a `print` una configuración con forma TTE (`print-speed`, `print-head-return-speed`, `print-head-easing`, gradient final) y dejar de usar solo constantes hardcodeadas
- [x] Parsear flags TTE/Rust después del nombre del efecto en el CLI Swift y rechazar flags desconocidos
- [x] Aplicar esas configs al construir cada efecto registrado (defaults iguales si no hay flags)
- [x] Tests CLI parse/help y diferencia de frames en `print` / `rain` / `wipe`; re-correr parity default print/wipe/expand y el smoke de 37 efectos
- [x] Lanzar el `ttfx` real: `print` default y `print --print-speed 5`, dos veces cada uno, y comprobar que default≠speed

## Cómo usarlo

```sh
ttfx print --print-speed 5
ttfx rain --rain-symbols o .
ttfx wipe --wipe-direction column_left_to_right
ttfx print --help
```

Los 37 nombres coincidían ya. Faltaba que el CLI aceptara los ajustes y que `print` no ignorara speed/easing/gradient.

## Notas

- Este Swift no acepta `swift run --product ttfx`; el binario real es `swift run ttfx` / `.build/debug/ttfx`.
- `ttfx <effect>` ahora escribe cada frame de la animación, no solo el último, para que `--print-speed` se vea en el entry point real.
