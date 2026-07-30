# Current State — Zeiki

> **Snapshot rápido del estado del proyecto.** Se actualiza en el cleanup (paso 12) de cada HDU cerrada. Para el detalle de una HDU específica, ver `specs/HDU-XXX-*.md`. Para el histórico, ver `.mavis/hdu.md`.

**Última actualización:** 2026-07-30 (post-HDU-003 cerrada).

---

## 📍 Dónde estamos

- **Fase:** 1 (MVP).
- **Última HDU cerrada:** HDU-003 — Feature flag system del cliente.
- **HDUs activas:** ninguna.
- **Rama `main`:** deployable.
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

## 🔜 Próximos pasos sugeridos (secuencia decidida con Hugo)

- **HDU-004:** `go_router` + navegación básica (rutas reales: splash → onboarding → login → home). Depende de HDU-003 ✅.
- **HDU-005:** Identidad / auth básico (email + Google + biometría, según Target §15).
- **HDU-006:** Splash nuevo, con feature flag + go_router + auth mínimo. Spec redactado con base en el reporte de HDU-EXPLORE-001 (qué migrar, qué descartar, qué mejorar).

## 🐛 Follow-ups activos (de HDUs cerradas)

| # | Origen | Descripción | Prioridad | Estado |
|---|--------|-------------|-----------|--------|
| 1 | HDU-001 | `zeiki-reviewer` creado (code review 3 gates). | media | **completado** |
| 2 | HDU-001 | Si vuelven a salir warnings de Gradle Java 8, abrir HDU para subir target a Java 11/17. | baja | watch (no se reprodujeron) |
| 3 | HDU-001 | 27 paquetes de `pub get` con updates disponibles. NO actualizar a ciegas — HDU dedicada de "actualizar deps base" cuando se decida. | baja | pendiente |
| 4 | HDU-001 | Documentar `assets/.env.example` no se incluye como asset cuando se conecte Supabase (usar `--dart-define-from-file`). | media | en próxima HDU de Identidad |
| 5 | HDU-EXPLORE-001 | Splash nuevo depende de feature flags + go_router + auth. No implementar antes de tener esos 3. | alta | bloqueante para HDU-006 |
| 6 | HDU-002 | `Future.delayed(1s)` en `main.dart` es residuo de HDU-001. Quitarlo cuando llegue HDU-004 (go_router) o HDU-005 (auth). | baja | pendiente |
| 7 | HDU-002 | Edge function usa `service_role` + `--no-verify-jwt`. OK hoy (flags del producto), revisar cuando se agreguen flags por usuario. | media | observation (Target §13.1) |
| 8 | HDU-002 | Refactor: extraer `setUpAll` duplicado en 3 integration tests a helper compartido cuando se agreguen más tests en HDU-003. | baja | **completado** (test 8 dedicado) |
| 9 | HDU-003 | Helper `registerLazySingletonIfNotRegistered<T>(factory)` para no repetir el patrón en futuros servicios (`AuthService`, `BiometricService`, etc.). | baja | pendiente (HDU futura) |
| 10 | HDU-003 | Conectar `tier_service_config.refreshInterval` con `Timer.periodic` cuando llegue la HDU de refresh automático. | baja | pendiente (HDU futura) |
| 11 | HDU-003 | `debugPrint` con la excepción en `refresh()` — sanitizar cuando el fetcher reciba más contexto (HDU-005 con auth). | baja | observation |
| 12 | HDU-003 | `_parseFlags` ignora tipos no-bool silenciosamente — loggear con `debugPrint` cuando se ignore un valor. | baja | pendiente (HDU futura) |
| 13 | HDU-003 | CLI `feature_manifest` (Target §15, aspiración) — genera doc auto-generada a partir del enum `AppFeature`. | baja | aspiración (Target §15) |

## 📚 Lecciones aprendidas recientes

- **2026-07-29 — "Si los planos lo dicen, no se pregunta, se hace":** el spec de HDU-001 omitió `lib/core/tiers/`, pero Target §6 y ADR-010 la mencionan. No se pregunta al usuario, se corrige el spec y se crea la carpeta. Lección completa en `memory/MEMORY.md` (agente).
- **2026-07-29 — "Lo que el auditor marca, se hace":** las 5 notas del `zeiki-auditor` no se "registran como follow-up", se aplican en el momento (o se descartan con razón explícita). 2 aplicadas en este cleanup, 2 registradas como aprendizaje, 1 zona gris documentada en `conventions.md`.
- **2026-07-29 — "El legacy es referencia, no verdad":** la HDU-EXPLORE-001 reportó que el bug del cortado "ya estaba arreglado en el legacy". Eso es lo que el código legacy DICE, no es verdad verificada. **Lección:** tratar el legacy como referencia, no como fuente de verdad. Lo que el legacy afirma sobre sus propios bugs debe verificarse antes de aceptarlo como base.
