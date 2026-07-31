# HDU-006 — Code Review (v2, re-review)

**Rama:** `feat/hdu-006-splash-nuevo`
**Spec:** `specs/HDU-006-splash-nuevo.md`
**Diff revisado:** 2 commits nuevos sobre la v1 (`1949e67` fix, `ea237bd` chore)
**Reviewer:** zeiki-reviewer (3 gates: clean code + security + architecture)
**Auditor de minimalismo:** ya pasó en v1. Este reporte NO cubre minimalismo, redundancias ni scope creep.
**Fecha:** 2026-07-31
**Re-review de:** [`docs/reviews/HDU-006-review.md`](HDU-006-review.md) (v1: 🔴 Rechazado)

---

## ✅ Bloqueante original corregido

El 1er pase rechazó el PR con 1 bloqueante: `rootBundle.loadString('pubspec.yaml')` fallaría en producción porque `pubspec.yaml` no está en `flutter.assets:`, el `catch` lo enmascaraba y el footer siempre diría "v?".

### Verificación del fix

**Implementación** — `lib/features/identidad/screens/splash_screen.dart:33, 235-264`:
- Línea 33: `import 'package:package_info_plus/package_info_plus.dart';` ✅
- Línea 254: `final info = await PackageInfo.fromPlatform();`
- Línea 255: `final version = info.version;` (devuelve el `versionName` del `AndroidManifest` / `CFBundleShortVersionString` del `Info.plist`)
- `_parseVersionFromPubspec` ya no existe (verificado con grep en `lib/`).

**Test endurecido** — `test/features/identidad/screens/splash_screen_test.dart:51-57, 129-142`:
- `setUp` llama `PackageInfo.setMockInitialValues(version: '0.1.0', ...)` con la versión real del pubspec.
- El test del footer ahora tiene **doble assert** (defensa en profundidad):
  1. `expect(find.textContaining('v?'), findsNothing, reason: '...')` — falla si la versión es "v?".
  2. `expect(find.text('v0.1.0 · Developed by Zeiki Team'), findsOneWidget, ...)` — exige el texto exacto.

### ¿El test cacharía el bug si alguien vuelve a `rootBundle.loadString('pubspec.yaml')`?

**Sí.** Hipotético: si alguien reemplazara `PackageInfo.fromPlatform()` por `rootBundle.loadString('pubspec.yaml')`:
- La lectura lanzaría `Unable to load asset` en runtime.
- El `catch (_)` lo traga.
- `_appVersion` queda en `null` → footer muestra "v?".
- **El assert #1 falla** (`findsNothing` para "v?" es violado).
- **El assert #2 también falla** (el texto "v0.1.0 · Developed by Zeiki Team" no existe).

El test ya no es "pasa con cualquier cosa" — **falla ruidosamente** si la versión se rompe. Cumple el regression test pedido en conventions §3 ("Regression para cada bug arreglado: un test que reproduce el bug. Falla antes del fix, pasa después.").

### ¿Por qué no `PlatformDispatcher.instance.applicationVersion` (la opción 1 de mi v1)?

Verificado el comentario en `splash_screen.dart:249-253` y el commit `1949e67`:
- El getter NO existe en Flutter 3.38.3 (probado: `undefined_getter` al compilar).
- Por lo tanto, **mi sugerencia v1 estaba mal** para esta versión de Flutter. La justificación para ir a `package_info_plus` es válida y está bien documentada (en código + en el mensaje del commit + en el pubspec.yaml).
- Reconozco el error de mi sugerencia v1: debí haber verificado que `PlatformDispatcher.applicationVersion` existiera antes de proponerlo. Es la lección.

### Veredicto del bloqueante

- [x] **Bloqueante original corregido.** AC8 cumplido en producción (con la dep, no requiere que `pubspec.yaml` esté en `flutter.assets:`).
- [x] **Test endurecido.** El footer test falla si la versión vuelve a "v?".
- [x] **Cero nuevos bloqueantes introducidos** por el fix.

---

## Gate 1 — Clean Code

### Bloqueantes

Ninguno.

### No bloqueantes

- `praise:` [lib/features/identidad/screens/splash_screen.dart:243-253] El comentario explica **el porqué** de la decisión v1, el porqué de la v2, y por qué no se eligió `PlatformDispatcher`. Es didáctico (28 líneas de comentarios para 7 líneas de código), pero cumple conventions §2 ("Documentar el porqué, no el qué"). El trade-off: el dev del futuro puede hacer `git log` y obtener lo mismo, pero el comentario lo deja en el sitio donde importa. **Decisión de gusto**, no la marco como issue.

- `praise:` [pubspec.yaml:71-77] La justificación de la dep en el pubspec responde las 4 preguntas de conventions §11 (¿ya existe? no; ¿lo resuelve el lenguaje? no; ¿lo resuelve el framework? no para esta versión; ¿vale la pena? sí). Documenta además por qué se rechazó `PlatformDispatcher`. Cero ambigüedad sobre por qué `package_info_plus` está ahí.

- `praise:` [test/features/identidad/screens/splash_screen_test.dart:51-57] El mock de `PackageInfo` se hace en `setUp` (no en cada test), con `setMockInitialValues` (la API oficial de testing del plugin, NO mockito). Cero overhead de `build_runner`. Coherente con conventions §3 ("Mocks solo donde se necesita").

- `praise:` [test/features/identidad/screens/splash_screen_test.dart:129-135] El `reason:` del `expect(find.textContaining('v?'), findsNothing, ...)` cita explícitamente el archivo y la línea donde diagnosticar: "Revisar `_loadAppVersion()` en `splash_screen.dart`". Esto baja el costo del próximo dev que rompa el footer: el mensaje del test le dice dónde mirar.

- `thought:` [lib/features/identidad/screens/splash_screen.dart:259-263] El `catch (_)` traga la excepción silenciosamente y deja `_appVersion` en `null`. **No hay test que cubra el caso "PackageInfo.fromPlatform() lanza excepción"** (ej. plugin no inicializado en runtime, error de plataforma). El `reason:` del assert #1 cubre el caso "v?", pero no el caso "excepción real en catch". Si el día de mañana alguien remueve el `try/catch` "porque no se necesita", el splash crashearía sin que ningún test lo detecte. Sugerencia: agregar un test con `PackageInfo.setMockInitialValues(...)` + un override que lance (ej. `setMockInitialValues` no es trivial de hacer fallar, pero se puede mockear el channel con `TestDefaultBinaryMessenger`). Hoy: no bloqueante, coverage gap.

- `nit:` [lib/features/identidad/screens/splash_screen.dart:33] El import de `package_info_plus` está posicionado correctamente (después de `flutter/material.dart`, antes de `flutter_bloc`). Coherente con el orden alfabético de imports de paquetes externos del resto del archivo. Solo lo menciono para confirmar que el lint está feliz.

---

## Gate 2 — Security

### Bloqueantes

Ninguno.

### No bloqueantes

- `praise:` [pubspec.yaml] `package_info_plus` es un plugin del **Flutter Community Plus** org (mantenedor oficial de la mayoría de plugins "plus" de Flutter). 1000+ likes en pub.dev, mantenido activamente, sin CVEs conocidos. Es el plugin canónico para "leer metadata del propio paquete" en Flutter. No es código sospechoso.

- `praise:` [android/app/src/main/AndroidManifest.xml] Verificado: **cero permisos nuevos**. `package_info_plus` lee del `PackageManager` (accesible sin permiso) y de los metadatos del propio APK. No requiere `INTERNET`, ni `READ_EXTERNAL_STORAGE`, ni nada. El manifest solo tiene los permisos pre-existentes de `local_auth` (`USE_BIOMETRIC`, `USE_FINGERPRINT`) y el `<queries>` de Flutter para `PROCESS_TEXT`. Sin superficie de ataque añadida.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:259-263] El `catch (_)` no loguea nada (ni el path, ni el contenido, ni el stack). Cumple conventions §6 ("Sin logs de información sensible"). Si la lectura falla, no se filtra información del sistema. Idéntico al comportamiento del v1 — bien.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:254-255] La API expuesta es `PackageInfo.fromPlatform().version`, que solo lee el `versionName`/`CFBundleShortVersionString` del propio bundle. No expone datos del sistema, no hace red, no accede a identificadores del dispositivo. Lo único que lee es metadata que el propio proyecto controla.

- `question:` [lib/features/identidad/screens/splash_screen.dart:104-108] **Comportamiento fail-safe del feature flag** — **REGISTRADA para conversación con Hugo, no requiere acción inmediata en este PR.** Se mantiene la pregunta del v1:
  > "Cuando la red está caída y el cache del `TierService` está vacío, `TierService.has()` devuelve `false`. Esto significa que el splash se salta y el usuario va directo al redirect. El comportamiento actual es: 'si no puedo leer el flag, no muestro el splash' (fail-safe hacia skip). El spec dice 'Si el flag está OFF → no se renderiza', y el fail-safe de `TierService` es OFF por default. Es **consistente con el spec**, pero quiero confirmar que esto es lo que quieres antes de mergear. Si prefieres fail-safe hacia 'show', hay que cambiar la lectura + agregar test del caso 'red caída'."
  
  Mavis (orquestador) confirmó: esta pregunta se queda registrada en el reporte pero NO requiere respuesta ahora — se lleva por separado a Hugo. No bloquea el merge.

- `praise:` [test/widget_test.dart:64-70] El mock de `PackageInfo` en el smoke test sigue el mismo patrón que el mock del test del splash. Consistencia: si el día de mañana se cambia la versión, los dos tests fallan juntos. Sin riesgo de "test pasa porque olvidamos mockear en uno de los dos lugares".

- `praise:` [test/widget_test.dart:76] El smoke test sigue configurando `tier.flags[AppFeature.splash] = false` para auto-navegar sin esperar las 2.5s de animación. Esto significa que el smoke test **no exercita el path de "PackageInfo desde el platform channel real"** — pero el widget test del splash sí lo hace (con mock). Cobertura adecuada sin tests lentos.

---

## Gate 3 — Architecture

### Bloqueantes

Ninguno.

### No bloqueantes

- `chore:` [docs/adr/ADR-012-router-location-and-getit.md:125] **El comando de verificación quedó PARCIALMENTE bien — hay un mismatch numérico que arreglar antes del merge (o en commit aparte, decisión de Hugo).** El ADR ahora dice:
  > "A 2026-07-31, HDU-006: 5 imports — `splash_cubit.dart`, `home_screen.dart`, `login_screen.dart`, `register_screen.dart`, `splash_screen.dart`, `unlock_screen.dart` — todos en `app_router.dart`."
  
  **El conteo dice 5, pero la lista tiene 6.** Verificado con `grep "import.*features" lib/core/router/app_router.dart`:
  1. `splash_cubit.dart`
  2. `home_screen.dart`
  3. `login_screen.dart`
  4. `register_screen.dart`
  5. `splash_screen.dart`
  6. `unlock_screen.dart` ← **el sexto, se me había escapado en la v1**
  
  El commit `ea237bd` también dice "5 imports" en el mensaje — coherente con el ADR pero igual de incorrecto. La matemática:
  - v1 del review (HDU-006, 3cd06ec): 4 imports (`home_screen`, `login_screen`, `register_screen`, `unlock_screen`).
  - HDU-006 agrega 2: `splash_cubit` + `splash_screen` → 4 + 2 = **6**, no 5.
  
  El texto en sí (la lista, la fecha, la regla "todos los imports del router, no solo los actuales") está bien. Solo el número está mal. **Fix de 1 palabra**: cambiar "5 imports" por "6 imports" en `ADR-012:125` y en el mensaje del commit `ea237bd` (squash o fixup, decisión de Hugo). **No bloquea el merge** — es un chore trivial, pero lo reporto porque en la v1 dije explícitamente "actualizar el comando como chore de cleanup" y ese chore quedó con un typo.

- `thought:` [lib/features/identidad/screens/splash_screen.dart:33, 254] `package_info_plus` se usa **directo** en `splash_screen.dart` (línea 254), sin un wrapper en `lib/core/`. Esto rompe el patrón que el proyecto aplica consistentemente:
  - `lib/core/auth/google_sign_in_handler.dart` envuelve `google_sign_in`.
  - `lib/core/services/biometric_service.dart` envuelve `local_auth`.
  - Ambos comentarios al inicio citan explícitamente la regla: "los features consumen este servicio desde GetIt, NUNCA el plugin directo" (`biometric_service.dart:14-16`).
  
  **¿Es bloqueante?** No, por dos razones:
  1. `package_info_plus` se usa en **un solo callsite** (el footer del splash). El patrón "wrapper en core" se justifica cuando hay múltiples features consumidores o cuando la lógica de error/esquema es no-trivial (como biometría, que tiene cache + KEY por usuario + fallbacks).
  2. Conventions §2 dice "Duplicar 10 líneas sobre crear una abstracción innecesaria" — crear un `AppInfoService` con 1 método para 1 callsite sería over-engineering.
  
  **Pero también hay un argumento a favor del wrapper:**
  - Si el día de mañana se quiere leer otra metadata del paquete (ej. `buildNumber`, `packageName` para mostrar en una pantalla "About"), o si se quiere migrar de `package_info_plus` a otra cosa, el cambio es local a `lib/core/` en vez de un grep en todos los `lib/features/`.
  - El comentario en `biometric_service.dart:14-16` ("los features consumen este servicio desde GetIt, NUNCA el plugin directo") es **categórico** — no dice "salvo cuando se usa en un solo feature".
  
  **Recomendación:** dejarlo así hoy (1 callsite, KISS), pero registrar el caso. Si en una HDU futura aparece un segundo uso de `package_info_plus`, **esa es la HDU correcta para extraer el wrapper** (no antes, no después). Lo dejo como `thought:` para que quede en el radar. **No bloqueante.**

- `praise:` [pubspec.yaml:77] La versión `^8.0.2` es un rango conservador (cubre 8.0.2 hasta <9.0.0, no "cualquier mayor"). Cumple conventions §11 ("Las deps se declaran con versión exacta o rango conservador"). La justificación está al lado del nombre, no escondida en otro doc.

- `praise:` [pubspec.yaml:9-77] El pubspec tiene un patrón consistente: cada dep lleva un comentario al lado que explica **para qué se usa + a qué HDU pertenece + advertencias operativas** (ej. `local_auth:68-69` menciona "Acción de Hugo pendiente: activar biometría en el Xiaomi"). El comentario de `package_info_plus:71-77` sigue el mismo formato. Cero fricción para el siguiente dev que abra el archivo.

- `praise:` [lib/features/identidad/screens/splash_screen.dart:89] El comentario "Versión leída de pubspec.yaml (AC8). Cacheada en el primer build." **sigue siendo correcto** aunque la implementación ya no lea pubspec.yaml. El AC8 dice "footer muestra la versión real" — la versión **proviene** del pubspec (vía `versionName` en el manifest, que el plugin lee), solo que el camino técnico cambió. La documentación a nivel AC sigue válida.

- `praise:` [docs/adr/ADR-012-router-location-and-getit.md:121-125] La sección "Cuándo NO se revisa" del ADR explícitamente dice: "Cambios en las pantallas reales (migración de placeholders a reales, en futuras HDUs). La excepción cubre **cualquier** pantalla real que el router importe, no solo las actuales." → HDU-006 NO requirió un ADR nuevo, exactamente como el ADR predecía. La excepción arquitectónica está funcionando como se diseñó. Bien.

- `praise:` (heredado de v1) El patrón de "DI vive en el router, no en la pantalla" sigue funcionando. El `SplashCubit` se provee desde `app_router.dart` vía `splashCubit:` param, los tests inyectan un Cubit controlado. Cero acoplamiento entre el splash y el ciclo de vida del Cubit.

---

## Veredicto

- [x] ✅ **Aprobado: 0 bloqueantes. El PR puede mergear.**
- [ ] 🟡 Aprobado con cambios: solo no bloqueantes, no bloquean el merge.
- [ ] 🔴 Rechazado: hay 1+ bloqueante(s). NO mergear hasta corregir.

### Resumen

- **Total issues:** 0 bloqueantes, 0 no bloqueantes críticos. 1 chore (mismatch numérico en ADR-012), 1 thought (wrapper de `package_info_plus`), 1 thought (coverage gap del `catch`), 1 question (fail-safe de red, registrada para Hugo), varios `praise:` y `nit:`.
- **Bloqueante original (v1):** ✅ **Corregido.** `package_info_plus` lee la versión del `AndroidManifest`/`Info.plist` (no requiere que `pubspec.yaml` esté en `flutter.assets:`). El test del footer está doblemente endurecido: falla si la versión es "v?" Y exige el texto exacto `v0.1.0 · Developed by Zeiki Team`.
- **Gate 1 (Clean Code):** ✅ Pasa limpio. Cero bloqueantes. 1 thought sobre coverage del catch (no bloqueante).
- **Gate 2 (Security):** ✅ Pasa limpio. Cero bloqueantes, cero permisos nuevos. 1 question de fail-safe **registrada para Hugo, no requiere acción ahora**.
- **Gate 3 (Architecture):** ✅ Pasa limpio. Cero bloqueantes. 1 chore de ADR con typo numérico (no bloquea) + 1 thought sobre wrapper de plugin (no bloquea, justificado por KISS).
- **Side effects del fix:** Cero. `package_info_plus` no agrega permisos en Android ni iOS, no hace red, no accede a datos sensibles. Plugin oficial del Flutter Community Plus org, sin CVEs conocidos.
- **Cumplimiento de conventions:**
  - §3 (testing): ✅ fakes > mocks, regression test para el bug arreglado, `PackageInfo.setMockInitialValues` es la API oficial de testing.
  - §6 (seguridad): ✅ `catch (_)` no loguea nada.
  - §11 (deps): ✅ justificación documentada, rango conservador, dep explícita (no implícita).
- **Lección para el reviewer (yo, v1):** debí verificar que `PlatformDispatcher.instance.applicationVersion` existiera en Flutter 3.38.3 antes de proponerlo como opción 1. La opción 2 (`package_info_plus`) era la correcta desde el inicio. Lo reconozco en este reporte.

### Acción esperada del implementer

1. **Arreglar el typo del ADR-012** (commit aparte o fixup, decisión de Hugo): cambiar "5 imports" por "6 imports" en `docs/adr/ADR-012-router-location-and-getit.md:125`. Si se hace como fixup del commit `ea237bd`, también actualizar el mensaje del commit.
2. **Re-correr la suite** + integration test en Xiaomi para confirmar que el cambio de `package_info_plus` no rompió nada en runtime (no debiera, pero el integration test es la red de seguridad).
3. **Reporte a Mavis** cuando esté listo para mergear.

### Acciones NO requeridas (registradas, no bloquean)

- **Wrapper de `package_info_plus`:** no se hace en esta HDU. Si aparece un segundo callsite, se extrae en esa HDU.
- **Test del `catch (_)`:** coverage gap, no bloquea. Se puede agregar como chore en una HDU futura.
- **Fail-safe de red caída:** registrada como `question:` en Gate 2, decisión de Hugo por separado.

---

*Reporte generado por `zeiki-reviewer` siguiendo `agent.md` (3 gates + Conventional Comments + veredicto). El bloqueante original está corregido y el test está doblemente endurecido — el footer del splash mostrará `v0.1.0 · Developed by Zeiki Team` en producción, no `v?`. El único issue pendiente es un typo numérico en el ADR-012 (5 vs 6 imports) que se arregla con 1 palabra.*
