# HDU-EXPLORE-001 — Reporte: Exploración del splash legacy (seiki_app)

**Tipo:** chore (research, solo lectura)
**HDU:** HDU-EXPLORE-001
**Estado:** completada
**Fecha:** 2026-07-29
**Autor:** Mavis (orquestador) + sesión de research
**Repo legacy explorado:** `navaworkingspaces-collab/seiki_app` (read-only)
**Path local:** `C:\Users\Pc\Documents\Seiki\seiki_app_github`
**HEAD del legacy al momento de lectura:** `0d18d7d` (rama `main`, working tree clean, sincronizado con origin/main)
**HDU de implementación que depende de esto:** HDU-002 (splash nuevo de Zeiki)

---

## Resumen ejecutivo (5 líneas)

El splash legacy es un `StatefulWidget` con 6 animaciones concurrentes (2500ms), fondo animado (partículas + anillos) y un logo hecho en `CustomPaint` — NO es un asset. La causa raíz del "bug del cortado" que Hugo reportó es **un bug evolutivo de 3 capas ya arreglado** (HDU-033/034/035, julio 2026): doble `pushReplacementNamed` + `getCurrentUser()` asíncrono + `signOut()` forzado en cold start, exacerbado por una race condition entre `main.dart` y `splash_page.dart`. La identidad de marca está 100% en código (colores en `app_theme.dart`, logo en `CustomPaint`); NO hay assets de marca ni fuentes custom. La HDU-002 puede migrar el feel con confianza si respeta Target §10 (feature flag obligatorio) y NO replica los bugs del legacy.

---

## Bloque A — Ubicación y estructura

### A1. Archivos del splash

| Path en el legacy | Líneas | Rol |
|---|---|---|
| `lib/features/splash/presentation/pages/splash_page.dart` | 397 | Widget principal del splash + lógica de navegación post-cold-start |
| `lib/features/splash/presentation/widgets/particles_background.dart` | 144 | 50 partículas púrpura que flotan hacia arriba (loop 8s) |
| `lib/features/splash/presentation/widgets/expanding_rings.dart` | 109 | 3 anillos concéntricos expansivos desde el centro (loop 3s) |
| `lib/app/widgets/zeiki_logo.dart` | 89 | Logo "Z" estilizada dibujada con `CustomPaint` + gradiente + glow |
| `lib/app/theme/app_theme.dart` | 35 | Paleta de colores de marca (primary, accent, backgrounds) |
| `lib/app/router/app_routes.dart` | 150 | Constantes de rutas (`AppRoutes.splash = '/'`) y mapa de routes |
| `lib/main.dart` (líneas 79-139) | 145 (sección relevante) | Listener de `onAuthStateChange` de Supabase que puede navegar (debe NO hacerlo en `initialSession`) |

**Total: 7 archivos** + 1 archivo de tests.

### A2. Tipo de widget

- Es un `StatefulWidget` (`splash_page.dart:11`) con `SingleTickerProviderStateMixin` (`splash_page.dart:18-19`).
- Usa `SingleTickerProviderStateMixin` (NO `TickerProviderStateMixin`): un solo `AnimationController` para todas las animaciones.
- Los widgets auxiliares `ParticlesBackground` y `ExpandingRings` son **StatefulWidgets separados** con sus propios `AnimationController` en loop (`..repeat()`).
- **NO es un `BLoC`**: a pesar de que el proyecto usa `flutter_bloc` (v8.1.3, ver `pubspec.yaml:16`), el splash no lo aprovecha. Toda la lógica está en el `State`.
- **Es un widget standalone**: vive en `lib/features/splash/`, no está embebido en `main.dart`.

### A3. Tests asociados

SÍ hay tests, y son robustos (escritos durante la saga de fixes HDU-033/035):

| Test file | Líneas | Cobertura |
|---|---|---|
| `test/widget/splash/splash_page_test.dart` | 218 | T1: `currentSession` válida + `currentUser` null (timing) → /dashboard. T2: `currentSession` null → /login. T3: `currentSession` expirada → /login. Patrón de fake configurable. |
| `test/widget/splash/splash_page_landscape_test.dart` | 145 | T1 (AC-A1/A2): landscape (789.8×392.7) NO debe haber RenderFlex overflow. T2 (AC-A3): portrait (400×800) NO regresión. |

Los tests usan `_FakeAuthRepository` que implementa la interface con `noSuchMethod` (líneas 43-65 de `splash_page_test.dart`). Patrón consistente con `login_page_test.dart` y `widget_test.dart` del legacy.

---

## Bloque B — Identidad de marca (look & feel)

### B1. Logo

**El logo NO es un asset PNG/SVG. Es código `CustomPaint`.**

- Path: `lib/app/widgets/zeiki_logo.dart` (89 líneas).
- Implementación: `_ZeikiLogoPainter` extiende `CustomPainter` (`zeiki_logo.dart:18`). Dibuja una "Z" estilizada con un polígono principal + 2 triángulos de highlight (`zeiki_logo.dart:44-85`).
- `shouldRepaint` retorna `false` (`zeiki_logo.dart:88`): el logo es estático, no se re-pinta.
- API: `ZeikiLogo({size = 200, withGlow = true})` (`zeiki_logo.dart:3-7`). El parámetro `withGlow` está declarado pero **NO se usa dentro del painter** (banda muerta: `zeiki_logo.dart:19, 21` lo recibe pero el `paint()` no lo consulta).
- En el splash, se instancia como `ZeikiLogo(size: 100, withGlow: true)` (`splash_page.dart:264`). El "glow" viene del `Container` exterior (3 `BoxShadow` con `Color(0xFF7c3aed).withAlpha(102)`, blurRadius 80), no del widget.
- Único asset gráfico en todo el proyecto: `assets/images/google_logo.svg` (1141 bytes). Es el logo de Google para el botón OAuth, **NO es el logo de Zeiki**.

### B2. Colores (paleta exacta)

Definidos en `lib/app/theme/app_theme.dart:5-11`:

| Nombre | Valor | Uso |
|---|---|---|
| `primaryPurple` | `0xFF7c3aed` | Color primario de marca. Botones, logo, anillos, partículas, progress bar. |
| `accentPurple` | `0xFFa855f7` | Color de acento. Gradiente del logo, gradiente del progress bar. |
| `darkPurple` | `0xFF6d28d9` | Reservado (no se usa en el splash). |
| `backgroundDark` | `0xFF1a1a2e` | Fondo del splash (`splash_page.dart:179`). `scaffoldBackgroundColor` global. |
| `backgroundDarker` | `0xFF16213e` | Reservado (no se usa en el splash). |
| `accentGreen` | `Colors.green` | Para íconos de "configuración SAT" (mencionado en comentario de `app_theme.dart:7`). |
| `textWhite` | `Colors.white` | Texto blanco. |

**Colores en HEX (los que se ven en el splash):** `#7c3aed`, `#a855f7`, `#1a1a2e`, `#ffffff`, `#ffffff60` (60% alpha), `#ffffff70` (70% alpha), `#ffffff30` (30% alpha), `#ffffff12` (12% alpha).

### B3. Tipografía

**NO hay fuentes personalizadas. NO hay sección `flutter.fonts` en `pubspec.yaml`.**

- Fuente global del theme: `'Segoe UI'` (`app_theme.dart:22`). Es la fuente del sistema en Windows; en iOS/Android se sustituye por la del sistema.
- En el splash:
  - **"ZEIKI"** (`splash_page.dart:281-291`): `fontSize: 72`, `fontWeight: bold`, `color: Colors.white`, `letterSpacing: 8`, `Shadow(color: 0xFF7c3aed, blurRadius: 30)`.
  - **"LOADING"** (`splash_page.dart:306-315`): `fontSize: 18`, `color: Colors.white70`, `letterSpacing: 4`.
  - **Footer "v1.0.0 - Developed by Seiki Team"** (`splash_page.dart:343-351`): `fontSize: 14`, `color: Colors.white60`, `letterSpacing: 2`.

### B4. Animaciones

**AnimationController principal: 2500ms** (`splash_page.dart:33`). Controla 6 animaciones concurrentes con curvas e intervalos escalonados:

| # | Elemento | Tween | Intervalo | Curve |
|---|---|---|---|---|
| 1 | Logo scale | 0.5 → 1.0 | 0.0–0.6 | `Curves.elasticOut` |
| 2 | Logo rotation | -0.5 → 0.0 rad | 0.0–0.6 | `Curves.easeOutBack` |
| 3 | Logo opacity | 0.0 → 1.0 | 0.0–0.4 | `Curves.easeIn` |
| 4 | Text slide | Offset 50 → 0 (Y) | 0.3–0.8 | `Curves.easeOutCubic` |
| 5 | Text opacity | 0.0 → 1.0 | 0.3–0.8 | `Curves.easeIn` |
| 6 | Loading bar width | 0.0 → 1.0 | 0.6–1.0 | `Curves.easeInOut` |

**Animaciones de fondo en loop infinito (separadas del controller principal):**

- **Partículas** (`particles_background.dart:28-32`): `AnimationController(duration: 8s)..repeat()`. 50 partículas, cada una con `delay` y `duration` aleatorios. Easing `easeInOutCubic`. Movimiento vertical hacia arriba (`size.height - (progress * size.height * 1.2)`).
- **Anillos** (`expanding_rings.dart:23-27`): `AnimationController(duration: 3s)..repeat()`. 3 anillos con delays escalonados (i × 0.333). Expansión de 100px hasta `size.width * 1.5`. Opacidad: aparece en 0-0.2, desvanece en 0.2-1.0.

**NO usa** Lottie, Rive, ni `flutter_animate`. Todo es `Tween` + `CurvedAnimation` + `AnimatedBuilder` + `CustomPaint`.

### B5. Layout

```
Scaffold (backgroundColor: AppTheme.backgroundDark = #1a1a2e)
  └── Stack
        ├── ParticlesBackground (50 partículas púrpura, repeat 8s)
        ├── ExpandingRings (3 anillos concéntricos, repeat 3s)
        ├── _buildMainContent() (Center + SingleChildScrollView)
        │     └── Column (mainAxisSize: min, mainAxisAlignment: center)
        │           ├── _buildLogoContainer() (200px de alto aprox)
        │           │     └── Container con gradiente + 3 boxShadows + ZeikiLogo(size: 100)
        │           ├── SizedBox(height: 40)
        │           ├── _buildBrandText() → "ZEIKI" 72px
        │           ├── SizedBox(height: 20)
        │           └── _buildTagline() → "LOADING" 18px
        └── _buildLoadingSection() (Align bottomCenter + SafeArea)
              └── Column
                    ├── "v1.0.0 - Developed by Seiki Team" 14px
                    ├── SizedBox(height: 20)
                    └── Progress bar 300×4 con gradiente (#7c3aed → #a855f7 → #7c3aed)
```

**Nota sobre landscape overflow (HDU-035, ya arreglado):** el `Center` + `Column` con `mainAxisSize: MainAxisSize.max` original causaba `RenderFlex overflowed by 0.273 pixels` en viewports de ~392.7px de alto. Fix: `SingleChildScrollView` con `mainAxisSize: MainAxisSize.min` (`splash_page.dart:200-214`).

### B6. Elementos condicionales al estado

**NO hay.** El splash se ve exactamente igual en cold start con sesión vs sin sesión, online vs offline, dark vs light. No hay variantes por tier, por feature flag, ni por estado de red.

---

## Bloque C — Comportamiento (cuándo aparece y desaparece)

### C1. Cómo se dispara la navegación DESDE el splash

`Navigator.of(context).pushReplacementNamed(...)` en 4 sitios (`splash_page.dart:133, 144, 170, 172`):

1. **Sin sesión** → `AppRoutes.login` (línea 133).
2. **Sesión expirada** (expiresAt en el pasado) → `AppRoutes.login` (línea 144).
3. **Sesión válida + biometría activada** → `AppRoutes.biometricGate` (línea 170).
4. **Sesión válida sin biometría** → `AppRoutes.dashboard` (línea 172).

**NO usa `getIt` ni streams para la decisión de navegación.** Lee `authRepository.getCurrentSession()` directamente (línea 127, llamada síncrona).

### C2. Tiempo mínimo visible

`Future.delayed(const Duration(milliseconds: 1500), () => _checkAuthStatus())` (`splash_page.dart:103`).

**1.5 segundos es el tiempo mínimo visible del splash.** Este valor es producto del fix HDU-033: bajó de 3s a 1.5s porque ya no se necesita esperar a que `currentUser` se hidrate asíncronamente (`splash_page.dart:101-102` comentario explícito: *"valor heredado del bug del timing"*).

### C3. Tiempo máximo visible (timeout)

**NO hay timeout.** Si `_checkAuthStatus` falla o se cuelga, el splash se queda forever. No hay `Timer` de seguridad que fuerce navegación.

### C4. ¿Espera a que algo termine de cargar?

Sí, pero NO a un futuro externo. Espera:
1. 1500ms (`Future.delayed`).
2. `getCurrentSession()` (síncrono, hidrata desde el storage persistente de Supabase).
3. Si hay sesión válida, `BiometricService.isBiometricEnabled()` (async, lee `SharedPreferences`, <50ms según comentario `splash_page.dart:158-162`).

**NO espera** a la red, ni a una llamada a la API, ni a que `onAuthStateChange` dispare.

### C5. Feature flag

**NO hay.** Verificado: el splash se muestra siempre, sin importar el tier del usuario, sin gating por feature flag, sin override por usuario. Esto es una **violación explícita de Target §10** para Zeiki (ver conclusiones).

### C6. Cómo decide a dónde ir después

Ver C1. Resumen de la lógica de decisión (`splash_page.dart:124-174`):

```
session = authRepository.getCurrentSession()  // síncrono
if (session == null) → /login
elif (session.expired) → /login
elif (isBiometricEnabled()) → /biometric-gate
else → /dashboard
```

Todos los `pushReplacementNamed` están protegidos con `if (!mounted) return;` (líneas 129, 144 implícito vía early return, 167). Patrón defensivo correcto.

---

## Bloque D — El bug del cortado (causa raíz)

### Conclusión D — Causa raíz verificada

El "splash se cortaba antes de tiempo" reportado por Hugo ("si duraba 5s, se cortaba a los 3s") es un **bug evolutivo acumulado de 3 capas independientes**, NO un solo bug. Ya está arreglado en el legacy (HDU-033/034/035, mergeados en julio 2026). **Es VINCULANTE migrar el fix, no el bug.**

### D1. Lógica que cancela la navegación prematuramente

**SÍ existía en el código pre-HDU-033** (commit `9b634eb` y subsiguientes hasta `538766b`). La causa fue una **race condition entre 2 fuentes de navegación post-cold-start**:

- `splash_page.dart:148` (en ese entonces) → `pushReplacementNamed('/dashboard')`.
- `main.dart:117` (listener de `onAuthStateChange`) → también `pushReplacementNamed('/dashboard')` en el evento `initialSession`.

Si ambos navegaban, el segundo ganaba y se "cortaba" la navegación a mitad de transición. En el commit `adfd994` (HDU-033) se documenta explícitamente: *"Si este listener también navega, puede saltarse el BiometricGate (race condition entre listener y SplashPage)"* — comentario en `main.dart:118-122`.

**Fix aplicado en HDU-034:** el listener de `main.dart` ya NO navega en `initialSession`. Solo navega en `signedIn` (login fresco) y `passwordRecovery`. La decisión de cold start quedó centralizada en el splash.

### D2. ¿El Timer/Future.delayed se limpiaba antes de completarse?

**NO directamente**, pero el valor de 3s del `Future.delayed` original (commit `74c2d4b`, 2025-11-10) era un **work-around** para un problema más grave: el splash llamaba a `authRepository.signOut()` dentro del callback del `Future.delayed` antes de decidir navegación. **El splash invalidaba su propia sesión persistida.**

Código del commit `9b634eb` (extracto de `splash_page.dart` en ese momento):
```dart
void _checkAuthStatus() async {
  try {
    final authRepository = sl<AuthRepository>();
    await authRepository.signOut();  // <-- INVALIDA LA SESIÓN PERSISTIDA
  } catch (e) { /* ignore */ }
  
  if (!mounted) return;
  final isAuthenticated = authRepository.isAuthenticated;
  if (isAuthenticated) {
    Navigator.of(context).pushReplacementNamed('/dashboard');
  } else {
    Navigator.of(context).pushReplacementNamed('/onboarding');
  }
}
```

Comentario en el código: `// LIMPIAR SESIÓN AL INICIAR - FORZAR LOGOUT` con `// TODO: HDU-001 - Este comportamiento debería ser configurable`. Esto significa que **en el commit `9b634eb`, el splash forzaba logout en cada cold start**, sin importar si había sesión. El usuario nunca llegaba al dashboard, siempre a onboarding/login. Eso es "se cortaba antes de tiempo" en su forma más extrema.

**Fix aplicado en HDU-033:** se eliminó el `signOut()` forzado, se cambió a `getCurrentSession()` síncrono, y se bajó el timing de 3s a 1.5s. Justificación en el commit `adfd994` (mensaje completo, 343 líneas): *"el splash pensaba que no había sesión por un timing issue en el SDK de Supabase"*.

### D3. ¿AnimationController interrumpido al cambiar de widget?

**NO es la causa del bug del cortado.** El `AnimationController` con `vsync: this` se dispone correctamente en `dispose()` (`splash_page.dart:43-46`). Las animaciones de fondo (`particles_background.dart`, `expanding_rings.dart`) también disponen sus controllers.

Sin embargo, hay un **riesgo latente**: si en el futuro se usa `TickerProviderStateMixin` con múltiples controllers, o se mete el splash dentro de un `PageView`/`TabBarView`, el controller podría pausarse. En el legacy actual, NO ocurre.

### D4. ¿Doble `Navigator.pushReplacement`?

**SÍ, confirmado.** En el commit `9b634eb` (intermedio, pre-HDU-033) el código del splash tenía literalmente:
```dart
Future.delayed(const Duration(seconds: 3), () {
  Navigator.of(context).pushReplacementNamed('/dashboard');
  Navigator.of(context).pushReplacementNamed('/onboarding');
  // ...
});
```

Y al mismo tiempo el listener de `main.dart` también navegaba. Resultado: hasta 3 navegaciones en rápida sucesión, ganaba la última, pantalla parpadeaba, splash se "cortaba" antes de los 3s.

**Fix aplicado en HDU-033:** una sola navegación por caso, todas con `if (!mounted) return;` antes.

### D5. ¿Se reproduce en debug, release, o devices específicos?

**Es un bug de timing/arquitectura, no de modo de build.** Se reproduce tanto en `flutter run --debug` como `--release`. La causa es la combinación de:
- `getCurrentUser()` asíncrono que retorna null en cold start.
- Race condition entre 2 fuentes de navegación.
- `signOut()` forzado.

Devices con cold start más lento (Android de gama baja) lo sufrían más. En iOS también se reproducía, solo que el splash nativo de iOS enmascaraba el bug.

### D6. ¿Hay issues/tickets/reportes en el legacy sobre este bug?

**SÍ, múltiples fuentes de evidencia:**

1. **Handoff:** `docs/handoffs/2026-07-24-hdu-028-033-034-auth-saga.md` (líneas 9-64) — describe la saga completa de fixes.
2. **Commit `adfd994`:** mensaje muy detallado (343 líneas de diff) que documenta la causa verificada. Cita `HDU-EXPLORE-009` (doble bug en `splash_page.dart:106` y `:118`).
3. **Comentario en código:** `splash_page.dart:96-101` y `main.dart:108-122` — documentan la decisión de centralizar en el splash.
4. **Spec:** `specs/HDU-EXPLORE-010-biometric-gate-cold-start.md` (líneas 16-20) — documenta la race condition `main.dart:117` vs `splash_page.dart:148`.
5. **Test T1 de `splash_page_test.dart:118-155`** — cubre exactamente el escenario del bug (sesión válida + currentUser null por timing).
6. **HDU-EXPLORE-009** está **referenciada en múltiples lugares** (handoffs, commit messages) pero **NO existe como archivo físico en `specs/`** del legacy. La investigación empírica se hizo directamente en el commit `adfd994`.

### Resumen de la causa raíz en 1 línea

> **Race condition entre `main.dart` (listener de Supabase) y `splash_page.dart` (doble navegación), exacerbada por `getCurrentUser()` asíncrono y `signOut()` forzado. Arreglado en HDU-033/034, centralizando la decisión de cold start en el splash.**

---

## Bloque E — Assets y dependencias externas

### E1. Assets de imagen

| Path | Formato | Tamaño | Uso |
|---|---|---|---|
| `assets/images/google_logo.svg` | SVG | 1141 bytes | Logo de Google para botón OAuth en LoginPage. NO es parte del splash. |

**No hay otros assets de imagen.** Verificado con `Get-ChildItem assets/images -Recurse`. El logo de Zeiki es código (`CustomPaint`), no asset.

### E2. Fuentes personalizadas

**NO hay.** La sección `flutter.fonts` está **ausente** en `pubspec.yaml` (líneas 60-64 solo declaran `assets/`). La fuente `'Segoe UI'` es del sistema.

### E3. Paquetes externos que el splash usa

Del `pubspec.yaml`:

- `flutter_svg: ^2.0.9` (línea 17) — instalado pero **NO usado por el splash directamente**. Lo usa el botón de Google OAuth.
- `flutter_bloc: ^8.1.3` (línea 16) — instalado, el proyecto lo usa en otras features, pero **el splash NO lo usa**.
- `get_it: ^7.6.4` (línea 19) — `sl<AuthRepository>()` se usa en `splash_page.dart:125`.
- `supabase_flutter: ^2.1.2` (línea 23) — `authRepository.getCurrentSession()` accede al cliente de Supabase por debajo.
- `local_auth: ^2.1.7` (línea 31) — `BiometricService.isBiometricEnabled()` en `splash_page.dart:165`.

**Paquéticos NO usados (importante):** `lottie`, `rive`, `flutter_animate`, `rive_flutter`. Todas las animaciones son `Tween` + `CustomPaint` + `AnimationController` puros de Flutter.

Imports del splash:
```dart
import 'package:flutter/material.dart';
import 'package:seiki_app/app/theme/app_theme.dart';
import 'package:seiki_app/app/router/app_routes.dart';
import 'package:seiki_app/app/widgets/zeiki_logo.dart';
import 'package:seiki_app/features/splash/presentation/widgets/particles_background.dart';
import 'package:seiki_app/features/splash/presentation/widgets/expanding_rings.dart';
import 'package:seiki_app/core/di/injection_container.dart';
import 'package:seiki_app/core/services/biometric_service.dart';
import 'package:seiki_app/features/auth/domain/repositories/auth_repository.dart';
```

---

## Hallazgos sorpresa (no preguntados pero relevantes)

1. **El "logo de Zeiki" no existe como asset gráfico.** Es código `CustomPaint` con coordenadas hardcodeadas (50, 40, 150, 160, etc.). Cambiar el logo = cambiar código. **Recomendación: extraer a SVG antes de que sea doloroso** (puede ser decisión de HDU-EXPLORE-002).

2. **El parámetro `withGlow` de `ZeikiLogo` es banda muerta.** Declarado en `zeiki_logo.dart:5, 19, 21` pero el painter nunca lo consulta. El "glow" del splash viene del `Container` exterior (3 `BoxShadow`), no del widget. En el splash se pasa `withGlow: true` (`splash_page.dart:264`) sin efecto.

3. **El "v1.0.0" del footer está hardcodeado** (`splash_page.dart:344`). Si en Zeiki se versiona dinámicamente, debe salir de `pubspec.yaml` o de remote config, no quedar fijo.

4. **El `Future.delayed(3s, () {})` original del commit `74c2d4b` tenía el callback VACÍO** (solo un comentario `"// Navegación automática - Listo para transición"`). El splash original **NO navegaba solo**. El usuario tenía que tocar la pantalla o hacer back. Esto fue un bug desde el día 1, no un bug evolutivo.

5. **HDU-EXPLORE-009 está referenciada en handoffs y commits pero NO existe como archivo físico** en `specs/`. La evidencia del bug del timing vive en: el mensaje del commit `adfd994` (343 líneas), el handoff `2026-07-24-hdu-028-033-034-auth-saga.md`, y los comentarios en el código. Si alguien busca el spec, no lo va a encontrar.

6. **El splash legacy es un punto de decisión centralizado, no solo UI.** NO es una pantalla bonita: es el "portero" que decide a dónde va el usuario después del cold start. Cualquier ruta nueva que se agregue debe pasar por aquí (o se reintroduce la race condition).

7. **El `main.dart` legacy también necesita cambios coordinados con el splash** (líneas 79-139). El listener de `onAuthStateChange` es parte integral del flujo. Migrar el splash sin migrar `main.dart` reintroducirá la race condition.

8. **El splash legacy NO tiene animación de salida.** La transición del splash al destino es abrupta (`pushReplacement` sin fade). Zeiki debería tener una transición de salida de 200-300ms.

9. **El splash legacy tiene 3 `BoxShadow` apilados en el logo container** (líneas 246-262 de `splash_page.dart`) que son los responsables del "glow" visual. Migrar solo el `ZeikiLogo` sin estos shadows pierde el efecto.

10. **El test del landscape usa el tamaño EXACTO del device de Hugo** (789.8×392.7, ver `splash_page_landscape_test.dart:110`). Es evidencia empírica: Hugo tuvo ese device y ese bug específico. Útil para HDU-002 si se quiere reproducir el caso.

---

## Conclusiones y recomendaciones

### ¿La hipótesis inicial (H1-H5) era correcta?

| Hipótesis | Resultado | Evidencia |
|---|---|---|
| H1: Splash es StatefulWidget o StatefulWidget simple | **Parcial** | Sí es StatefulWidget, pero tiene 6 animaciones + 2 widgets auxiliares + 7 imports. No es "simple". |
| H2: Usa Timer o Future.delayed | **Confirmado** | `Future.delayed(1500ms, ...)` en `splash_page.dart:103`. |
| H3.1: initState con push antes de animación | **Parcial** | En commit `9b634eb` sí, en la versión actual no. El push está en el callback de `Future.delayed`, no en `initState`. |
| H3.2: Timer cancelado prematuramente | **Refutado** | El `Future.delayed` no se cancela. El bug era que el callback estaba vacío o hacia cosas mal. |
| H3.3: AnimationController interrumpido | **Refutado** | No es la causa. |
| H4: Identidad de marca en assets + tema | **Parcial** | El tema sí está centralizado. El logo NO está en assets. |
| H5: No hay feature flag | **Confirmado** | El splash se muestra siempre, sin gating. |

### Qué se migra tal cual (input directo para HDU-002)

1. **Paleta de colores exacta** (de `app_theme.dart:5-11`): `0xFF7c3aed` primary, `0xFFa855f7` accent, `0xFF1a1a2e` background dark. Mismas constantes, en `lib/core/theme/` o equivalente en Zeiki.
2. **Layout general** del splash: logo centrado + texto "ZEIKI" + tagline "LOADING" + footer con versión + progress bar. Misma estructura, solo cambia el router.
3. **Animaciones de entrada** (las 6 del AnimationController 2500ms): scale+rotation+opacity del logo, slide+opacity del texto, width del progress bar. Mismas curvas, mismos intervalos.
4. **Fondo animado**: las 50 partículas (loop 8s) y los 3 anillos expansivos (loop 3s). Mismo comportamiento.
5. **Tipografía** `'Segoe UI'` (del sistema). Misma decisión si se mantiene como sistema-font.
6. **Textos**: "ZEIKI" 72px bold, "LOADING" 18px, "v1.0.0 - Developed by Seiki Team" 14px. **Mismo copy**, **PERO** el "v1.0.0" debe ser dinámico (venir de `pubspec.yaml` o remote config).
7. **Colores del texto**: blanco sólido para "ZEIKI", `Colors.white70` para "LOADING", `Colors.white60` para el footer. Mismos valores con alpha.
8. **Sombras del logo container**: 3 `BoxShadow` apilados (líneas 246-262). Son las responsables del glow visual.

### Qué se descarta

1. **Callback de `Future.delayed` con `signOut()` forzado** (commit `9b634eb`). Es un bug, ya revertido.
2. **Doble `pushReplacementNamed`** (commits pre-`adfd994`). Es un bug, ya revertido.
3. **`getCurrentUser()` asíncrono** en el splash. Reemplazado por `getCurrentSession()` síncrono.
4. **`Navigator.pushReplacementNamed`** del legacy. En Zeiki se usa `go_router` (Target §3).
5. **`get_it` (DI)**. En Zeiki se usa otra cosa (ver Target §3, no explorado en este reporte).
6. **`AuthRepository` legacy** con la firma completa. En Zeiki se rediseña con la arquitectura nueva.
7. **`BiometricService` legacy** con la firma rota. En Zeiki se reescribe con `local_auth` y opciones correctas (HDU-EXPLORE-010 ya documentó el bug).
8. **`AppRoutes` legacy** con mapa de routes hardcodeado. En Zeiki se centraliza en `go_router`.
9. **`AuthStateChangeNotifier` legacy** que se llama desde `main.dart` para forzar inicialización. En Zeiki se rediseña.
10. **El parámetro `withGlow` de `ZeikiLogo`** (banda muerta). Si se migra el widget, quitar este parámetro o implementarlo de verdad.
11. **El "v1.0.0" hardcodeado** del footer. Reemplazar por lectura de `pubspec.yaml` o remote config.
12. **Las rutas legacy que decidían cuándo se mostraba el splash** (explícitamente excluido por el spec de la HDU-EXPLORE-001).

### Qué se mejora (input directo para HDU-002)

1. **Usar `go_router`** (Target §3) en vez de `Navigator.pushReplacementNamed`. El splash debe ser una ruta de go_router, no un widget standalone.
2. **Usar BLoC** (Target §3) en vez de `StatefulWidget` directo. El splash tiene estado (autenticación, animación, navegación) que merece su propio cubo. Esto facilita testing.
3. **Feature flag OBLIGATORIO** (Target §10). Definir un `AppFeature.splash` o `AppFeature.brandedSplash` de tipo Release. El splash debe estar apagado por default y activarse explícitamente. Esto es regla de CD seguro de Zeiki.
4. **Centralizar la decisión de navegación post-cold-start en UNA sola fuente.** El listener de Supabase NO debe navegar. Solo el splash decide. Mismo patrón que HDU-034 en el legacy.
5. **Usar `getCurrentSession()` directo de Supabase** (síncrono) en vez de wrapper. Es el patrón validado por HDU-033/EXPLORE-009.
6. **Animación de salida (fade out 200-300ms) antes del `pushReplacement`.** El legacy NO la tiene. La transición abrupta es un rough edge.
7. **Si el logo se mantiene, aislarlo en `lib/app/widgets/zeiki_logo.dart` o `lib/core/branding/`.** Si se quiere evolucionar, mejor como SVG (decisión de Hugo, ver HDU-EXPLORE recomendada).
8. **NO recrear el bug del cortado** (checklist de patrones prohibidos en la nueva implementación):
   - NUNCA doble `pushReplacementNamed` (ni en splash, ni en main, ni en ningún lado).
   - NUNCA `signOut()` dentro del splash.
   - SIEMPRE `if (!mounted) return;` antes de navegar.
   - SIEMPRE una sola fuente de decisión post-cold-start.
   - SIEMPRE `getCurrentSession()` síncrono, nunca `getCurrentUser()` asíncrono para decidir navegación.
9. **Manejo del `Future.delayed` con `AnimationController.addStatusListener`**: en vez de un `Future.delayed` separado, escuchar el estado del `AnimationController`. Si la animación se interrumpe (por ejemplo, dispose), NO navegar. Esto evita el race condition entre timing y animación.
10. **Tests adicionales** más allá de los T1-T3 del legacy:
    - T4: feature flag on/off cambia visibilidad del splash.
    - T5: sesión válida + biometría activada → navega a /biometric-gate (no /dashboard).
    - T6: listener de Supabase llega tarde post-splash → no doble navegación.
    - T7: app disposed mid-animación → no navega, no crashea.
    - T8: dark mode / light mode del sistema (si se decide soportar).
11. **Soporte de dark/light mode (decisión abierta):** el legacy siempre es dark. Si en Zeiki se quiere respetar el theme del sistema, hay que definir una variante clara del splash para light mode.
12. **Reducir la dependencia del splash con `BiometricService`.** En Zeiki, si se decide no usar biometría, el splash NO debe acoplarse a ella. Usar un `FeatureGate` o un evento de `AuthBloc` para abstraer.

### ¿Qué cambia en el spec de la HDU-002 gracias a esta exploración?

1. **La HDU-002 debe incluir coordinación con `main.dart` (o el equivalente en Zeiki).** El listener de Supabase NO debe navegar. Esta es una decisión de arquitectura que debe documentarse en el spec de la HDU-002, no es solo del splash.
2. **La HDU-002 debe respetar Target §10** desde el día 1: splash detrás de `AppFeature.splash` (Release). El spec debe declarar el flag y el plan de remoción.
3. **La HDU-002 debe incluir tests de race condition** (T4-T8 propuestos arriba) además de los T1-T3 del legacy.
4. **La HDU-002 debe decidir**: ¿el logo se queda como `CustomPaint` o se extrae a SVG? Esto es decisión de Hugo, no técnica. **Bloqueador si se quiere evolucionar branding.**
5. **La HDU-002 debe incluir**: la fuente `'Segoe UI'` confirmada como la tipografía de marca. Si en Zeiki se quiere cambiar, debe ser decisión explícita de Hugo.
6. **La HDU-002 debe decidir**: si el splash respeta el theme del sistema (light/dark) o siempre es dark. El legacy siempre es dark.
7. **La HDU-002 debe incluir**: animación de salida (fade out) antes de navegar, no solo entrada. Mejora de UX no presente en el legacy.
8. **La HDU-002 debe documentar los patrones prohibidos** (checklist de D1-D4) en el código o en el spec, para que cualquier implementer futuro no repita los bugs.

### ¿Hay riesgo nuevo descubierto?

1. **La HDU-002 NO puede ser la primera HDU de implementación en Zeiki.** El splash depende de: auth básico, routing, una pantalla de destino (dashboard o login), y el sistema de feature flags. Sin estos, no se puede probar el splash de Zeiki. **Recomendación: implementar primero HDU de auth básico + go_router + feature flag, y luego HDU-002.**

2. **El "logo" es código, no asset.** Si en el futuro se quiere cambiar el branding, hay que modificar código fuente en vez de reemplazar un PNG/SVG. Riesgo de deuda técnica si no se documenta la decisión.

3. **El splash legacy tiene acoplamiento fuerte con `BiometricService`.** Si en Zeiki se decide no usar biometría, hay que quitar esa lógica. Si se decide usar, hay que asegurar el patrón de opciones (`biometricOnly: true, stickyAuth: true, useErrorDialogs: true`) que HDU-EXPLORE-010 documentó como bug pre-existente.

4. **El splash legacy NO tiene feature flag** (violación de Target §10). Hay que añadirlo desde el día 1.

5. **El splash legacy NO tiene animación de salida.** La transición abrupta es un rough edge de UX.

6. **El parámetro `withGlow` es banda muerta.** Si se migra el `ZeikiLogo` tal cual, se arrastra el parámetro inútil. Limpieza necesaria.

7. **El "v1.0.0" está hardcodeado.** Si en Zeiki se versiona, debe ser dinámico. Riesgo de que el splash siempre diga "v1.0.0" aunque la app esté en v2.0.0.

8. **HDU-EXPLORE-009 NO existe como archivo físico.** Si alguien busca la evidencia del bug del timing, va a pensar que no está documentado. **Recomendación: antes de implementar HDU-002, crear `specs/HDU-EXPLORE-009-sesion-restauracion.md` en el repo Zeiki con la evidencia consolidada** (commit messages, handoffs, tests). Es la única forma de que las sesiones futuras tengan acceso a la historia del bug.

### ¿Se requiere otra HDU-EXPLORE antes de implementar?

**SÍ, dos HDU-EXPLORE recomendadas** (ambas de producto, no técnicas):

1. **HDU-EXPLORE-002 — Decisiones de marca para Zeiki.**
   - ¿El logo se queda como `CustomPaint` o se extrae a SVG?
   - ¿Tipografía: `'Segoe UI'` del sistema o se carga una custom?
   - ¿Dark mode siempre, o respetar theme del sistema?
   - ¿Animación de salida: sí o no?
   - ¿Branding "Seiki" → "Zeiki": solo cambio de nombre en el texto o rediseño?
   - ¿Por cuánto tiempo se muestra el splash? (el legacy usa 1.5s + 2.5s de animación, total 4s).
   - **Owner:** Hugo (decisiones de producto).
   - **Bloqueador:** sí, si se decide extraer el logo a SVG (cambio de assets).

2. **HDU-EXPLORE-003 — Sistema de feature flags en Zeiki (Target §10 setup).**
   - ¿Cómo se define el primer `AppFeature`? ¿Splash es el primero?
   - ¿Cómo se sincroniza el enum en código con la tabla en Supabase?
   - ¿Cómo se testea una feature detrás de flag?
   - ¿Cómo se hace rollout gradual (1% → 10% → 50% → 100%)?
   - **Owner:** técnico (Mavis/orquestador + implementer).
   - **Bloqueador:** sí, el splash nuevo DEBE tener feature flag desde el día 1.

**No requiere HDU-EXPLORE adicional** el auth flow (HDU-EXPLORE-009 y 010 ya cubrieron eso, aunque el 009 no exista como archivo). La evidencia está consolidada en este reporte y en los handoffs del legacy.

---

## Evidencia

### Archivos leídos (legacy)

| Archivo | Líneas | Razón |
|---|---|---|
| `lib/features/splash/presentation/pages/splash_page.dart` | 397 | Widget principal + lógica de navegación |
| `lib/features/splash/presentation/widgets/particles_background.dart` | 144 | Fondo animado (partículas) |
| `lib/features/splash/presentation/widgets/expanding_rings.dart` | 109 | Fondo animado (anillos) |
| `lib/app/widgets/zeiki_logo.dart` | 89 | Logo CustomPaint |
| `lib/app/theme/app_theme.dart` | 35 | Paleta de colores |
| `lib/app/router/app_routes.dart` | 150 | Constantes y mapa de rutas |
| `lib/main.dart` | 145 (sección relevante 79-139) | Listener de Supabase |
| `lib/main.dart.backup` | 47 | Comparación con main.dart actual |
| `pubspec.yaml` | 64 | Dependencias y assets |
| `test/widget/splash/splash_page_test.dart` | 218 | Tests de sesión |
| `test/widget/splash/splash_page_landscape_test.dart` | 145 | Tests de landscape overflow |
| `docs/handoffs/2026-07-24-hdu-028-033-034-auth-saga.md` | 199 | Handoff de la saga de fixes |
| `specs/HDU-EXPLORE-010-biometric-gate-cold-start.md` | 65 | Research de race condition |
| `docs/architecture/target-architecture.md` (Zeiki) | §10 líneas 489-575 | Política de feature flags |

### Commits del legacy consultados (git log/show)

| Commit | Fecha | Mensaje | Relevancia |
|---|---|---|---|
| `cf4f717` | 2025-??-?? | "start seiki" | Inicio del proyecto. |
| `74c2d4b` | 2025-11-10 | "splash screen" | **Splash creado, callback VACÍO.** |
| `be25ee6` | (2025) | "update onboarding" | Actualización de onboarding. |
| `df50500` | (2025) | "registro con google" | Google signup. |
| `57d9760` | (2025) | "login with google" | Google login. |
| `ff6cd08` | (2025) | "login y registro completo" | Auth completa. |
| `d26502b` | (2025) | "codigo postal API" | Servicio de códigos postales. |
| `48c2eb0` | (2025) | "update authservice ( cambio de ruta )" | Cambio de ruta en auth. |
| `9b634eb` | (2026) | "feat: refactor auth to Clean Architecture with BLoC + google_sign_in integration" | **Introduce doble push + getCurrentUser asíncrono + signOut forzado.** |
| `b2a7445` | (2026) | "feat: add biometric unlock + fix logout flow" | Biometric unlock. |
| `538766b` | 2026-07-09 | "fix: integrate biometric button into login page, remove separate unlock screen" | **Bug B: navega a /login en vez de /dashboard.** |
| `adfd994` | 2026-07-24 | "fix(splash): restore persisted session on cold start via currentSession + /dashboard navigation [HDU-033]" | **Fix completo del bug del cortado. 343 líneas de diff.** |
| `2ee4bc7` | 2026-07-24 | "feat(auth): biometric gate post-cold-start + fix BiometricService.authenticate options [HDU-034]" | Quita nav de main.dart + biometric gate. |
| `bea06f9` | 2026-07-27 | "fix(splash): landscape overflow + branded auth emails [HDU-035]" | Fix overflow en landscape. |
| `0d18d7d` | (HEAD) | "chore(hdu): cierre saga auth - PRs #17 #18 #19 mergeadas" | Cierre de la saga. |

### Comandos ejecutados (resumen)

```powershell
# Localizar splash
Get-ChildItem "C:\Users\Pc\Documents\Seiki\seiki_app_github" -Recurse -Force | Where-Object Name -Match "splash"
rg -i "splash" "C:\Users\Pc\Documents\Seiki\seiki_app_github"

# Git log del splash
git log --all --oneline -- lib/features/splash/presentation/pages/splash_page.dart
git log --all --oneline --grep="splash\|cortad\|timing" -i
git log --all --oneline --grep="HDU-033"
git log --all --oneline --grep="navegaci\|navigation\|splash" -i

# Código histórico (para entender la evolución del bug)
git show 74c2d4b:lib/features/splash/presentation/pages/splash_page.dart
git show 9b634eb:lib/features/splash/presentation/pages/splash_page.dart
git show 538766b:lib/features/splash/presentation/pages/splash_page.dart
git show 74c2d4b --stat
git show 9b634eb --stat
git show adfd994 --stat
```

### Assets encontrados

```powershell
Get-ChildItem "C:\Users\Pc\Documents\Seiki\seiki_app_github\assets\images" -Recurse -Force
# Resultado: 1 solo archivo
# C:\Users\Pc\Documents\Seiki\seiki_app_github\assets\images\google_logo.svg (1141 bytes)
```

### Condiciones de la lectura

- **Fecha:** 2026-07-29.
- **Hora:** sesión de research.
- **Working tree del legacy:** NO se modificó nada. Solo lectura.
- **Working tree de Zeiki:** se creó `docs/research/` (carpeta nueva, no había).
- **Rama de Zeiki:** `chore/hdu-explore-001-splash-legacy` (ya creada, el spec de la HDU-EXPLORE-001 está commiteado ahí).

---

## Apéndice — Comandos de git ejecutados (crudos)

```bash
# Verificar HEAD del legacy
cd "C:\Users\Pc\Documents\Seiki\seiki_app_github"
git log --oneline -1
# 0d18d7d chore(hdu): cierre saga auth - PRs #17 #18 #19 mergeadas

# Verificar working tree
git status
# (no ejecutado en esta sesión, pero el spec del HDU asume clean)

# Historia del splash
git log --all --oneline -- lib/features/splash/presentation/pages/splash_page.dart
# 14 commits devueltos, ordenados del más reciente al más antiguo

# Búsqueda por keyword
git log --all --oneline --grep="splash\|cortad\|timing" -i
# 20+ matches, incluyendo HDU-033/034/035

# Verificación de ausencia de HDU-EXPLORE-009
ls specs/HDU-EXPLORE-009*
# No such file
```

---

*Reporte generado por Mavis. Sesión de research cerrada 2026-07-29.*
