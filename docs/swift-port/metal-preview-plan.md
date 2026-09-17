# Plan: preview Metal real en TTFXGalleryApp

## Estado: implementado y verificado (2026-09-17)

La galería usa Metal por defecto cuando hay device y MetalKit. El control **Use Metal** permite volver al preview SwiftUI existente sin reiniciar el efecto; sin GPU se conserva el fallback automático. El renderer dibuja fondos y glifos con un atlas CoreText, presenta el drawable y confirma el command buffer.

### Evidencia

- `swift test --filter 'TTFXSwiftUITests|TTFXGalleryAppTests'`: **28 tests pasan**, incluidos headless, selección/switch, geometría y envío GPU offscreen.
- Prueba GPU local condicional: glifos A–T en varias filas de atlas, color de fondo exacto, fila inferior vacía y orientación de F. Esto no afirma paridad GPU en CI headless.
- `swift build --product TTFXGalleryApp`: **pasa**, incluido el shader como recurso.
- `./script/build_and_run.sh --verify`: **build Xcode y apertura del `.app` en macOS pasan**. El script usa `.build/xcode`; la acción Run de Codex llama al mismo script.
- Comprobación visual del `.app`: **Hello visible, coloreado y derecho en Print y Wipe**, con `Metal renderer available`. **Use Metal OFF** muestra el SwiftUI existente y `SwiftUI preview — Metal disabled`; **ON** devuelve el preview GPU.
- `xcodegen generate`: **no aplica**, porque no cambió la configuración del proyecto; el recurso pertenece al paquete local.

### Decisiones de implementación

`Shaders/GlyphCell.metal` se copia como recurso SwiftPM y se compila al crear el pipeline, tanto en SwiftPM como en Xcode. `MetalGlyphAtlas.swift` rasteriza glifos con CoreText y construye quads; el fragment mezcla foreground/background usando la cobertura del atlas. La geometría conserva fila TTE 1 abajo y expresa tamaños en puntos para Retina. `MTKView` permanece pausado y se invalida por snapshot o cambio de tamaño de fuente.

La prueba RED inicial detectó la ausencia de `draw` y de sus métricas. `prepare` ya devolvía `.encodeGlyphDraw` con device antes del cambio: no se presenta ese caso como RED. El seam de presentación comprueba envío y commit offscreen; la presentación visible se comprobó en la app.

## Estado inicial (antes de implementar)

Al iniciar este plan la galería **no usaba GPU**. Metal armaba un buffer de celdas y un `MTKView`, pero no encodeaba un render pass ni presentaba el drawable. Por eso `TTFXGalleryPreviewRendererSelection.resolve` forzaba SwiftUI y el pie decía *Metal GPU view not connected yet*.

Este plan es para un agente limpio: conectar Metal de verdad, ver glifos en el `.app` de Mac, y dejar SwiftUI como fallback.

## Repetir la verificación

1. Ejecutar los tests SwiftUI/galería indicados en **Evidencia**.
2. Ejecutar `./script/build_and_run.sh --verify`.
3. Reproducir Print y Wipe; comprobar glifos y estado Metal.
4. Alternar **Use Metal** y comprobar ambos renderers.

## Piezas del estado inicial

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

## Tareas completadas (orden original)

Trabajar en `TTFXSwiftUI` primero; la galería solo cambia cuando el drawable ya pinta.

### 1. Tests del hueco actual

Archivos: `tests/ttfx-swiftUITests/RendererTests.swift`

- [x] Con device, el camino de dibujo conserva `.encodeGlyphDraw`, sube el buffer y completa el command buffer. `prepare` ya producía esa operación antes del cambio; ese caso no fue RED.
- [x] RED observado y resuelto: hay un seam testeable de “se presentó un drawable” **sin** leer píxeles de GPU en CI. Ejemplo: `lastPresentedDrawableSize` / `lastEncodedOperationCount` en `TTFXMetalRenderer` después de `draw(snapshot:into:)` con un drawable mock o un `MTLCommandBuffer` que se `commit`.
- [x] Seguir cubriendo el skip headless (`TTFXMetalCommandPlan.headlessSkipReason`).

### 2. Encode + present en `TTFXMetalRenderer`

Archivo: `Sources/ttfx-swift/SwiftUI/Renderer.swift`

- [x] Pipeline Metal mínimo: un quad por celda (instancing o un vertex buffer).
- [x] Clear del drawable al color de fondo del canvas (negro está bien).
- [x] Dibujar `backgroundRGB` de cada celda como rect.
- [x] Dibujar el glifo. Camino chico recomendado: atlas de textura (CTFont / CGGlyph → `MTLTexture`), samplear en el fragment con `foregroundRGB`. No dibujar letras con SwiftUI encima del `MTKView`.
- [x] `prepare` no basta: un método tipo `draw(snapshot:cellSize:view:)` que pide `view.currentDrawable` + `currentRenderPassDescriptor`, encodea, `present`, `commit`.
- [x] Si no hay drawable, devolver skip (mismo motivo headless). No crashear.

### 3. `TTFXMetalFrameView` dibuja de verdad

Archivo: `Sources/ttfx-swift/SwiftUI/Views.swift`

- [x] El `Coordinator.draw(in:)` llama al draw del renderer, no solo `prepare`.
- [x] `isPaused = false` **o** `enableSetNeedsDisplay` + `setNeedsDisplay` en cada `update*View` cuando cambia el snapshot (la galería avanza frames con timer).
- [x] Color pixel format y `clearColor` coherentes con el pass.
- [x] Reusar el `device` del renderer; no crear un segundo `MTLCreateSystemDefaultDevice()` distinto si se puede pasar `renderer.device`.

### 4. Encender Metal en la galería

Archivos: `TTFXGalleryViewModel.swift`, `TTFXGalleryRootView.swift`, `tests/TTFXGalleryAppTests/TTFXGalleryViewModelTests.swift`

- [x] `resolve(availability:platformSupportsMetalView:)` → `.metalFrameView` si `availability.isAvailable && platformSupportsMetalView`; si no, `.swiftUIFrameView`.
- [x] `statusText` para Metal: `availability.message` (hoy “Metal renderer available”).
- [x] Actualizar tests que hoy esperan SwiftUI aunque Metal esté available (`previewRendererSelectionUsesVisibleSwiftUIFallbackUntilDrawableRenderingIsImplemented`).
- [x] Fallback SwiftUI intacto para headless (`isAvailable: false`).
- [x] Switch **Use Metal**, activo por defecto; OFF selecciona SwiftUI sin modificar el snapshot y ON vuelve a Metal cuando está disponible. Tests y prueba visual cubren ambos estados.

### 5. Verificar en el `.app` de Mac

- [x] `xcodegen generate`: no aplica; no cambió la configuración del proyecto.
- [x] `xcodebuild -project TTFXGalleryApp.xcodeproj -scheme TTFXGalleryApp -destination 'platform=macOS' -configuration Debug build`
- [x] Abrir **`TTFXGalleryApp.app`**, scheme del `.app`, destino **My Mac**. No el ejecutable SwiftPM.
- [x] Play en `print` / `wipe`: se ven glifos en el preview, no un `MTKView` negro.
- [x] Pie de estado: Metal available, no “not connected yet”.
- [x] Sin device (inyectar availability false en tests): SwiftUI sigue mostrando texto.

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

## Límite de rollback

La unidad funcional comprende `Renderer.swift`, `MetalGlyphAtlas.swift`, `Shaders/GlyphCell.metal`, su recurso en `Package.swift`, `Views.swift`, los cambios de selección/control en `TTFXGalleryViewModel.swift` y `TTFXGalleryRootView.swift`, y sus dos archivos de tests. Revertirla restaura la selección SwiftUI anterior; no requiere cambios en efectos, Core o CLI. `script/build_and_run.sh` y `.codex/environments/environment.toml` forman una unidad independiente para el build/apertura local.

## Próxima comprobación

Al cambiar shaders, atlas o representación de coordenadas, repetir los tests GPU condicionales y la verificación visual del `.app`; un build o los tests de efectos/CLI por sí solos no prueban que haya glifos visibles.
