# Plan: preview Metal real en TTFXGalleryApp

Hoy la galería **no usa GPU**. Metal arma un buffer de celdas y un `MTKView`, pero no encodea un render pass ni presenta el drawable. Por eso `TTFXGalleryPreviewRendererSelection.resolve` fuerza SwiftUI y el pie dice *Metal GPU view not connected yet*.

Este plan es para un agente limpio: conectar Metal de verdad, ver glifos en el `.app` de Mac, y dejar SwiftUI como fallback.

## Quick path

1. Leer este archivo y los 4 archivos de código de la tabla **Estado actual**.
2. Hacer que `TTFXMetalRenderer` dibuje y presente un drawable (tests RED de plan de comandos primero).
3. Encender Metal en la galería cuando hay device + `MTKView`.
4. Verificar con tests headless **y** `TTFXGalleryApp.app` en My Mac.

## Estado actual

| Pieza | Dónde | Qué hace hoy |
|---|---|---|
| Upload plan | `Sources/ttfx-swift/SwiftUI/Renderer.swift` `TTFXMetalFrameUploadPlan` / `TTFXMetalGlyphCell` | Empaca codepoint, RGB, origen de cada celda. Tests headless en `tests/ttfx-swiftUITests/RendererTests.swift`. |
| Command plan | `TTFXMetalCommandPlan` | Con GPU: allocate + upload + `encodeGlyphDraw`. Sin GPU: skip. **Nadie ejecuta `encodeGlyphDraw`.** |
| Renderer | `TTFXMetalRenderer.prepare` | Copia celdas a `MTLBuffer`, crea un `MTLCommandBuffer` y lo tira. No pipeline, no vertices, no `present`. |
| Vista | `Sources/ttfx-swift/SwiftUI/Views.swift` `TTFXMetalFrameView` | `MTKView` pausado. `draw(in:)` solo llama `prepare`. Pantalla vacía. |
| Galería | `TTFXGalleryPreviewRendererSelection.resolve` | **Siempre** `.swiftUIFrameView`. El `switch` de `TTFXGalleryRootView` que instancia `TTFXMetalFrameView` nunca corre. |

Origen de coordenadas: `TTFXFrameSnapshot` recorre filas de `frame.rows` → `1` (arriba primero en texto). `TTFXMetalGlyphCell.cellOriginY` usa `(row - 1) * height` (fila TTE 1 = abajo). El agente tiene que fijar Y de Metal (flip vs `MTKView`) y probarlo con un frame conocido, no adivinar.

## Objetivo

Cuando Metal está disponible (Mac / iOS Simulator):

- El preview de `TTFXGalleryApp` usa `TTFXMetalFrameView`.
- Cada frame del efecto se ve en GPU: fondo de celda + glifo (al menos ASCII + el texto sample).
- El pie de estado no habla de “not connected”; algo como `Metal renderer available`.
- Si no hay device / no hay MetalKit, se queda SwiftUI (como ahora).

## Fuera de alcance

- Paridad visual byte-a-byte con el CLI / Rust.
- Afirmar “GPU parity” en CI headless (no hay drawable controlado).
- Reescribir efectos, el motor, o el CLI.
- App Store / sandbox / App Intents.

## Tareas (en orden)

Trabajar en `TTFXSwiftUI` primero; la galería solo cambia cuando el drawable ya pinta.

### 1. Tests del hueco actual

Archivos: `tests/ttfx-swiftUITests/RendererTests.swift`

- [ ] RED: `prepare` con device (si `MTLCreateSystemDefaultDevice()` existe en el runner) deja un plan con `.encodeGlyphDraw`, no solo skip.
- [ ] RED: hay un seam testeable de “se presentó un drawable” **sin** leer píxeles de GPU en CI. Ejemplo: `lastPresentedDrawableSize` / `lastEncodedOperationCount` en `TTFXMetalRenderer` después de `draw(snapshot:into:)` con un drawable mock o un `MTLCommandBuffer` que se `commit`.
- [ ] Seguir cubriendo el skip headless (`TTFXMetalCommandPlan.headlessSkipReason`).

### 2. Encode + present en `TTFXMetalRenderer`

Archivo: `Sources/ttfx-swift/SwiftUI/Renderer.swift`

- [ ] Pipeline Metal mínimo: un quad por celda (instancing o un vertex buffer).
- [ ] Clear del drawable al color de fondo del canvas (negro está bien).
- [ ] Dibujar `backgroundRGB` de cada celda como rect.
- [ ] Dibujar el glifo. Camino chico recomendado: atlas de textura (CTFont / CGGlyph → `MTLTexture`), samplear en el fragment con `foregroundRGB`. No dibujar letras con SwiftUI encima del `MTKView`.
- [ ] `prepare` no basta: un método tipo `draw(snapshot:cellSize:view:)` que pide `view.currentDrawable` + `currentRenderPassDescriptor`, encodea, `present`, `commit`.
- [ ] Si no hay drawable, devolver skip (mismo motivo headless). No crashear.

### 3. `TTFXMetalFrameView` dibuja de verdad

Archivo: `Sources/ttfx-swift/SwiftUI/Views.swift`

- [ ] El `Coordinator.draw(in:)` llama al draw del renderer, no solo `prepare`.
- [ ] `isPaused = false` **o** `enableSetNeedsDisplay` + `setNeedsDisplay` en cada `update*View` cuando cambia el snapshot (la galería avanza frames con timer).
- [ ] Color pixel format y `clearColor` coherentes con el pass.
- [ ] Reusar el `device` del renderer; no crear un segundo `MTLCreateSystemDefaultDevice()` distinto si se puede pasar `renderer.device`.

### 4. Encender Metal en la galería

Archivos: `TTFXGalleryViewModel.swift`, `TTFXGalleryRootView.swift`, `tests/TTFXGalleryAppTests/TTFXGalleryViewModelTests.swift`

- [ ] `resolve(availability:platformSupportsMetalView:)` → `.metalFrameView` si `availability.isAvailable && platformSupportsMetalView`; si no, `.swiftUIFrameView`.
- [ ] `statusText` para Metal: `availability.message` (hoy “Metal renderer available”).
- [ ] Actualizar tests que hoy esperan SwiftUI aunque Metal esté available (`previewRendererSelectionUsesVisibleSwiftUIFallbackUntilDrawableRenderingIsImplemented`).
- [ ] Fallback SwiftUI intacto para headless (`isAvailable: false`).

### 5. Verificar en el `.app` de Mac

- [ ] `xcodegen generate` si toca el proyecto.
- [ ] `xcodebuild -project TTFXGalleryApp.xcodeproj -scheme TTFXGalleryApp -destination 'platform=macOS' -configuration Debug build`
- [ ] Abrir **`TTFXGalleryApp.app`**, scheme del `.app`, destino **My Mac**. No el ejecutable SwiftPM.
- [ ] Play en `print` / `wipe`: se ven glifos en el preview, no un `MTKView` negro.
- [ ] Pie de estado: Metal available, no “not connected yet”.
- [ ] Sin device (inyectar availability false en tests): SwiftUI sigue mostrando texto.

## Verificación automática

```sh
swift test --filter TTFXSwiftUITests
swift test --filter previewRendererSelection
swift test --filter rendererStatusAndAccessibilityLabelsAreHeadlessInspectable
```

No uses `swift test` de efectos/CLI como prueba de Metal.

## Archivos que no tocar salvo necesidad

- `src/effects/**`, CLI Rust, `PrintEffect` / flags TTE.
- `Package.swift` productos, salvo un recurso de shader `.metal` si el agente lo pone en `Sources/ttfx-swift/SwiftUI` (entonces sí hay que incluirlo como `resources` o que Xcode lo compile; el target `TTFXSwiftUI` es SPM).

Si hace falta un shader: `Sources/ttfx-swift/SwiftUI/Shaders/GlyphCell.metal` + `resources: [.process("Shaders")]` en el target `TTFXSwiftUI`, **o** shader source embebido en Swift para no pelear con SPM. Preferir un `.metal` en el target y comprobar `swift build --product TTFXGalleryApp` y el xcodeproj.

## Criterio de hecho

| Check | Hecho cuando |
|---|---|
| GPU | `draw(in:)` presenta un drawable con celdas visibles (fondo + glifo). |
| Galería | `resolve` elige `.metalFrameView` en Mac con device. |
| Fallback | Headless / sin MetalKit sigue SwiftUI. |
| CI | Tests de plan/upload/skip siguen verdes sin drawable. |
| Manual | `TTFXGalleryApp.app` en My Mac muestra el efecto, no un rectángulo vacío. |

## Next step

Empezar por la tarea 1 (tests RED del encode/present). No cambiar `resolve` a Metal hasta que `TTFXMetalFrameView` pinte algo; si no, la galería vuelve a una pantalla negra.
