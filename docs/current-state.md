# Current State — Zeiki

> **Snapshot rápido del estado del proyecto.** Se actualiza en el cleanup (paso 12) de cada HDU cerrada. Para el detalle de una HDU específica, ver `specs/HDU-XXX-*.md`. Para el histórico, ver `.mavis/hdu.md`.

**Última actualización:** 2026-08-04 (post-cleanup VerifyEmailScreen, PR #20 mergeado).

---

## 📍 Dónde estamos

- **Fase:** 1 (MVP).
- **Última unidad cerrada:** Cleanup de `VerifyEmailScreen` (PR #20) — código muerto de HDU-007 borrado.
- **HDUs activas:** ninguna.
- **BUGs activas:** ninguno (BUG-002b sobre "Revisa tu correo" no aparece post-signUp está agendado pero no abierto).
- **Rama `main`:** deployable (último merge: `90b843a` — PR #20).
- **Stack operativo:** Flutter 3.38.3 + Supabase (proyecto Zeiki, región `us-east-2`) + Deno para edge functions.
- **Proyecto Supabase:** ref `iocbqjzmoneulydmeavr`, URL `https://iocbqjzmoneulydmeavr.supabase.co`. Config en `assets/.env` (en `.gitignore`).

## ✅ HDUs cerradas recientemente

### HDU-001 — Base del proyecto Flutter (2026-07-29)
- PR #1 mergeado a main.
- Crea la base del proyecto: `lib/main.dart` con placeholder, 6 carpetas en `lib/core/` (auth, di, logging, constants, services, tiers), 6 carpetas en `lib/features/` (identidad, fiscal, clientes, reportes, asistencia, configuracion), `pubspec.yaml` con 7 dependencias, `analysis_options.yaml` estricto, smoke test.
- Crea los agentes `zeiki-implementer` y `zeiki-auditor` en `C:\Users\Pc\.minimax\agents\`.
- El primer build tuvo 3 warnings de Gradle (Java 8 obsoleto), no se reprodujeron en builds subsiguientes (cache frío).
- Post-HDU-001 se creó también el agente `zeiki-reviewer` (code review 3 gates: clean code + security + architecture).

### HDU-EXPLORE-001 — Exploración del splash legacy (2026-07-29)
- PR #2 mergeado a main.
- Lee el splash del proyecto legacy `seiki_app` (read-only) y produce reporte con: causa del bug del cortado, qué se puede migrar tal cual, qué se descarta, qué se mejora.
- **Lección:** el legacy es **referencia, no verdad**. Lo que el legacy "ya tiene arreglado" no es vinculante sin verificación propia.
- Las HDU-EXPLORE-002 (decisiones de marca) y HDU-EXPLORE-003 (diseño del feature flag system) propuestas por el agente de la sesión **se descartan** por decisión del orquestador. Se diseñan las decisiones en specs directos.

### HDU-002 — Setup de Supabase (2026-07-30)
- PR #3 mergeado a main.
- Crea la base del backend de Supabase: tabla `app_tier_features` con RLS, seed inicial, edge function `feature-flags` que devuelve los flags, e inicialización del cliente Dart.
- **3 migraciones SQL idempotentes** aplicadas: schema + RLS, seed, GRANTs.
- **1 edge function** deployada con `--no-verify-jwt` (los flags son datos del producto, no del usuario).
- **Pipeline end-to-end verificado en Xiaomi:** 1 widget + 6 Deno + 4 integration (1 health + 4 RLS negativos + 1 edge function) tests pasan. `flutter analyze` 0, build APK OK.
- Crea `docs/runbooks/secrets.md` (runbook de gestión de secretos).
- **Cierres de auditoría (regla 7):** RLS verificada con tests negativos (commit `7c1df9d`), constraint `supabase_flutter` subido a `^2.13.0` (commit `074cc5d`), `conventions.md §12` corregido sobre formato de migraciones (commit `899f290`).
- **Bugs del implementer capturados en cleanup:** dep `integration_test` faltante en `pubspec.yaml`, formato de migraciones con guión bajo, GRANTs de Postgres faltantes. Todos resueltos antes del merge.
- **Aprobado por el zeiki-reviewer** (3 gates: clean code, security, architecture). 6 follow-ups no bloqueantes registrados.

### HDU-003 — Feature flag system del cliente (2026-07-30)
- PR #4 mergeado a main.
- Singleton `TierService` con cache en memoria, integración con la edge function `feature-flags` de Supabase, y enum `AppFeature` type-safe que la UI consulta sin strings sueltos.
- **7 commits en la rama `feat/hdu-003-feature-flag-system`:** spec → implementación → fix race condition → tests → 2 doc fixes (auditor) → 2 chores pre-merge (reviewer: dispose idempotente + governance de ADRs).
- **15 archivos modificados/creados** (4 nuevos en `lib/core/tiers/`, 1 en `lib/core/di/`, 5 integration tests, 3 unit tests, spec, `lib/main.dart` actualizado).
- **Pipeline local verificado en Xiaomi:** `flutter analyze` 0, 28/28 unit tests verde, **10/10 integration tests** verde (incluyendo `tier_service_sync_test` que valida la race condition fix), build APK OK.
- **Aprobado por el `zeiki-auditor`** — veredicto "Limpio con notas" (2 follow-ups de docs aplicados en el PR).
- **Aprobado por el `zeiki-reviewer`** — veredicto "🟡 Aprobado con cambios" (0 bloqueantes, 1 `issue:` de governance de ADRs resuelto inline + chores aplicados).
- **Governance de ADRs formalizada en el mismo PR:** `ADR-010` movido a `deprecated/`, nuevo `ADR-011-tier-service-getit-registration.md` documenta la decisión de registrar `TierService` en GetIt, `ADR-005` actualizado con la nueva excepción, tabla §13 de Target refrescada.
- **Bugs del implementer capturados en cleanup:** race condition con `dispose()` durante `refresh()` async (fix: guard `isClosed` antes de `_controller.add()`). Cubierto con 2 regression tests.
- **5 follow-ups no bloqueantes registrados en `.mavis/hdu.md`** (helper de `registerLazySingleton`, conectar `refreshInterval` con `Timer.periodic`, sanitizar `debugPrint`, loggear tipos no-bool en `_parseFlags`, CLI `feature_manifest`).

### HDU-004 — Navegación con go_router (2026-07-30)
- PR #5 mergeado a main.
- `GoRouter` con 4 rutas (`/splash`, `/onboarding`, `/login`, `/home`), 4 placeholders temporales con 2 botones cada uno, deep links con `zeiki://` funcionando, back stack funcional, state restoration al rotar.
- **6 commits en la rama `feat/hdu-004-go-router`:** spec → deps + intent filter → router + placeholders + handler → refactor main + matar placeholder viejo → tests → 2 chores pre-merge (auditor) → 1 chore pre-merge (reviewer: `_StubScreen` con `Directionality`).
- **14 archivos modificados/creados** (4 placeholders + 2 router files + 3 test files + `main.dart` + `pubspec.yaml` + `AndroidManifest.xml` + spec).
- **Pipeline local verificado en Xiaomi:** `flutter analyze` 0, **54/54 unit tests** verde (era 28, +27 nuevos), **2/2 integration tests** verde (`router_test.dart`), build APK OK.
- **Aprobado por el `zeiki-auditor`** — veredicto "Limpio con notas" (2 fixes cosméticos aplicados en el PR, 1 nota del cleanup diferida al paso 12).
- **Aprobado por el `zeiki-reviewer`** — veredicto "🟡 Aprobado con cambios" (0 bloqueantes, 1 pre-merge chore aplicado en el PR, 14 no bloqueantes registrados en `.mavis/hdu.md`).
- **Desviación del spec aprobada por Hugo:** AC3 / Plan técnico 1 decía `context.go(...)` en los placeholders; implementer usó `context.push(...)` con razón documentada (con `go` se rompe AC6 back). Decisión correcta, queda como lección + follow-up de patrón.
- **8 follow-ups no bloqueantes registrados en `.mavis/hdu.md`** (whitelist de hosts en deep link, sanitizar `errorBuilder`, restringir intent filter, mover `appRouter` a GetIt, automatizar integration test en CI, regla `push` vs `go`, `android:label` branding, renombrar test de "rotación").

### HDU-005 — Auth básico (email + Google) con router redirigido por sesión (2026-07-31)
- PR #6 mergeado a main.
- `AuthService` con API mínima (envuelve `supabase.auth`, sin que features importen Supabase directo), register con correo/Google, login con ambos métodos, home con sign out, sesión persistente vía Supabase, redirect del router usando `AuthService`. **Decisión A del review de HDU-004 implementada:** `appRouter` en GetIt como singleton lazy.
- **10 commits en la rama `feat/hdu-005-auth-basico`:** spec → deps → AuthService + handler + exception → router a GetIt + redirect → pantallas reales → wire main → integration test → runbook → 3 pre-merge (1 auditor + 1 fix bug test + 1 ADR-012).
- **26 archivos modificados/creados** + 1 nuevo ADR (ADR-012).
- **Pipeline local verificado en Xiaomi:** `flutter analyze` 0, **113/113 unit tests** verde (era 54, +59 nuevos), **3/3 integration tests** verde (`auth_flow_test.dart`), build APK OK.
- **Aprobado por el `zeiki-auditor`** — veredicto "Limpio con notas" (1 follow-up aplicado: `hasGoogleHandler` getter muerto eliminado en `63fd262`).
- **Aprobado por el `zeiki-reviewer`** — veredicto "🟡 Aprobado con cambios" (0 bloqueantes, 1 `issue:` de governance arquitectónico resuelto con ADR-012 + 8 no bloqueantes).
- **Governance de ADRs formalizada:** nuevo `ADR-012-router-location-and-getit.md` que documenta (a) router a GetIt (Decisión A) y (b) la excepción de imports `core → features` del router. Tabla §13 de Target refrescada.
- **Acciones de Hugo completadas:** SHA-1 del cert de debug, OAuth clients Android+Web, Google provider en Supabase dashboard.
- **Compromiso "no regresión" cumplido:** 0 tests de HDUs 001-004 rotos (verificado por el implementer antes de reportar "listo" y reverificado después de cada fix pre-merge).
- **Bug del implementer capturado en cleanup:** el integration test del implementer tenía un `authServiceGetter` que lanzaba excepción en vez de devolver un `AuthService` fake. Detectado en QA con Hugo, arreglado en `2da50b4` (registrar `_NullAuthServiceForTest` en GetIt).
- **5 follow-ups no bloqueantes registrados en `.mavis/hdu.md`** (quitar `GoRouterRefreshStream`, extraer `_FakeAuthService`, whitelist de hosts, migrar session token a `flutter_secure_storage`, HDU-005b biometría + timer).

### HDU-005b — Biometría + timer de inactividad (2026-07-31)
- PR #7 mergeado a main.
- `BiometricService` con API mínima (flag en `flutter_secure_storage` con KEY por usuario, defensa contra `PlatformException`), `InactivityTimer` con default de 5 min (constante en `AuthServiceConfig`), `BiometricActivationDialog` one-shot por sesión, `UnlockScreen` con 3 intentos antes de fallback, y **`authStateChanges` finalmente conectado al `GoRouter.refreshListenable`** (cierra el follow-up #1 de HDU-005 / ADR-012).
- **12 commits en la rama `feat/hdu-005b-biometria-timer`:** spec → deps → BiometricService → AuthServiceConfig → InactivityTimer + Monitor → BiometricActivationService + Dialog → UnlockScreen → router wireup + /unlock → MainActivity + USE_BIOMETRIC → wire dialog post-login → settings en Home → integration tests → update tests → 2 pre-merge (1 auditor cleanup + 1 move a services/ + reviewer's fixes).
- **23 archivos modificados/creados** + refactor: `BiometricService` movido de `lib/core/auth/` a `lib/core/services/` (Target §6 lo requiere explícitamente).
- **Pipeline local verificado en Xiaomi:** `flutter analyze` 0, **155/155 unit tests** verde (era 113 en HDU-005, +42 nuevos), **2/2 integration tests** verde (`biometric_flow_test.dart`), build APK OK.
- **Aprobado por el `zeiki-auditor`** — veredicto "Limpio con notas" (3 fixes pre-merge: parámetro YAGNI removido, 2 imports no usados, comentario del flash alineado).
- **Aprobado por el `zeiki-reviewer`** — veredicto "🟡 Aprobado con cambios" (0 bloqueantes, 1 `issue:` de Target §6 resuelto con move de `BiometricService` a `services/`, 3 stale comments eliminados, 1 tipo incorrecto corregido, 6 no bloqueantes).
- **Cambios en Android:** `MainActivity` cambiada a `FlutterFragmentActivity` (requerido por `local_auth` 2.x), permiso `USE_BIOMETRIC` agregado al manifest.
- **Acciones de Hugo completadas:** huella activada en el Xiaomi, integration test ejecutado.
- **Compromiso "no regresión" cumplido:** 0 tests de HDUs 001-005 rotos.
- **Desviaciones del spec (ambas aprobadas por lógica):**
  - **AC14:** "Usar contraseña" hace `signOut` + `/login` (no solo navegar). Spec original causaba loop. Documentado.
  - **Move de `BiometricService` a `services/`:** el spec lo ponía en `auth/`, contradiciendo Target §6. Se corrigió.
- **5 follow-ups no bloqueantes registrados en `.mavis/hdu.md`** (extraer `_FakeBiometricService` a helper, whitelist de "último userId" post-logout, migrar session token a `flutter_secure_storage`, pre-cargar cache de `BiometricService`, HDU-006).

### HDU-006 — Splash nuevo con branding + feature flag (2026-07-31)
- PR #8 mergeado a main.
- `SplashScreen` real con branding (logo `CustomPaint` con rotar/escalar, "ZEIKI" 72px bold con slide-in, "LOADING", 50 partículas flotando + 3 anillos en loop, barra de progreso morada), detrás de `AppFeature.splash` (Target §10). Versión del footer dinámica vía `package_info_plus ^8.0.2`. `SplashCubit` con `SplashState` sealed (`SplashLoading` → `SplashReady` → `SplashHidden`). `dispose()` idempotente.
- **16 commits en la rama `feat/hdu-006-splash-nuevo`:** spec → branding widgets → SplashCubit → SplashScreen wired al router → tests (8 widget + 12 cubit + 1 redirect + 1 integration) → runbook → 4 pre-merge (2 auditor + 2 reviewer v1/v3) + 1 fix fail-safe v3.
- **20 archivos modificados/creados** + 1 dep nueva (`package_info_plus`).
- **Pipeline local verificado en Xiaomi:** `flutter analyze` 0, **179/179 unit tests** verde (era 155 en HDU-005b, +24 nuevos), build APK OK.
- **Aprobado por el `zeiki-auditor`** — veredicto "Limpio con notas" (2 fixes pre-merge: dead `Transform.translate` + caracteres chinos en comentario).
- **Aprobado por el `zeiki-reviewer`** después de **3 rondas de review:**
  - v1 🔴 Rechazado: 1 bloqueante (`rootBundle.loadString('pubspec.yaml')` falla en producción).
  - v2 ✅ Aprobado: tras fix con `package_info_plus` (opción 2; la opción 1 — `PlatformDispatcher.applicationVersion` — no existe en Flutter 3.38.3, reconocido por el reviewer).
  - v3 ✅ Aprobado: tras fix con `TierService.isCacheLoaded()` y fail-safe "ON" cuando el cache está frío (resuelve pregunta no-bloqueante de v2 sobre comportamiento con red caída).
- **Decisiones de producto:**
  - **Sin tiempo mínimo** (splash dura lo que dure el redirect del router).
  - **Fail-safe "ON":** si el cache del `TierService` está frío (primera instalación, red caída), mostrar el splash por default. Solo se salta si el flag explícitamente está OFF en Supabase.
  - **Versión dinámica:** `package_info_plus` lee del `pubspec.yaml` cross-platform, sin riesgo de que el archivo no esté bundleado.
- **QA local en Xiaomi (Hugo):** cold start con app cerrada (force-stop) → splash aparece completo con footer `v0.1.0 · Developed by Zeiki Team` → después de ~3s fade-out → redirect → /login. Cierre + reapertura de la app → splash reaparece (cache cold, fail-safe ON).
- **Bug encontrado en QA post-merge (BUG-001):** Google Sign-In no completa el flujo. El selector de cuenta SÍ aparece, pero después de seleccionar una cuenta no pasa nada. NO fue detectado por los 113/113 tests de HDU-005 ni por las 3 rondas de review. Lección guardada en memoria #8.
- **5 follow-ups no bloqueantes** (registrados por el reviewer v3): redundancia de tests, nit de naming, mismatch fake vs real en `isCacheLoaded`, edge case de operador olvidando seedear flag, `debugEnabled` no activa fail-safe.

## 🔜 Próximos pasos sugeridos (secuencia decidida con Hugo)

- **Decidir la siguiente unidad de trabajo.** Opciones:
  - **HDU-007b / BUG-002b (bugfix):** "Revisa tu correo" no aparece después de crear cuenta en `register_screen.dart`. Snippet chico (~30 min), aislado a la pantalla de register + mostrar SnackBar + navegar a /login. Sale cuando Hugo lo pida.
  - **HDU-008 (feature nueva):** descarga de CFDIs del SAT, onboarding, fiscal, o clientes.
  - **Polish visual + branding de pantallas** (login, register, home sin identidad de marca Zeiki).
  - **Pausa / descanso.**

## 🐛 Follow-ups activos (de HDUs cerradas)

| # | Origen | Descripción | Prioridad | Estado |
|---|--------|-------------|-----------|--------|
| 1 | HDU-001 | `zeiki-reviewer` creado (code review 3 gates). | media | **completado** |
| 2 | HDU-001 | Si vuelven a salir warnings de Gradle Java 8, abrir HDU para subir target a Java 11/17. | baja | watch (no se reprodujeron) |
| 3 | HDU-001 | Política: "deps se actualizan solo con trigger concreto, no en revisión periódica". Triggers: CVE, stack upgrade forza incompatibilidad, feature necesita API, autor abandona la dep, conflicto con otras deps. NO son triggers: "hay updates disponibles", "es buena práctica", "pasaron X meses". | baja | **cerrado con política (2026-08-03) — ver `conventions.md §11 "Cuándo actualizar una dep (triggers)"`** |
| 4 | HDU-001 | Documentar `assets/.env.example` no se incluye como asset cuando se conecte Supabase (usar `--dart-define-from-file`). | media | **completado (housekeeping bundle #4)** |
| 5 | HDU-EXPLORE-001 | Splash nuevo depende de feature flags + go_router + auth. No implementar antes de tener esos 3. | alta | bloqueante para HDU-006 |
| 6 | HDU-002 | `Future.delayed(1s)` en `main.dart` es residuo de HDU-001. Quitarlo cuando llegue HDU-004 (go_router) o HDU-005 (auth). | baja | pendiente |
| 7 | HDU-002 | Edge function usa `service_role` + `--no-verify-jwt`. OK hoy (flags del producto), revisar cuando se agreguen flags por usuario. | media | **observation cerrada (housekeeping bundle #4): ya documentado en `secrets.md` + `specs/HDU-002-supabase-setup.md`. Revisar cuando se agreguen flags por usuario.** |
| 8 | HDU-002 | Refactor: extraer `setUpAll` duplicado en 3 integration tests a helper compartido cuando se agreguen más tests en HDU-003. | baja | **completado** (test 8 dedicado) |
| 9 | HDU-003 | Helper `registerLazySingletonIfNotRegistered<T>(factory)` para no repetir el patrón en futuros servicios (`AuthService`, `BiometricService`, etc.). | baja | **completado (housekeeping bundle #4)** |
| 10 | HDU-003 | Conectar `tier_service_config.refreshInterval` con `Timer.periodic` cuando llegue la HDU de refresh automático. | baja | pendiente (HDU futura) |
| 11 | HDU-003 | `debugPrint` con la excepción en `refresh()` — sanitizar cuando el fetcher reciba más contexto (HDU-005 con auth). | baja | **completado (housekeeping bundle #1)** |
| 12 | HDU-003 | `_parseFlags` ignora tipos no-bool silenciosamente — loggear con `debugPrint` cuando se ignore un valor. | baja | **completado (housekeeping bundle #2)** |
| 13 | HDU-003 | CLI `feature_manifest` (Target §15, aspiración) — genera doc auto-generada a partir del enum `AppFeature`. | baja | aspiración (Target §15) |
| 14 | HDU-004 | Whitelist de hosts válidos para `zeikiUriToPath`. Crece naturalmente con HDU-005/006. | baja | **completado (housekeeping bundle #3)** |
| 15 | HDU-004 | Sanitizar `state.uri` en `errorBuilder` del router. Bajo riesgo hoy, escala cuando crezca el número de rutas. | baja | **completado (housekeeping bundle #3)** |
| 16 | HDU-004 | Restringir intent filter `zeiki://` a hosts específicos en `AndroidManifest.xml`. Mismo motivo que #14. | baja | **completado (housekeeping bundle #3)** |
| 17 | HDU-004 | Mover `appRouter` a GetIt como singleton lazy. Necesario cuando llegue HDU-005 (auth con `redirect:`) y `AuthService`. | media | **completado (se hizo en HDU-005, PR #6)** |
| 18 | HDU-004 | Cobertura del integration test en CI: back nativo + rotación + deep link end-to-end con `adb` automatizados. | baja | **en progreso (1/? — housekeeping #18 part 1: codemagic.yaml mínimo creado, falta activar en dashboard y扩展). Ver `docs/runbooks/codemagic-setup.md`.** |
| 32 | HDU-007 cleanup | Limpieza de 9 stubs `_FakeAuthService` que aún tienen `String? emailRedirectTo` en el override de `signUpWithEmail` (incoherente con la firma real ahora). En Dart es válido (subtipo), `flutter analyze` no se queja, pero la firma debería reflejar la realidad. | baja | pendiente (housekeeping bundle futuro) |
| 19 | HDU-004 | Regla "push para detail/sheet, go para tab/sección" — documentar como patrón canónico cuando haya más navegación. | baja | **completado (housekeeping bundle #1)** |
| 20 | HDU-004 | `android:label="zeiki"` en minúsculas (debería ser "Zeiki" con Z mayúscula). Pre-existente a HDU-001. | baja | **completado (housekeeping bundle #1)** |
| 21 | HDU-004 | Renombrar test de "rotación" a "router conserva ruta tras rebuild" — el nombre actual es engañoso. | baja | **obsoleto** (el test nunca se llamó "rotación", ya era "state restoration está habilitado (AC7)" en `widget_test.dart:148`) |
| 22 | **HDU-005** | **BUG:** Google Sign-In no completa el flujo — selector de cuenta aparece, seleccionar cuenta → no pasa nada. Detectado en QA post-HDU-006 (no en test). 113/113 tests + 3 rondas de review no lo cacharon. | **alta** | **completado (BUG-001 cerrada, PR #9)** |
| 23 | HDU-006 | Redundancia entre grupos "cache cold" y "feature flag OFF" en `splash_screen_test.dart`. | baja | **completado (housekeeping bundle #1)** |
| 24 | HDU-006 | Nit de naming en el grupo "cache cold" (un test no es realmente cold porque setea un flag). | baja | **completado (housekeeping bundle #1)** |
| 25 | HDU-006 | Fake `_FakeTierService.isCacheLoaded()` retorna `flags.isNotEmpty`; el real retorna `_cache.isNotEmpty \|\| _config.debugEnabled`. Mismatch pequeño. | baja | **completado (housekeeping bundle #1)** |
| 26 | HDU-006 | Edge case: si el operador olvidó seedear `splash` en Supabase, el splash se salta. Documentar en runbook. | baja | **completado (housekeeping bundle #1)** |
| 27 | HDU-006 | Wrapper de `package_info_plus` en `core/services/` — se usa directo en `splash_screen.dart`. Si aparece un segundo callsite, extraer. | baja | **observation cerrada (housekeeping bundle #4): confirmado 1 callsite (`splash_screen.dart`). Sigue como "watch" — extraer cuando aparezca 2º callsite.** |
| 28 | HDU-006 | Test del `catch (_)` de `_loadAppVersion` — coverage gap. Si alguien borra el try/catch, ningún test lo detecta. | baja | **completado (housekeeping bundle #1, documentado como no-testeable)** |
| 29 | **Lección #8 (memoria)** | **Tests verde NO es app funcionando. QA en device real es obligatorio antes de merge para cualquier HDU con OAuth / push / deep links / biometría nativa / pagos.** | alta | regla operativa (cross-project) |
| 30 | **BUG-001** | **`AuthService.signOut()` también desloguea de Google** — sin esto, el chooser "recordaba" la cuenta después del signOut. | **alta** | **completado (housekeeping bundle #1)** |
| 31 | **BUG-001** | **Convención "OAuth Client IDs NO son secretos, van en `.env`"** documentada en `conventions.md`. | media | **completado (housekeeping bundle #1)** |

## 📚 Lecciones aprendidas recientes

- **2026-07-29 — "Si los planos lo dicen, no se pregunta, se hace":** el spec de HDU-001 omitió `lib/core/tiers/`, pero Target §6 y ADR-010 la mencionan. No se pregunta al usuario, se corrige el spec y se crea la carpeta. Lección completa en `memory/MEMORY.md` (agente).
- **2026-07-29 — "Lo que el auditor marca, se hace":** las 5 notas del `zeiki-auditor` no se "registran como follow-up", se aplican en el momento (o se descartan con razón explícita). 2 aplicadas en este cleanup, 2 registradas como aprendizaje, 1 zona gris documentada en `conventions.md`.
- **2026-07-29 — "El legacy es referencia, no verdad":** la HDU-EXPLORE-001 reportó que el bug del cortado "ya estaba arreglado en el legacy". Eso es lo que el código legacy DICE, no es verdad verificada. **Lección:** tratar el legacy como referencia, no como fuente de verdad. Lo que el legacy afirma sobre sus propios bugs debe verificarse antes de aceptarlo como base.

## 🧹 Housekeeping bundle #3 — deep link hardening (2026-07-31)

- **Tipo:** chore (bundle chico defensivo)
- **PR:** [#12](https://github.com/navaworkingspaces-collab/zeiki/pull/12) — mergeado a `main` (commit `68e13ae`)
- **Cambios (3 fixes relacionados con deep links):**
  1. **#14** Whitelist de hosts válidos en `zeikiUriToPath` (`_allowedDeepLinkHosts` con 6 hosts: splash, onboarding, login, register, unlock, home). Host fuera del whitelist → `debugPrint` + return `null`. Antes aceptaba cualquier host (`zeiki://admin`).
  2. **#15** Nuevo helper `sanitizeUriForDisplay(uri, maxLength: 50)` usado en el `errorBuilder` del router. Trunca a 50 chars. Antes mostraba `state.uri.toString()` directo, filtrando query params arbitrarios.
  3. **#16** `AndroidManifest.xml`: intent filter declara 6 `<data android:host="..." />` explícitos en vez de un `<data android:scheme="zeiki" />` genérico. Defensa en profundidad: el SO no muestra Zeiki en el chooser para hosts no whitelisted.
- **Pipeline final:** `flutter analyze` 0, `flutter test` **191/191** verde (era 182, +9 tests: 5 en `zeikiUriToPath`, 1 en `wireDeepLinks`, 3 en `sanitizeUriForDisplay`).
- **QA en device real:** no requerida. Los 3 cambios son hardening defensivo — el comportamiento observable para el usuario en flujos válidos es idéntico.
- **Backlog:** 13 → 10 follow-ups activos. 0 HDUs activas, 0 BUGs activas, 0 PRs abiertos, 0 crons. `main` deployable.
- **Regla de mantenimiento (3 lugares deben mantenerse en sync):** `AppRoute` enum en `app_router.dart`, `_allowedDeepLinkHosts` en `app_links_handler.dart`, `<data android:host="..." />` en `AndroidManifest.xml`. Si agregas un valor a `AppRoute`, agrega el host en los otros 2 lugares. Los tests documentan el contrato.
- **Lección:** "defensa en profundidad" no es paranoia. El whitelist (#14) + el manifest (#16) + el sanitize (#15) son 3 capas que reducen la superficie de ataque. Si una falla, las otras 2 siguen protegiendo.

## 🧹 Housekeeping bundle #4 — quick wins (2026-07-31)

- **Tipo:** chore (bundle chico mixto)
- **PR:** [#13](https://github.com/navaworkingspaces-collab/zeiki/pull/13) — mergeado a `main` (commit `81cf154`)
- **Cambios (4 follow-ups):**
  1. **#9** Helper `registerLazySingletonIfNotRegistered<T>(factory)` en `service_locator.dart`. Centraliza el patrón idempotente `if (!getIt.isRegistered<T>()) { getIt.registerLazySingleton<T>(...); }` que se repetía 4 veces. -16 líneas netas. 3 tests nuevos.
  2. **#4** Doc `--dart-define-from-file` en `secrets.md` (sección "Inyección de variables en build (CI)") + bloque "DOS MODOS DE USO" en `assets/.env.example`. Diferencia dev vs CI + comando exacto.
  3. **#7** Observation cerrada: `service_role` + `--no-verify-jwt` ya documentado en `secrets.md` + spec. Se cierra con nota "revisar cuando se agreguen flags por usuario".
  4. **#27** Observation cerrada: wrapper de `package_info_plus` sigue con 1 callsite (`splash_screen.dart`). Se cierra con nota "extraer cuando aparezca 2º callsite".
- **Pipeline final:** `flutter analyze` 0, `flutter test` **194/194** verde (era 191, +3 del helper #9).
- **QA en device real:** no requerida. Sin cambios de comportamiento observables.
- **Backlog:** 10 → 6 follow-ups activos. 0 HDUs activas, 0 BUGs activas, 0 PRs abiertos, 0 crons. `main` deployable.
- **Notas:**
  - El bundle #4 es el primero con un refactor de código (#9) que toca la infraestructura de DI. El comportamiento es idéntico (cubierto por el test de idempotencia existente + 3 tests nuevos del helper).
  - Los 6 que quedan son más "duros": #3 (deps update riesgoso), #10 (refresh interval es feature, no chore), #13 (CLI feature_manifest aspiración), #18 (CI/CD grande). El próximo bundle tendrá menos quick wins, así que vale la pena pensar en HDUs de feature.

## 🧹 Housekeeping bundle #5 — deps update part 1 (2026-08-03)

- **Tipo:** chore (serie de bumps, 1 dep por PR)
- **PR:** [#14](https://github.com/navaworkingspaces-collab/zeiki/pull/14) — mergeado a `main` (commit `e3c3e66`, Fast-forward)
- **Dep:** `package_info_plus: ^8.0.2` → `^9.0.1`
- **Análisis del changelog:**
  - 8.3.1 → 9.0.0: cambio de compile SDK en Android + requisito AGP >= 8.12.1.
  - 9.0.0 → 10.0.0: **NO actualizable** sin subir Flutter (10.x requiere 3.41.6+, proyecto en 3.38.3).
- **Verificación:**
  - `flutter analyze`: 0 issues.
  - `flutter test`: 194/194 verde.
  - `flutter build apk --debug`: OK (157 MB). El proyecto tiene AGP 8.11.1 y 9.0.0 dice requerir 8.12.1+; en la práctica compila sin tocar AGP.
- **Sin QA en device real:** el cambio de dep no afecta comportamiento observable (mismo API, mismo valor devuelto en el footer del splash).
- **Próximas deps (8 más):** flutter_bloc 8→9, flutter_dotenv 5→6, flutter_secure_storage 9→10, get_it 7→9, go_router 14→17, google_sign_in 6→7, local_auth 2→3, app_links 7→7.2 (minor). Cada una en su propio PR siguiendo este patrón.
- **Notas:**
  - El patrón "1 dep por PR" permite rollback granular si algo se rompe.
  - Hugo aprobó este enfoque después de los bundles #1-#4 (que eran 3-10 quick wins por bundle). Las deps son más invasivas, así que el tradeoff es diferente: un bundle con 9 cambios de versión es muy difícil de revertir si algo se rompe.

## 📜 Cierre del follow-up #3 con política de actualización de deps (2026-08-03)

- **Tipo:** doc (cierre de follow-up con política operativa)
- **PR:** [#15](https://github.com/navaworkingspaces-collab/zeiki/pull/15) — pendiente de merge
- **Cambio:** política de cuándo actualizar deps, documentada en `conventions.md §11` (nueva subsección "Cuándo actualizar una dep (triggers)").
- **Triggers HARD (obligatorio, no se discute):**
  1. **CVE de seguridad publicado** que afecte a la versión actual.
  2. **Stack upgrade fuerza incompatibilidad** (Flutter/Dart suben y la dep no soporta).
  3. **Una HDU/feature nueva necesita una API específica** de la versión mayor disponible.
- **Triggers SOFT (recomendado, no obligatorio):**
  4. La versión actual ya no recibe parches del autor (deprecation announced, repo archivado, último release > 2 años).
  5. Compatibilidad con el resto del stack degradada (conflicto de versiones con otras deps).
- **NO son triggers válidos:** "hay updates disponibles", "es buena práctica estar actualizado", "pasaron X meses", "el review sugirió actualizar sin contexto".
- **Anti-patrón documentado:** NO listar deps outdated como follow-up de housekeeping rutinario.
- **Implicación operacional para Mavis (orquestador):**
  - NO escanear `flutter pub outdated` en cada bundle.
  - NO proponer bumps preventivos sin trigger.
  - SÍ reportar inmediatamente si detecta un CVE conocido.
  - SÍ verificar deps cuando (a) Mavis planea HDU con feature nueva, (b) Mavis hace stack upgrade, (c) el usuario pregunta explícitamente.
- **Notas:**
  - Hugo pidió esta política explícitamente: "no me los pases como pendientes aunque no sean necesarios, me confunde; pero tampoco quiero que no los pases, deben aparecer cuando deben".
  - El bundle #5 part 1 (`package_info_plus` 8.3.1 → 9.0.1) queda como el único bump preventivo del proyecto. Se hizo para validar el proceso "1 dep por PR", no porque hubiera trigger HARD. Es la **excepción** que confirma la regla.
- **Backlog:** 5 → 4 (#3 desaparece como pendiente, reemplazado por la política).

## 🧹 Housekeeping #18 — CI setup part 1 (2026-08-03)

- **Tipo:** chore (CI/CD setup)
- **PR:** [#16](https://github.com/navaworkingspaces-collab/zeiki/pull/16) — mergeado a `main` (commit `1de56fc`, Fast-forward)
- **Cambios (4 archivos, +190/-2):**
  1. **`codemagic.yaml`** (NUEVO, raíz) — workflow `test` con 3 scripts: `flutter pub get`, `flutter analyze`, `flutter test`. Triggers: push a main + pull_request. Cache de `~/.pub-cache` y `.dart_tool`.
  2. **`docs/runbooks/codemagic-setup.md`** (NUEVO) — runbook paso a paso para que Hugo active el pipeline en codemagic.io. Incluye troubleshooting.
  3. **`docs/architecture/target-architecture.md`** — `codemagic.yaml` de "Pendiente" a "Creado".
  4. **`docs/git.md`** — status del deploy de edge functions de "TBD" a "Parcial" (test workflow creado, deploy sigue TBD).
- **Acción de Hugo pendiente:**
  1. Crear cuenta en codemagic.io (login con GitHub).
  2. Agregar el repo `navaworkingspaces-collab/zeiki`.
  3. Code Magic detecta `codemagic.yaml` automáticamente.
  4. Click en workflow `test` → "Start new build" → seleccionar `main` → "Start build".
  5. Verificar que pasa (5-8 min la primera vez).
- **Lo que NO está (sale en HDU futura):**
  - Build de APK debug/release.
  - Deploy a Firebase App Distribution (sin USB).
  - Integration tests con `adb` (back nativo, rotación, deep links).
  - Coverage report.
  - Deploy de edge functions de Supabase.
- **Notas:**
  - El setup mínimo valida que el pipeline funciona antes de invertir 2 días en扩展. Si aporta valor, las siguientes partes salen en HDUs diferentes.
  - Plan gratis de Code Magic es suficiente para 1 dev + 1 repo público. Si el repo es privado y excede minutos, evaluar plan de pago.
  - Workflow NO usa secrets (los tests no tocan Supabase real). Cuando se agregue deploy a Firebase, ahí se necesitan secrets documentados en el runbook.
- **Backlog:** #18 de "pendiente" a "en progreso (1/?)" — Hugo debe activar el pipeline antes de seguir.
