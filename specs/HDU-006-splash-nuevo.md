# HDU-006 — Splash nuevo con branding + feature flag

**Tipo:** feature
**Prioridad:** alta
**Estado:** pendiente
**Fecha:** 2026-07-31
**Sistemas externos involucrados:** ninguno (todo es cliente)
**Dominio(s):** `lib/features/identidad/screens/` (pantalla real) + `lib/core/router/` (cambio de `initialLocation` por defecto a `/splash` ya está hecho)

---

## Check de entendimiento (3 líneas)

- Lo que quieres: que al abrir la app vea un splash con el logo de Zeiki que dure lo justo, y que después me mande al lugar correcto según si ya entré o no.
- Vas a saber que está bien cuando: al abrir la app vea el splash (con el logo y la marca de Zeiki), dure lo que tenga que durar (sin tiempo fijo), y me mande a `/login` (si nunca he entrado), `/home` (si ya estoy logueado) o al `UnlockScreen` (si tengo biometría y acabo de cerrar la app).
- Esto NO se va a hacer: el diseño visual final del splash, animaciones de transición elaboradas, ni cambios al `TierService` o al router más allá de lo mínimo necesario.

---

## Decisiones de producto (acordadas con Hugo el 2026-07-31)

> Esta sección documenta EL QUÉ, no el cómo. Es la fuente de verdad para los criterios de aceptación.

### Opción B para el tiempo del splash: **sin tiempo mínimo**

- El splash dura **lo que tenga que durar** (lo que tarde el redirect del router en decidir a dónde ir).
- Si la app abre rápido, el splash es casi instantáneo (< 500ms).
- Si la app abre lento, el splash dura lo que necesite, **sin un mínimo forzado**.
- **NO hay `Future.delayed`** que mantenga el splash artificialmente.
- **NO hay timeout máximo** (si la app está colgada, hay un problema de performance, no de splash).

**Analogía:** el portero del hotel no se queda un tiempo fijo en la puerta "para que se vea bien". Te saluda y te manda adentro cuando sabe a dónde ir. Si tarda 0.5s en saber, te manda rapidísimo. Si tarda 2s, te quedas 2s. Si tarda 5s, hay un problema del SISTEMA, no del portero.

### Branding: lo que se migra del legacy, lo que se descarta

**Migrado del legacy (HDU-EXPLORE-001):**

- **Paleta de colores exacta** (mismas constantes, en `lib/core/theme/`):
  - `primaryPurple` = `0xFF7c3aed`
  - `accentPurple` = `0xFFa855f7`
  - `backgroundDark` = `0xFF1a1a2e`
  - `textWhite` = `Colors.white`
- **Logo:** se queda como `CustomPaint` (mismo patrón del legacy). No se extrae a SVG en esta HDU — sale en HDU-EXPLORE futura si Hugo lo decide.
- **Animaciones de entrada** (las 6 del legacy, refactorizadas con `Tween` + `CurvedAnimation` + `AnimationController`):
  - Scale + rotation + opacity del logo (0–0.6s)
  - Slide + opacity del texto (0.3–0.8s)
  - Width del progress bar (0.6–1.0s)
- **Animaciones de fondo en loop infinito:**
  - 50 partículas púrpura flotando (loop 8s)
  - 3 anillos concéntricos expansivos (loop 3s)
- **Layout:** logo centrado + "ZEIKI" 72px bold + "LOADING" 18px + footer con versión + progress bar 300×4.
- **Textos exactos** (mismo copy):
  - "ZEIKI" en grande
  - "LOADING" como tagline
  - Footer: "v{version} · Developed by Zeiki Team" (versión dinámica, NO hardcodeada como en el legacy)

**Descartado del legacy (los bugs):**

- ❌ `Future.delayed(1.5s)` artificial — causa del "splash cortado".
- ❌ `signOut()` forzado dentro del splash — invalidaba la sesión.
- ❌ Doble `Navigator.pushReplacementNamed` — race condition.
- ❌ `getCurrentUser()` asíncrono — reemplazado por `getCurrentSession()` síncrono (ya hecho en HDU-005).
- ❌ `Navigator.pushReplacementNamed` legacy — reemplazado por `go_router` (ya hecho en HDU-004).
- ❌ "v1.0.0" hardcodeado — reemplazado por lectura de `pubspec.yaml`.
- ❌ Parámetro `withGlow` banda muerta del `ZeikiLogo` — se quita o se implementa de verdad.
- ❌ Falta de feature flag (Target §10 violation) — el splash SIEMPRE se mostraba en el legacy. En Zeiki está detrás de `AppFeature.splash` desde el día 1.

### Decisiones que YA se tomaron en HDUs anteriores (no se cuestionan)

- **Decisión de navegación post-cold-start:** la hace el `redirect` del `GoRouter` (HDU-004), NO el splash. El splash solo renderiza; el redirect lo reemplaza.
- **Biometría post-cold-start:** la pantalla `/unlock` (HDU-005b) la maneja, NO el splash.
- **Auth state:** el `AuthService` (HDU-005) la provee, NO el splash.
- **Feature flag:** el `TierService.has(AppFeature.splash)` (HDU-003) la provee. El splash está detrás del flag `AppFeature.splash` (ya declarado en el enum).

### Resoluciones explícitas

| Pregunta | Resolución |
|----------|------------|
| ¿Cuánto dura el splash? | Lo que tenga que durar (sin tiempo mínimo). |
| ¿Qué pasa si la app abre en 0.5s? | El splash es casi instantáneo. |
| ¿Qué pasa si la app abre en 5s? | El splash dura 5s. Hay un problema de performance a investigar. |
| ¿El splash decide a dónde ir? | **NO.** El redirect del `GoRouter` lo hace. |
| ¿El splash consulta biometría? | **NO.** El `UnlockScreen` lo hace (HDU-005b). |
| ¿Está detrás de feature flag? | Sí: `AppFeature.splash`. Por default OFF en `app_tier_features` (se activa por tier desde Supabase). |
| ¿Qué versión muestra el footer? | La de `pubspec.yaml` (vía `PackageInfo` o lectura directa), NO hardcodeada. |
| ¿El logo se extrae a SVG? | No en esta HDU. Sale en HDU-EXPLORE futura. |

---

## Decisiones arquitectónicas

### 1. El splash NO tiene lógica de navegación

- El splash es puramente visual. Renderiza el logo, las animaciones, el texto. Eso es todo.
- El `redirect` del `GoRouter` (construido en HDU-004, extendido en HDU-005 y HDU-005b) hace toda la decisión de a dónde ir.
- El `initialLocation` del router es `/splash`. Cuando el splash se monta, el router ejecuta el `redirect`, que decide el destino real. El splash desaparece cuando se completa la navegación.

**Por qué:** el legacy tenía 4 sitios diferentes que navegaban post-cold-start (`splash_page.dart`, `main.dart` listener, `getCurrentUser()` asíncrono, `signOut()` forzado). Esa dispersión fue la causa raíz del "splash cortado". En Zeiki, **una sola fuente de navegación** (el redirect del router) elimina el bug.

### 2. `BuildContext` navigation via `GoRouter`, no `Navigator`

- El splash usa `context.go(AppRoute.splash.path)` solo si necesita navegar a sí mismo (raro). Para el caso normal, no llama a nada de navegación.
- Si el splash necesita irse (caso edge: feature flag OFF, splash no se muestra), usa `context.go(AppRoute.login.path)` o `context.go(AppRoute.home.path)` según `TierService.has(AppFeature.splash)`.

### 3. `Bloc` para el estado del splash (no `StatefulWidget` directo)

- El splash tiene estado complejo: animaciones, sub-estados de carga, decisión de feature flag. Un `SplashBloc` (Cubit) lo encapsula.
- Sigue el patrón de `Target §3` y `ADR-004` (BLoC para state management).
- El Cubit expone: `state` con `SplashState` (loading, ready, error).

### 4. Animación de salida (fade out) antes de que el redirect navegue

- Cuando el redirect decide a dónde ir, el splash hace un fade out de 200-300ms antes de que la navegación se complete.
- Esto mejora la UX vs el legacy (que NO tenía animación de salida — la transición era abrupta).

### 5. `version` desde `pubspec.yaml`, no hardcodeada

- Se lee `pubspec.yaml` con `YamlLoader` o el `PackageInfo` package, y se inyecta en el footer.
- El footer siempre muestra la versión real, no un string fijo como en el legacy.

---

## Problema / Motivación

HDU-004 dejó el router con un placeholder de splash (`lib/core/router/screens/splash_placeholder.dart`) que solo dice "Splash" con 2 botones de prueba. No es una pantalla real, es un andamio.

HDU-005 agregó auth (register, login, home). HDU-005b agregó biometría + timer. Ahora todos los componentes del cold start están listos, pero falta la **primera impresión visual** que tiene el usuario al abrir la app: el splash.

Esta HDU es la pieza que consolida HDU-003 (feature flags), HDU-004 (router), HDU-005 (auth) y HDU-005b (biometría + timer) en una experiencia de usuario coherente. Es el momento donde todo se junta.

El reporte de HDU-EXPLORE-001 estudió el splash legacy en detalle y documentó los bugs que causaban el "splash cortado". Esta HDU migra el **feel** del legacy (paleta, logo, animaciones, layout) **sin replicar los bugs**.

---

## Criterios de aceptación

### SplashScreen (pantalla real)

- [ ] **AC1:** `lib/features/identidad/screens/splash_screen.dart` declara el widget `SplashScreen` (extiende `StatelessWidget` o `ConsumerWidget` si se usa BLoC).
- [ ] **AC2:** El splash está detrás del feature flag `AppFeature.splash`. Si `TierService.has(AppFeature.splash) == false`, la app NO muestra el splash — va directo a `/login` o `/home` (lo que el redirect decida).
- [ ] **AC3:** El splash usa la paleta exacta del legacy (en `lib/core/theme/app_theme.dart` o equivalente):
  - `primaryPurple` = `0xFF7c3aed`
  - `accentPurple` = `0xFFa855f7`
  - `backgroundDark` = `0xFF1a1a2e`
- [ ] **AC4:** El logo "Z" de Zeiki se dibuja con `CustomPaint` (mismo patrón que el legacy). Se aísla en `lib/app/widgets/zeiki_logo.dart` (mismo path que el legacy).
- [ ] **AC5:** Las animaciones de entrada (scale, rotation, opacity del logo; slide, opacity del texto; width del progress bar) se reproducen en el orden y timing del legacy. Usan `Tween` + `CurvedAnimation` + `AnimationController` puros (sin Lottie/Rive).
- [ ] **AC6:** Las animaciones de fondo (50 partículas, 3 anillos) corren en loop infinito, separadas del controller principal.
- [ ] **AC7:** El texto "ZEIKI" se renderiza en 72px bold, "LOADING" en 18px, el footer en 14px.
- [ ] **AC8:** El footer del splash muestra **"v{version} · Developed by Zeiki Team"** donde `{version}` se lee de `pubspec.yaml` dinámicamente (NO hardcodeado).
- [ ] **AC9:** El splash NO tiene `Future.delayed` que mantenga la pantalla artificialmente. Desaparece en cuanto el redirect del router navega.
- [ ] **AC10:** El splash NO consulta `AuthService` ni `BiometricService`. Esa lógica ya está en el `redirect` y en el `UnlockScreen` (HDU-005b).
- [ ] **AC11:** Cuando el splash está por desaparecer, hace un fade out de 200-300ms antes de la navegación del redirect.

### SplashBloc (Cubit)

- [ ] **AC12:** `lib/features/identidad/blocs/splash_cubit.dart` declara el `SplashCubit` que extiende `Cubit<SplashState>`. Exponer el `stream` de animaciones.
- [ ] **AC13:** `SplashState` es una clase sellada con: `loading`, `ready`, `hidden` (post-fade-out).

### Router + navegación

- [ ] **AC14:** El `initialLocation` del `GoRouter` sigue siendo `/splash` (ya está así desde HDU-004). Sin cambios.
- [ ] **AC15:** El `redirect` del router (ya existente) sigue decidiendo a dónde ir. **No se modifica** el redirect en esta HDU.
- [ ] **AC16:** Si el feature flag `AppFeature.splash` está OFF, el splash NO se monta — el `redirect` se ejecuta sin pantalla intermedia.

### Tests + pipeline + no regresión

- [ ] **AC17:** `test/features/identidad/screens/splash_screen_test.dart` cubre con widget tests: render del logo, render de los textos ("ZEIKI", "LOADING", footer con versión), animaciones se ejecutan, fade-out al cambiar a `hidden`.
- [ ] **AC18:** `test/features/identidad/blocs/splash_cubit_test.dart` cubre: estado `loading` inicial, transición a `ready`, transición a `hidden` post-fade.
- [ ] **AC19:** `test/core/router/redirect_test.dart` (ya existe) cubre el caso "feature flag OFF" (splash NO se monta).
- [ ] **AC20:** `integration_test/splash_flow_test.dart` cubre en Xiaomi: cold start con feature flag ON ve el splash, cold start con feature flag OFF NO lo ve, el redirect del router funciona correctamente en ambos casos.
- [ ] **AC21:** `flutter analyze` 0 warnings, `flutter test` 100% verde, `flutter test integration_test/` (en Xiaomi) pasa, `flutter build apk --debug` compila. Pipeline local completo.
- [ ] **AC22:** **NO regresión** (compromiso con Hugo). Todos los tests de las 6 HDUs cerradas (001-005b) siguen pasando después de esta HDU. Bloqueante si alguno falla.

### Cumplimiento del reporte de HDU-EXPLORE-001

- [ ] **AC23:** Cumplir el checklist de "patrones prohibidos" del reporte de HDU-EXPLORE-001:
  - ❌ NO doble `pushReplacement` (ni en splash, ni en main, ni en ningún lado).
  - ❌ NO `signOut()` dentro del splash.
  - ✅ `if (!mounted) return;` antes de cualquier navegación.
  - ✅ Una sola fuente de decisión post-cold-start (el redirect del router).
  - ✅ `getCurrentSession()` síncrono, nunca `getCurrentUser()` asíncrono.
- [ ] **AC24:** El splash respeta Target §10: detrás de `AppFeature.splash` desde el día 1 (NO se replica la violación del legacy).

---

## Archivos afectados

**Nuevos:**

- `lib/core/theme/app_theme.dart` — paleta de colores de Zeiki (migrada del legacy).
- `lib/app/widgets/zeiki_logo.dart` — logo "Z" con `CustomPaint` (migrado del legacy).
- `lib/app/widgets/particles_background.dart` — 50 partículas en loop (migrado del legacy).
- `lib/app/widgets/expanding_rings.dart` — 3 anillos en loop (migrado del legacy).
- `lib/features/identidad/screens/splash_screen.dart` — pantalla real del splash.
- `lib/features/identidad/blocs/splash_cubit.dart` — Cubit para el estado del splash.
- `test/features/identidad/screens/splash_screen_test.dart` — widget tests.
- `test/features/identidad/blocs/splash_cubit_test.dart` — Cubit tests.
- `integration_test/splash_flow_test.dart` — integration test del cold start con feature flag ON/OFF.
- `docs/runbooks/splash-feature-flag.md` — cómo activar/desactivar el splash via Supabase dashboard.

**Modificados:**

- `lib/core/router/app_router.dart` — la ruta `/splash` ahora renderiza `SplashScreen` (no el placeholder). El `redirect` no se modifica.
- `lib/main.dart` — pre-calentamiento del `TierService` para que el splash consulte el feature flag sin await async (mismo patrón que se usó para `AuthService` en HDU-005).
- `pubspec.yaml` — sin cambios de dependencias (todo es Flutter puro).
- `lib/core/router/screens/splash_placeholder.dart` — **eliminado** (reemplazado por la pantalla real).
- `docs/current-state.md` — actualizar cuando se mergee (cleanup).
- `.mavis/hdu.md` (local, en `.gitignore`) — registrar la HDU-006 cerrada.

**Eliminados:**

- `lib/core/router/screens/splash_placeholder.dart` — reemplazado por `SplashScreen` real.

---

## Plan técnico (pasos verificables)

1. **Crear `lib/core/theme/app_theme.dart`** — paleta exacta del legacy (`primaryPurple`, `accentPurple`, `backgroundDark`, `textWhite`).
2. **Crear `lib/app/widgets/zeiki_logo.dart`** — logo "Z" con `CustomPaint`. Migrar la geometría del legacy, quitar el parámetro `withGlow` banda muerta.
3. **Crear `lib/app/widgets/particles_background.dart`** — 50 partículas con `AnimationController(duration: 8s)..repeat()`. Migrar la lógica del legacy.
4. **Crear `lib/app/widgets/expanding_rings.dart`** — 3 anillos con `AnimationController(duration: 3s)..repeat()`. Migrar la lógica del legacy.
5. **Crear `lib/features/identidad/blocs/splash_cubit.dart`** — Cubit con `SplashState` (loading, ready, hidden).
6. **Crear `lib/features/identidad/screens/splash_screen.dart`** — `StatelessWidget` que renderiza el logo, los textos, el progress bar, las animaciones de fondo. Lee `TierService` para el feature flag. Si el flag está OFF, `context.go(AppRoute.login.path)` inmediatamente.
7. **Modificar `lib/core/router/app_router.dart`** — la ruta `/splash` ahora importa `SplashScreen` (no el placeholder).
8. **Modificar `lib/main.dart`** — pre-calentar `getIt<TierService>()` antes de `runApp` (mismo patrón que `AuthService` en HDU-005).
9. **Eliminar `lib/core/router/screens/splash_placeholder.dart`** — reemplazado por la pantalla real.
10. **Tests:**
    - `test/features/identidad/screens/splash_screen_test.dart` — widget tests del splash con `flag_on`, `flag_off`, render, animaciones.
    - `test/features/identidad/blocs/splash_cubit_test.dart` — Cubit tests.
    - `integration_test/splash_flow_test.dart` — cold start en Xiaomi.
    - Actualizar `test/core/router/redirect_test.dart` (ya existe) con el caso "feature flag OFF".
11. **Pipeline local:** `flutter analyze`, `flutter test`, `flutter test integration_test/`, `flutter build apk --debug`. Todo verde.
12. **Regression check (AC22):** correr la suite completa de HDUs 001-005b. Si alguna falla, **bloqueante** — corregir antes de reportar "listo".

---

## Notas / Decisiones explícitas

- **El logo sigue siendo `CustomPaint`**, no asset. Migrar a SVG sale en HDU-EXPLORE futura. Por ahora, mismo patrón del legacy.
- **El footer muestra la versión de `pubspec.yaml`** vía lectura directa del YAML (no usamos `package_info_plus` para no agregar dependencia). Si en el futuro se quiere versión desde remote config, se reemplaza.
- **El splash está detrás de `AppFeature.splash`** (Target §10). Por default en `app_tier_features` el flag está OFF (o solo activo para tier específico). Se activa via Supabase dashboard.
- **El splash NO tiene `Future.delayed`** artificial. La animación de salida (fade out) usa un `AnimationController` separado que se conecta al estado `hidden` del Cubit.
- **`AnimationController.addStatusListener`** en vez de `Future.delayed` — la animación de entrada se conecta a la navegación via `addStatusListener(AnimationStatus.completed)`. Esto evita el race condition entre timing y animación que tenía el legacy.
- **El `withGlow` parámetro del `ZeikiLogo` legacy es banda muerta.** En la migración, se quita el parámetro o se implementa de verdad (con `BoxShadow` en el painter). Decisión del implementer, sin blocker.
- **El listener de `onAuthStateChange` en `main.dart` NO navega** (ya arreglado en HDU-005b). El splash es la **única** fuente de UI post-cold-start, y el redirect del router es la **única** fuente de navegación.
- **El `BiometricService` no se consulta desde el splash.** El `UnlockScreen` (HDU-005b) maneja el caso de biometría activada.

---

## Fuera de scope (NO se hace en esta HDU)

- Extraer el logo a SVG (sale en HDU-EXPLORE futura).
- Diseño visual final del splash (animaciones complejas, transiciones, etc.) — se hace en HDU de diseño visual.
- Soporte de dark/light mode (decisión abierta) — el legacy siempre es dark, Zeiki también por ahora.
- "v{version}" desde remote config — se lee de `pubspec.yaml` por ahora.
- HDU-EXPLORE-009 (documentación de la causa raíz del bug del cortado) — se hace en paralelo si Hugo quiere.
- Cambios al `AuthService`, `BiometricService`, `TierService`, o al `GoRouter` redirect — **están listos** de HDUs anteriores.
- Cambios al `main.dart` más allá del pre-calentamiento del `TierService`.

---

## Riesgos

- **Riesgo bajo — el splash NO tiene tiempo mínimo.** Si el cold start es muy rápido (< 200ms), el splash casi no se ve. Esto es intencional (decisión de Hugo). Si la UX lo exige, se agrega un mínimo de 800ms en una HDU futura.
- **Riesgo bajo — el logo es `CustomPaint` y depende de coordenadas hardcodeadas.** Cambiar el branding = cambiar código. Riesgo de deuda técnica a largo plazo. Mitigación: HDU-EXPLORE futura para extraer a SVG.
- **Riesgo bajo — la animación de salida (fade out) puede no completarse** si la navegación del redirect es síncrona. Mitigación: el Cubit coordina el estado `hidden` ANTES de que el redirect navegue (espera 250ms de fade out antes de `context.go`).
- **Riesgo bajo — el listener de `onAuthStateChange` de Supabase** ya no navega (HDU-005b), pero si en el futuro se agrega navegación en otro listener, se reintroduce el bug. Mitigación: el comentario en `main.dart` documenta esta decisión.
- **Riesgo bajo — el `version` del footer** se lee de `pubspec.yaml` en cada cold start. Si el archivo cambia en runtime (no debería), se vería diferente. Mitigación: leer en `initState` del Cubit, cachear.

---

## Sistemas externos involucrados

- **Ningún sistema externo backend** (todo es cliente).
- **`pubspec.yaml`** (archivo local) — para leer la versión.
- **`Supabase app_tier_features` (tabla)** — para el feature flag (ya configurada en HDU-002/003).
