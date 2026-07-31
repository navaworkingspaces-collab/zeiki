# HDU-006 — Code Review

**Rama:** `feat/hdu-006-splash-nuevo`
**Spec:** `specs/HDU-006-splash-nuevo.md`
**Diff revisado:** 10 commits (3cd06ec → 1bafbf1), 15 archivos, +2030/-91 líneas
**Reviewer:** zeiki-reviewer (3 gates: clean code + security + architecture)
**Auditor de minimalismo:** ya pasó con "Limpio con notas" (2 fixes cosméticos aplicados: `Transform.translate` muerto + caracteres chinos en comentario). Este reporte NO cubre minimalismo, redundancias ni scope creep.
**Fecha:** 2026-07-31

---

## 🔴 Bloqueante encontrado

Antes de los 3 gates, **1 issue bloqueante** que invalida el AC8 en producción:

### `issue:` [lib/features/identidad/screens/splash_screen.dart:237] El `rootBundle.loadString('pubspec.yaml')` fallará en producción — la versión del footer siempre será "v?"

**Evidencia:**
- `pubspec.yaml` líneas 89-91 declara los assets:
  ```yaml
  assets:
    - assets/.env.example
    - assets/.env
  ```
- `pubspec.yaml` **NO está en la sección `flutter.assets:`**.
- `lib/features/identidad/screens/splash_screen.dart:237`:
  ```dart
  final raw = await rootBundle.loadString('pubspec.yaml');
  ```
- El bloque `catch (_)` en `splash_screen.dart:242-245` se traga la excepción silenciosamente y deja `_appVersion` en `null`.
- El footer en `splash_screen.dart:394` muestra `'v?'` como fallback (`_appVersion != null ? 'v$_appVersion' : 'v?'`).
- **Resultado en producción (APK):** el footer SIEMPRE dirá `v? · Developed by Zeiki Team` porque Flutter no bundlea `pubspec.yaml` como asset (confirmado en docs oficiales de Flutter: "Your asset hasn't been properly declared in your `pubspec.yaml` file" → `Unable to load asset`).

**Por qué el test no lo detecta:** `splash_screen_test.dart:112-115` usa `find.textContaining('Developed by Zeiki Team')`. El match pasa tanto con `"v0.1.0+1 · Developed by Zeiki Team"` como con `"v? · Developed by Zeiki Team"`. El test no verifica que la versión sea la real.

**Impacto en ACs:**
- **AC8** (footer muestra `v{version}`): **NO se cumple en producción.** La versión es "v?" siempre.
- El build APK compila (Flutter no valida referencias a assets en compile time).
- Solo se descubre en runtime cuando el usuario abre la app.

**Opciones de fix (rankeadas):**
1. **`PlatformDispatcher.instance.applicationVersion`** (recomendada) — built-in de Flutter, sin dep extra, devuelve el `versionName` de Android / `CFBundleShortVersionString` de iOS. Es exactamente lo que `package_info_plus` hace internamente. 1 línea de cambio.
2. `package_info_plus` — funciona, pero agrega una dep (justamente lo que se quería evitar).
3. Agregar `pubspec.yaml` a `flutter.assets:` — funciona, pero bundlea un archivo de config de 1.5KB que no debería estar en el APK.
4. Inyectar la versión en build time con `--dart-define` o un script de generación — más complejo, no aporta valor vs opción 1.

**Acción:** corregir antes del merge. Sugiero opción 1 (más simple, sin dep extra, semánticamente correcto).

---

## Gate 1 — Clean Code

### Bloqueantes

Ver el **`issue:` de pubspec.yaml arriba** (sección "Bloqueante encontrado"). Es el único bloqueante de este gate.

### No bloqueantes

- `nit:` [lib/features/identidad/screens/splash_screen.dart:121-159] Los intervalos de las 6 animaciones (0.0, 0.6, 0.3, 0.8, 0.4, 1.0) están inline en los `Tween`s. Coinciden con los del legacy (HDU-EXPLORE-001 tabla B4) y el spec los pide iguales, así que es intencional. Si el día de mañana se quiere ajustar la animación, se tienen que tocar 6 lugares. Considerar extraer a `const _AnimationTimings` si crece. Hoy: no bloqueante.

- `nit:` [lib/features/identidad/blocs/splash_cubit.dart:80-106] El `Stream<double> animationProgress` + `setAnimationProgress` están expuestos pero **el widget nunca escribe al stream** (solo usa `addStatusListener` para transiciones de estado). El stream es útil solo para tests. Funciona, pero si no se va a usar en producción, considerar documentarlo como "API de testing" o quitarlo. No bloqueante.

- `praise:` [lib/features/identidad/blocs/splash_cubit.dart:108-114] El `close()` es idempotente (chequea `isClosed` antes de cerrar). Lección de HDU-003/005b bien aplicada. `setAnimationProgress` también es no-op post-close. Excelente defensa contra race conditions de dispose.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:200-212] Los `_onEntryStatusChanged` y `_onFadeOutStatusChanged` filtran por `AnimationStatus.completed` (no `dismissed`) y tienen guard `if (!mounted) return;` antes de tocar el Cubit. Defensa correcta contra el ciclo `forward() → reverse()` que emite `dismissed`.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:225-233] El `_navigated` flag previene re-entry incluso si el listener se dispara múltiples veces. Combinado con el guard del Cubit (`markHidden` no re-emite si ya está en `SplashHidden`) y el `listenWhen: prev != curr` del `BlocListener`, es defensa en profundidad de 3 capas. Bien hecho.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:191-198] `dispose()` remueve los status listeners **antes** de disposar los controllers. Orden correcto (primero des-suscribir, luego disponer la fuente).

- `praise:` [lib/features/identidad/screens/splash_screen.dart:235-246] El `catch (_)` de `_loadAppVersion` no loguea nada (intencional, para no spammear logs en release). Junto con el `if (mounted)` antes del `setState`, no crashea si se completa después del dispose. Bien.

- `chore:` [lib/features/identidad/screens/splash_screen.dart:107-108] El comentario "El TierService se consulta UNA vez al construir; si el flag cambia después, NO afecta a este splash" documenta la decisión de no suscribirse a `tier.changes`. Es correcto (los flags no se "apagan" en runtime), pero si en el futuro se quiere reactividad, hay que recordar este punto. Pre-existente, fuera de scope de esta HDU.

- `chore:` [test/features/identidad/screens/splash_screen_test.dart:204-224] `_FakeTierService`, `_FakeAuthService`, `_FakeBiometricService` están duplicados en `splash_screen_test.dart`, `widget_test.dart`, `integration_test/splash_flow_test.dart`, `redirect_test.dart`, `login_screen_test.dart`, `app_router_test.dart`. La duplicación de fakes es **pre-existente** (ya estaba en HDUs anteriores) y fue cubierta por el auditor. NO la marco como issue. Si en una HDU futura se quiere extraer a `test/helpers/`, sale como chore.

---

## Gate 2 — Security

### Bloqueantes

Ninguno.

### No bloqueantes

- `praise:` [lib/features/identidad/screens/splash_screen.dart:235-246] El `catch (_)` no loguea nada del error (ni el path, ni el contenido). Si la lectura falla, no se filtra información del sistema de archivos. Cumple conventions §6 ("Sin logs de información sensible").

- `praise:` [lib/features/identidad/screens/splash_screen.dart:237] El path `'pubspec.yaml'` es hardcoded. Sin input del usuario → sin riesgo de path traversal o inyección. (Aunque el load va a fallar por el issue del Gate 1, el riesgo de seguridad del path en sí es cero.)

- `praise:` [lib/features/identidad/screens/splash_screen.dart:104-108] El feature flag se consulta vía `getIt<TierService>().has(AppFeature.splash)`. El `TierService.has()` es síncrono y consulta el cache local (Target §10, HDU-003). No hay forma de que código malicioso en el cliente "engañe" al splash para mostrar branding: el flag es de solo lectura desde el cache. Si el atacante modifica el cache en memoria, el daño es local (puede mostrar el splash, pero no roba datos del usuario).

- `praise:` [lib/features/identidad/screens/splash_screen.dart:225-233] La única navegación es `context.go(AppRoute.home.path)`. No se navega a URLs externas, no se leen parámetros del usuario para construir la ruta. Sin superficie de ataque de URL.

- `praise:` [android/app/src/main/AndroidManifest.xml] NO se agregaron permisos nuevos. El splash es puramente UI — no necesita red, ni archivos, ni biometría. El `USE_BIOMETRIC` y `USE_FINGERPRINT` son pre-existentes de HDU-005b.

- `question:` [lib/features/identidad/screens/splash_screen.dart:104-108] **Comportamiento fail-safe del feature flag.** Cuando la red está caída y el cache del `TierService` está vacío, `TierService.has()` devuelve `false` (documentado en `tier_service.dart:99-109`). Esto significa que el splash se salta y el usuario va directo al redirect. **El comportamiento actual es: "si no puedo leer el flag, no muestro el splash"** (fail-safe hacia "skip"). Tu comentario en el brief decía "probablemente: mostrar el splash igual" (fail-safe hacia "show"). Ambos son válidos, pero diferentes. El spec (línea 105 del spec) dice "Si el flag está OFF → no se renderiza", y el fail-safe de `TierService` es OFF por default. Es **consistente con el spec**, pero quiero confirmar que esto es lo que quieres antes de mergear. Si prefieres "mostrar el splash cuando no se puede leer el flag" (fail-safe hacia "show"), hay que cambiar la lectura a algo como: si el cache está frío y el flag no se ha podido refrescar, mostrar el splash igual. Esto requiere un test que cubra el caso "red caída". Hoy no hay tal test → gate fail-safe no validado. **No bloqueante**, pero decisión de producto.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:183-187] El `addPostFrameCallback` + guard `if (mounted)` para el caso "flag OFF" evita el warning de Flutter sobre navegar durante el build. Patrón correcto.

- `chore:` [docs/runbooks/splash-feature-flag.md:124-144] El runbook documenta el troubleshooting de "splash no se muestra" y "splash se muestra aunque flag OFF". El segundo escenario menciona que la causa es el cache del `TierService` en memoria. Correcto, pero **no menciona el caso "red caída en cold start"** (que con el comportamiento actual hace que el splash se salte). Si la decisión de producto es "skip cuando no se puede leer el flag", agregar al runbook. Si es "show cuando no se puede leer", cambiar la implementación Y el runbook.

---

## Gate 3 — Architecture

### Bloqueantes

Ninguno.

### No bloqueantes

- `chore:` [docs/adr/ADR-012-router-location-and-getit.md:125] **El comando de verificación del ADR-012 está desactualizado.** El ADR dice:
  > "**Verificación:** `grep -r "import.*features" lib/core/` debe devolver SOLO los 3 imports del router."

  Hoy devuelve **5 imports** (verificado):
  - `app_router.dart:49` → `splash_cubit.dart` (nuevo en HDU-006)
  - `app_router.dart:50` → `home_screen.dart`
  - `app_router.dart:51` → `login_screen.dart`
  - `app_router.dart:52` → `register_screen.dart`
  - `app_router.dart:53` → `splash_screen.dart` (nuevo en HDU-006)
  - `app_router.dart:54` → `unlock_screen.dart`

  El ADR explícitamente dice (§"Cuándo NO se revisa"): "Cambios en las pantallas reales (migración de placeholders a reales, en futuras HDUs). La excepción cubre **cualquier** pantalla real que el router importe, no solo las actuales." → la excepción cubre los nuevos imports, **NO requiere un ADR nuevo**. Pero el comando de verificación dice "3 imports" y debería decir "los imports del router, sin importar el conteo exacto" o listar los actuales. **Pre-existente, fuera de scope**, pero la HDU-006 lo deja más visible. Actualizar el comando en el ADR como chore de cleanup.

- `thought:` [lib/main.dart:127-136] El `BlocProvider<SplashCubit>` está en `main.dart` (app-level), no en el router (route-level). El comentario en `app_router.dart:147-153` dice que esto es "el patrón del resto de las features", pero la realidad es que el router también tiene un `BlocProvider<SplashCubit>.value` para los tests (líneas 154-162). **Funciona**, pero es un patrón dual:
  - **Producción:** `BlocProvider` en `main.dart` → Cubit vive para toda la app.
  - **Tests:** `BlocProvider.value` en el router (vía `splashCubit:` param) → Cubit inyectado, controlado por el test.

  Ambos paths llegan al mismo `SplashScreen`, así que funciona. Pero el comentario en `app_router.dart` es engañoso ("la lógica de DI vive en el router, no en la pantalla" — en realidad vive en `main.dart`). Sugiero en una HDU futura mover el `BlocProvider` al router (route-level) y quitar el de `main.dart`. Más simple, más local, sigue el patrón de "DI vive en el router" del comentario. No bloqueante.

- `praise:` [lib/core/router/app_router.dart:137-162] La firma `buildAppRouter({splashCubit: ...})` con `BlocProvider.value` cuando se inyecta un Cubit es exactamente el patrón que permite a los tests controlar las transiciones de estado sin `pumpAndSettle` de 2.5s. Limpio y testeable.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:214-222] La navegación está en el `BlocListener` (side effect), no en el Cubit. Cumple ADR-004 ("Side effects (navegación, snackbars) en el `listener` del `BlocConsumer`, no en el BLoC.").

- `praise:` [lib/features/identidad/blocs/splash_cubit.dart:38-66] `SplashState` es `sealed class` con 3 valores (`SplashLoading`, `SplashReady`, `SplashHidden`). El `switch` exhaustivo en el listener es seguro en compile time. Buena práctica de Dart 3.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:32-45] Cero `setState` para lógica de negocio. El único `setState` es para el `_appVersion` (UI state local). Cumple Target §14 (anti-patrón "setState para lógica de negocio").

- `praise:` [lib/features/identidad/screens/splash_screen.dart:232] La ruta se construye con `AppRoute.home.path`, no con string hardcoded. Cumple Target §14 (anti-patrón "Rutas hardcoded en widgets").

- `praise:` [lib/app/widgets/*] Los widgets de branding (`zeiki_logo.dart`, `particles_background.dart`, `expanding_rings.dart`) viven en `lib/app/widgets/`, no en `lib/core/`. Correcto: son UI de aplicación, no servicios transversales. Coherente con el path del legacy.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:10-13] El splash **NO consulta `AuthService` ni `BiometricService`**. Solo lee el feature flag. La navegación la hace el `redirect` del router. Cumple AC10 y la decisión arquitectónica del spec (§"El splash NO tiene lógica de navegación").

- `praise:` [lib/app/widgets/expanding_rings.dart, particles_background.dart] Los widgets de fondo tienen su propio `AnimationController(duration: ...s)..repeat()`. **Independientes** del controller principal del splash. No comparten estado. Se disponen en su propio `dispose()`. No hay riesgo de leak si el splash se destruye.

- `praise:` [lib/app/widgets/zeiki_logo.dart:41-105] El `shouldRepaint` retorna `false` (el logo es estático). El `CustomPainter` se crea una vez. Eficiente.

- `praise:` [pubspec.yaml] **NO se agregaron dependencias.** El footer usa regex sobre `pubspec.yaml` (cumpliendo conventions §11: "Lo resuelve el framework" / "lo resuelve el lenguaje"). La elección de NO agregar `package_info_plus` es coherente con conventions §11 (4 preguntas: ¿ya existe? sí, regex de 5 líneas). Lastima que el approach elegido no funciona (ver issue del Gate 1), pero la intención es correcta.

- `praise:` Branding — Búsqueda de "Seiki" en código de la app: solo aparece en comentarios de migración del legacy (ej. `// Migrado del legacy seiki_app@0d18d7d`), que es la convención ADR-009. **Cero ocurrencias en código activo.** Branding consistente.

---

## Veredicto

- [ ] ✅ Aprobado: 0 bloqueantes. El PR puede mergear.
- [ ] 🟡 Aprobado con cambios: solo no bloqueantes, no bloquean el merge.
- [x] 🔴 **Rechazado: hay 1 bloqueante (`pubspec.yaml` no bundleado como asset → footer siempre dice "v?"). NO mergear hasta corregirlo.**

### Resumen

- **Total issues:** 1 bloqueante, 0 no bloqueantes críticos. 8 `nit:` / `thought:` / `question:` / `chore:` / `praise:` (la mayoría praise + observaciones menores).
- **Gate 1 (Clean Code):** 🔴 **1 bloqueante** (pubspec.yaml no bundleado). Todo lo demás es praise o nit.
- **Gate 2 (Security):** ✅ Pasa limpio. Cero issues, 1 question de diseño de fail-safe (no bloqueante).
- **Gate 3 (Architecture):** ✅ Pasa limpio. Cero issues, 1 chore de ADR desactualizado (no bloqueante, pre-existente) + 1 thought de diseño (no bloqueante).
- **Fix del bloqueante:** 1 línea de cambio recomendada (`PlatformDispatcher.instance.applicationVersion`) — sin agregar deps, sin cambiar assets, sin cambiar API pública.
- **Tests del fix:** el test actual en `splash_screen_test.dart:104-120` no detecta el bug (usa `textContaining`). Después del fix, agregar un assert explícito: `expect(find.textContaining('v0.1.0+1'), findsOneWidget)` o equivalente.

### Acción esperada del implementer

1. **Aplicar el fix del pubspec.yaml** (opción 1 recomendada: `PlatformDispatcher.instance.applicationVersion`).
2. **Endurecer el test** para que falle si la versión es "v?" (assert explícito del número de versión).
3. **Re-correr la suite** + integration test en Xiaomi.
4. **Reporte a Mavis** cuando esté listo para re-review.

---

*Reporte generado por `zeiki-reviewer` siguiendo `agent.md` (3 gates + Conventional Comments + veredicto). El bug encontrado es real y reproducible: build APK OK, pero `rootBundle.loadString('pubspec.yaml')` lanza `Unable to load asset` en runtime, el catch lo traga, y el footer muestra "v?" indefinidamente.*
