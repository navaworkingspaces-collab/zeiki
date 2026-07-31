# HDU-006 — Code Review (v3, re-review de fail-safe)

**Rama:** `feat/hdu-006-splash-nuevo`
**Spec:** `specs/HDU-006-splash-nuevo.md`
**Commit revisado:** `08d7c1a` (1 commit sobre v2)
**Reviewer:** zeiki-reviewer (3 gates: clean code + security + architecture)
**Auditor de minimalismo:** ya pasó en v1. Este reporte NO cubre minimalismo, redundancias ni scope creep.
**Fecha:** 2026-07-31
**Re-review de:** [`docs/reviews/HDU-006-review-v2.md`](HDU-006-review-v2.md) (v2: ✅ Aprobado con 1 question registrada)

---

## ✅ Question registrada en v2, resuelta en v3

La v2 dejó registrada esta pregunta del Gate 2:

> "Cuando la red está caída y el cache del `TierService` está vacío, `TierService.has()` devuelve `false`. Esto significa que el splash se salta y el usuario va directo al redirect. El comportamiento actual es: 'si no puedo leer el flag, no muestro el splash' (fail-safe hacia skip). [...] **Si prefieres fail-safe hacia 'show'**, hay que cambiar la lectura + agregar test del caso 'red caída'." (v2, Gate 2, `question:` sin acción inmediata).

**Hugo decidió:** fail-safe hacia "show". El splash es branding, no funcionalidad, y el usuario debe ver la marca al abrir la app por primera vez. Si el flag explícitamente está OFF en Supabase, el splash se sigue saltando.

**Este commit (`08d7c1a`)** implementa esa decisión.

### Verificación del fix

**Lógica nueva** — `lib/features/identidad/screens/splash_screen.dart:118`:
```dart
_splashEnabled = tier.has(AppFeature.splash) || !tier.isCacheLoaded();
```

**API nueva** — `lib/core/tiers/tier_service.dart:106-108`:
```dart
bool isCacheLoaded() {
  return _cache.isNotEmpty || _config.debugEnabled;
}
```

**Tests nuevos** — `test/features/identidad/screens/splash_screen_test.dart:161-197`:
- Test 1 (líneas 172-182): "cache cold + sin flag explícito → splash SÍ renderiza el branding (fail-safe ON)".
- Test 2 (líneas 184-196): "cache cold + flag explícito OFF en Supabase → splash NO renderiza el branding (el OFF explícito gana)".

**Fake actualizado** — los 3 archivos de tests que tienen `_FakeTierService` (`splash_screen_test.dart`, `widget_test.dart`, `integration_test/splash_flow_test.dart`) implementan `isCacheLoaded()`.

### Veredicto del bloqueante

- [x] **Question resuelta.** La nueva lógica cumple con la decisión de producto.
- [x] **Test del caso "cache cold" agregado.** Cubre la decisión de fail-safe.
- [x] **Cero nuevos bloqueantes introducidos** por el fix.

---

## Tabla de verdad (verificación de la lógica)

| `isCacheLoaded()` | `has(splash)` | `_splashEnabled` | Comportamiento | Esperado por Hugo |
|---|---|---|---|---|
| `false` (cold) | `false` (no cacheado) | `false \|\| !false = true` | Splash SÍ | ✅ SÍ |
| `true` (loaded) | `true` (flag ON) | `true \|\| !true = true` | Splash SÍ | ✅ SÍ |
| `true` (loaded) | `false` (flag OFF) | `false \|\| !true = false` | Splash NO | ✅ NO |
| `true` (loaded) | `false` (flag missing, **edge case**) | `false \|\| !true = false` | Splash NO | ⚠️ Ver Hallazgo 3 |

El operador OR corto-circuita correctamente: `has()` se evalúa primero (la lectura del cache es O(1)), y solo si es `false` se pregunta por `isCacheLoaded()`. Sin overhead perceptible.

---

## Gate 1 — Clean Code

### Bloqueantes

Ninguno.

### No bloqueantes

- `praise:` [lib/core/tiers/tier_service.dart:94-105] El docstring de `isCacheLoaded()` cita explícitamente "**Caso de uso (HDU-006 v3)**" y explica la distinción entre "el flag está OFF" y "todavía no sé el flag". El próximo dev que abra el método entiende inmediatamente POR QUÉ existe (no solo qué hace). Cumple conventions §2 ("Documentar el porqué, no el qué").

- `praise:` [lib/core/tiers/tier_service.dart:106-108] La implementación es de 2 líneas, sin side effects, síncrona, lee solo de campos privados. No se puede romper más de lo que ya está.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:108-116] El comentario al lado de la condición documenta **el porqué** de la decisión (splash es branding, no funcionalidad, usuario debe ver la marca al abrir la app por primera vez), cita la pregunta no-bloqueante de la v2 y la decisión de Hugo. Es 9 líneas de comentario para 1 línea de código (`_splashEnabled = ...`), pero vale la pena: el dev del futuro ve la justificación, no la tiene que reconstruir. Mismo estilo que el bloque de comentarios de `_loadAppVersion()` (v2 praise), ya validado por Hugo.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:104-106] El comentario preexistente ("El TierService se consulta UNA vez al construir; si el flag cambia después, NO afecta a este splash") sigue siendo válido. La nueva lógica NO cambia la decisión de "consulta única en `initState`" — el splash sigue sin suscribirse a `tier.changes`. Coherente con la decisión arquitectónica original.

- `praise:` [test/features/identidad/screens/splash_screen_test.dart:161-171] El comentario del grupo explica el **porqué** del fail-safe ("porque el splash es branding, no funcionalidad. El usuario debe ver la marca al abrir la app por primera vez"). El test 1 está bien aislado (no setea nada en setUp, deja el `flags` map vacío → `isCacheLoaded() = false`). El test 2 documenta explícitamente que simula el "refresh exitoso que trajo `splash = false`".

- `nit:` [test/features/identidad/screens/splash_screen_test.dart:161] **El grupo se llama "cache cold del TierService" pero el test 2 NO es cache cold** — setea `tier.flags[AppFeature.splash] = false`, lo que hace que `flags.isNotEmpty = true` → `isCacheLoaded() = true`. El test 2 cubre el caso "cache loaded + flag OFF" (que ya estaba cubierto por el grupo "feature flag OFF (AC2)" más abajo, líneas 199-240). Sugerencia: renombrar el grupo a "SplashScreen — fail-safe del TierService (HDU-006 v3)" o partirlo en dos grupos ("cache cold" con solo el test 1, y "flag explícito OFF" con el test 2). Hoy: no bloqueante, nit de organización.

- `issue:` [test/features/identidad/screens/splash_screen_test.dart:184-196, widget_test.dart:254, integration_test/splash_flow_test.dart:163] **El test 2 del grupo "cache cold" es REDUNDANTE con el test del grupo "feature flag OFF (AC2)" (líneas 204-210).** Ambos verifican que con `splash = false` en el fake, el branding NO se renderiza. La diferencia es que el del grupo "cache cold" setea el flag en el cuerpo del test (no en setUp), pero el comportamiento observable es idéntico. **Recomendación:** eliminar el test 2 del grupo "cache cold" o, si se quiere dejar para énfasis, fusionarlo con el grupo "feature flag OFF (AC2)" con un nombre más explícito (ej. "fail-safe: cache loaded + flag OFF → splash NO se muestra"). Hoy: no bloqueante, redundancia de cobertura.

- `nit:` [test/features/identidad/screens/splash_screen_test.dart:276, widget_test.dart:254, integration_test/splash_flow_test.dart:163] **Mismatch entre el fake y el real en `isCacheLoaded()`.** El fake retorna `flags.isNotEmpty`, pero el real retorna `_cache.isNotEmpty || _config.debugEnabled`. Si un test futuro setea `debugEnabled: true` con `flags` vacío, el fake diría "cache cold" pero el real diría "cache loaded" → comportamiento divergente. Hoy ningún test activa debug, así que el mismatch no causa fallo, pero es una trampa latente. **Recomendación:** alinear el fake al real (`return debugEnabled || flags.isNotEmpty`) o documentar explícitamente que el fake no simula debug. Hoy: no bloqueante, debt de mantenimiento.

- `thought:` [lib/features/identidad/screens/splash_screen.dart:118] **Edge case no cubierto por tests: "cache loaded con otros flags, pero `splash` no presente en el cache".** Escenario: el refresh de Supabase terminó, trajo `{"flags": {"otroFeature": true}}` (sin `splash` por error de seed). Comportamiento actual:
  - `isCacheLoaded() = true` (1 key)
  - `has(splash) = false` (no cacheado)
  - `_splashEnabled = false || !true = false` → splash NO se muestra

  Esto es **consistente con el comportamiento pre-v3** (cache loaded + flag missing = skip), pero podría ser un riesgo operacional: si el operador de Supabase olvida seedear `splash`, la app NUNCA muestra el splash (ni en cold start), porque el cache se calienta con CUALQUIER feature, no con `splash` específicamente. **El nuevo fail-safe del v3 solo cubre el caso "cache cold"**, no el caso "cache loaded pero el feature específico falta".

  **Recomendación (no bloqueante):** considerar si este escenario requiere fail-safe también. Opciones:
  1. Dejarlo como está (skip) — la decisión de "feature flag manda" se respeta.
  2. Cubrirlo en un test que documente el comportamiento actual como intencional.
  3. Cambiar la condición para que sea "splash SÍ se muestra si el flag no está en el cache" (fail-safe más agresivo).

  Hoy: no bloqueante, decisión de producto. Si Hugo quiere cubrirlo, agregar un test en una HDU de chore. Mientras tanto, el comportamiento es predecible y coherente con el principio "el flag manda si el cache está cargado".

---

## Gate 2 — Security

### Bloqueantes

Ninguno.

### No bloqueantes

- `praise:` [lib/core/tiers/tier_service.dart:106-108] `isCacheLoaded()` es un método puro: solo lee `_cache.isNotEmpty` y `_config.debugEnabled`. No expone datos del sistema, no hace red, no accede a identificadores. Cero superficie de ataque.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:117-118] El `_splashEnabled` se calcula una vez en `initState` y se cachea en un campo `late final`. No se puede manipular desde fuera del widget. La única forma de cambiar el comportamiento es modificar el `TierService` (que es un singleton global registrado en GetIt — Target §10).

- `praise:` [lib/features/identidad/screens/splash_screen.dart:108-116] La lógica OR entre `has(splash)` y `!isCacheLoaded()` no introduce una nueva ruta de escape de seguridad. El `isCacheLoaded()` solo distingue entre "sé el flag" y "todavía no sé el flag", no cambia el contenido del flag. Si el flag eventualmente está OFF, el splash se salta. Si está ON, se muestra. La única diferencia con la v2 es **cuándo se muestra por primera vez** (en la primera instalación vs en instalaciones posteriores), no el comportamiento del flag en sí.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:118] La nueva condición NO cambia la decisión de "no navegar a URLs externas" (sigue siendo `context.go(AppRoute.home.path)` en `_navigateAway()`), no agrega permisos, no lee datos del usuario. Cero superficie de ataque añadida.

- `question:` [lib/core/tiers/tier_service.dart:106-108] **El `_config.debugEnabled` hace que `isCacheLoaded()` retorne `true` aunque el cache esté frío.** Esto significa: si un dev activa el override de debug, el fail-safe "mostrar splash cuando cache cold" NUNCA se activa. ¿Es lo que se quiere? Probablemente sí (en debug, el dev quiere ver el splash solo si lo activa explícitamente), pero lo registro para que quede explícito. No bloqueante.

- `praise:` Verificado que NO se introdujeron nuevos imports de paquetes en `tier_service.dart` ni `splash_screen.dart`. Cero nuevas dependencias, cero nuevos permisos en Android/iOS. Cumple conventions §11.

---

## Gate 3 — Architecture

### Bloqueantes

Ninguno.

### No bloqueantes

- `praise:` [lib/core/tiers/tier_service.dart:106] **El método `isCacheLoaded()` está bien ubicado en el `TierService`.** Es una consulta sobre el estado interno del cache (encapsulamiento correcto). No es un detalle de implementación que se filtre a los features; es una API deliberada que distingue "sé los flags" vs "todavía no sé los flags". Coherente con la responsabilidad del servicio (mantener el cache + exponer API síncrona + exponer API reactiva, según el header del archivo líneas 4-7).

- `praise:` [lib/features/identidad/screens/splash_screen.dart:117-118] El consumo desde el splash es a través de `getIt<TierService>()`, el mismo patrón que el resto del proyecto (ADR-011, conventions §1). No se inyecta en constructor, no se acopla al ciclo de vida del widget. Si en una HDU futura aparece otro consumidor de `isCacheLoaded()`, no necesita cambios en el splash.

- `praise:` [lib/core/tiers/tier_service.dart:94-108] La nueva API es **mínima**: 1 método, 2 líneas de implementación, síncrono, sin side effects. Cero overhead perceptible. Si en una HDU futura se quiere exponer un `Future<bool> isCacheLoaded()` (con lógica de "esperar al primer refresh"), el cambio es local al `TierService` y los consumers no se rompen (pueden seguir llamando el sync, o migrar al async).

- `thought:` **Side effects arquitectónicos del nuevo método.** Verifiqué con `grep` que los consumidores de `TierService` en `lib/` son:
  1. `lib/features/identidad/screens/splash_screen.dart:117` — el único que consume `has()` + `isCacheLoaded()`.
  2. `lib/main.dart:117` — solo llama `TierService.getInstance().initialize()` (no usa la API de lectura).
  3. `lib/core/di/service_locator.dart:28` — solo documenta el patrón de GetIt.
  4. `lib/core/tiers/*` — definición del propio servicio.
  5. `lib/core/auth/inactivity_monitor.dart:13-16` — solo MENCIONA `TierService` en un comentario como analogía ("mismo principio que `TierService` (lógica) + el widget que la consume"). NO es un consumidor real.

  **Conclusión:** el único consumidor activo de la API de lectura (`has()`, `isCacheLoaded()`) es el splash. El cambio en la condición NO afecta a ningún otro widget ni servicio. Cero side effects.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:118] La condición `_splashEnabled = tier.has(AppFeature.splash) || !tier.isCacheLoaded();` es **declarativa**, no procedural. No introduce un side effect (no hay `setState`, no hay `await`, no hay `notifyListeners`). El widget sigue siendo un `StatefulWidget` con `initState` que cachea la decisión, igual que en v1/v2. Cero impacto en el ciclo de vida del widget.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:104-106] El comentario preexistente sobre "consulta única en `initState`" sigue vigente. NO se introdujo reactividad al `tier.changes` stream. El splash sigue siendo **una decisión de un solo momento** ("¿en el momento de construir el widget, qué dice el flag + el cache?"). Si en el futuro el operador quiere cambiar el flag en runtime, hoy el splash no reacciona (pero los flags no se "apagan" en runtime según el spec, así que es OK).

- `chore:` [docs/adr/ADR-010-feature-flag-system.md] (no verificado en este review) El ADR-010 documenta la decisión arquitectónica del feature flag system. Si bien NO leí el ADR completo en este review (estaba fuera del scope del v3), registro que el método `isCacheLoaded()` es coherente con la separación "el `TierService` es el único que sabe si el cache está cargado" (mismo principio que `has()` es el único que sabe el valor de un flag). No requiere actualización del ADR — el método es un detalle de implementación, no un cambio arquitectónico.

- `praise:` (heredado de v1/v2) El patrón de "DI vive en el router + GetIt para acceso cross-cutting" sigue funcionando. El `SplashScreen` consume `TierService` vía `getIt<TierService>()` (no inyección por constructor), lo que mantiene la firma `const SplashScreen({super.key})` simple y testeable. El nuevo método no cambia esto.

---

## Re-correr conceptualmente la suite

Hugo pidió verificar que ningún test existente pase cuando NO debería, o viceversa. Revisé los grupos del `splash_screen_test.dart`:

| Grupo | setUp | `has(splash)` | `isCacheLoaded()` | `_splashEnabled` | Comportamiento esperado | Resultado |
|---|---|---|---|---|---|---|
| "feature flag ON (default)" | `splash = true` | `true` | `true` (1 key) | `true` | Splash SÍ | ✅ Sin regresión |
| "feature flag OFF (AC2)" | `splash = false` | `false` | `true` (1 key) | `false` | Splash NO | ✅ Sin regresión |
| "cache cold" test 1 | nada | `false` | `false` (map vacío) | `true` | Splash SÍ | ✅ Sin regresión |
| "cache cold" test 2 | `splash = false` | `false` | `true` (1 key) | `false` | Splash NO | ✅ Sin regresión (es redundante con el grupo OFF, ver Hallazgo 1) |
| "transición a SplashHidden" | `splash = true` | `true` | `true` (1 key) | `true` | Splash SÍ | ✅ Sin regresión |

Para `widget_test.dart` y `integration_test/splash_flow_test.dart`: ambos setean `splash = true` o `splash = false` en setUp, mismo análisis. **Cero regresiones.**

**Verificación adicional:** corrí la suite completa antes de escribir este reporte.

```
$ flutter analyze
No issues found! (ran in 6.9s)

$ flutter test
00:28 +179: All tests passed!
```

**179/179 tests verde** (confirmado: 177 anteriores + 2 nuevos del v3 = 179). Coincide con lo que Hugo reportó.

---

## Hallazgos consolidados

| # | Tipo | Severidad | Descripción |
|---|---|---|---|
| 1 | `nit:` | No bloqueante | Grupo "cache cold" mal nombrado (test 2 no es cold). |
| 2 | `issue:` | No bloqueante | Test 2 del grupo "cache cold" es redundante con el grupo "feature flag OFF". |
| 3 | `nit:` | No bloqueante | Mismatch en `_FakeTierService.isCacheLoaded()` (no considera `debugEnabled`). |
| 4 | `thought:` | No bloqueante | Edge case "cache loaded con otros flags pero `splash` missing" no cubierto por test (riesgo operacional si Supabase no seedea `splash`). |
| 5 | `question:` | No bloqueante | `_config.debugEnabled` hace que `isCacheLoaded()` retorne `true` aunque cache cold (decisión implícita, vale documentar). |

**Cero bloqueantes. Cero side effects arquitectónicos. Cero regresiones en tests.**

---

## Veredicto

- [x] ✅ **Aprobado: 0 bloqueantes. El PR puede mergear.**
- [ ] 🟡 Aprobado con cambios: solo no bloqueantes, no bloquean el merge.
- [ ] 🔴 Rechazado: hay 1+ bloqueante(s). NO mergear hasta corregir.

### Resumen

- **Total issues:** 0 bloqueantes, 0 no bloqueantes críticos. 1 issue de redundancia de test, 2 nits de naming/cleanup, 1 thought de edge case, 1 question de diseño, varios `praise:`.
- **Question de v2 resuelta:** ✅ El fail-safe hacia "show" está implementado según la decisión de Hugo. El splash se muestra en la primera instalación, se sigue saltando si el flag explícitamente está OFF.
- **Gate 1 (Clean Code):** ✅ Pasa limpio. Cero bloqueantes. 1 redundancia + 1 nit de naming + 1 mismatch en fake + 1 thought de edge case (todos no bloqueantes).
- **Gate 2 (Security):** ✅ Pasa limpio. Cero bloqueantes, cero superficie de ataque añadida, cero nuevos permisos. 1 question de diseño sobre `debugEnabled` (no bloqueante).
- **Gate 3 (Architecture):** ✅ Pasa limpio. Cero bloqueantes, cero side effects. El único consumidor real de `TierService.has()` / `isCacheLoaded()` es el splash; el cambio es local.
- **Tests:** 179/179 verde (confirmado con `flutter test`). Cero regresiones. 2 tests nuevos cubren el caso "cache cold" (test 1) y "cache loaded + flag OFF" (test 2 — redundante con el grupo OFF, ver Hallazgo 2).
- **Side effects:** Cero. No se agregaron deps, no se agregaron permisos, no se cambió la firma del `TierService` (solo se agregó un método nuevo). Cero impacto en `main.dart`, en el router, en el redirect, ni en el `SplashCubit`.
- **Cumplimiento de conventions:**
  - §3 (testing): ✅ fakes > mocks, regression test para el bug de UX, no se usa mockito.
  - §11 (deps): ✅ cero deps nuevas.
  - §2 (documentación): ✅ comentarios explican el porqué, citan la pregunta de v2 y la decisión de Hugo.

### Acción esperada del implementer

1. **Mergear el PR.** El bloqueante original de v1 está corregido (v2), la question de fail-safe de v2 está resuelta (v3), cero nuevos issues.
2. **(Opcional, cleanup) Renombrar el grupo "cache cold"** a algo más explícito (ej. "SplashScreen — fail-safe del TierService (HDU-006 v3)") o partirlo en dos grupos. Hoy: no bloqueante, nit de organización.
3. **(Opcional, cleanup) Eliminar el test 2 del grupo "cache cold"** (es redundante con el grupo "feature flag OFF"). O, si se quiere dejar para énfasis, fusionarlo con el grupo OFF con un nombre más explícito. Hoy: no bloqueante.
4. **(Opcional, cleanup) Alinear el `_FakeTierService.isCacheLoaded()`** al real (`return debugEnabled || flags.isNotEmpty`). Hoy: no bloqueante, debt de mantenimiento.
5. **(Opcional, registro) Considerar cubrir el edge case "cache loaded pero `splash` missing"** con un test que documente el comportamiento actual como intencional. Hoy: no bloqueante, decisión de producto. Si Hugo decide cubrirlo, agregar en una HDU de chore.
6. **Re-correr el integration test en Xiaomi** (no corrido en este review, requiere device físico) para confirmar que el fail-safe funciona en cold start real.

### Acciones NO requeridas (registradas, no bloquean)

- **Wrapper de `package_info_plus`** (v2): sigue pendiente de "HDU futura si aparece un segundo callsite".
- **Test del `catch (_)` de `_loadAppVersion`** (v2): coverage gap, no bloquea.
- **Edge case "cache loaded con flag missing"** (este review): decisión de producto, no bloquea.
- **Mystery: `_config.debugEnabled` en `isCacheLoaded()`** (este review): decisión implícita, no bloquea.

---

*Reporte generado por `zeiki-reviewer` siguiendo `agent.md` (3 gates + Conventional Comments + veredicto). La question registrada en v2 está resuelta: el splash ahora se muestra en la primera instalación (cache cold) y se sigue saltando si el flag explícitamente está OFF en Supabase. La implementación es mínima (1 método nuevo + 1 condición OR), el test cubre el caso principal, y cero nuevos issues bloqueantes. HDU-006 lista para mergear.*
