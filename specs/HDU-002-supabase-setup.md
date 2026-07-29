# HDU-002 — Setup de Supabase para Zeiki

**Tipo:** chore
**Prioridad:** alta
**Estado:** pendiente
**Fecha:** 2026-07-29
**Sistemas externos involucrados:** Supabase (Postgres + Edge Functions + Auth)
**Dominio(s):** ninguno (es transversal — sienta la base del backend para todos los dominios)

---

## Check de entendimiento (3 líneas)

- Lo que quieres: dejar listo el backend de Supabase de Zeiki (la tabla `app_tier_features` con su RLS, seed inicial, y la edge function stub que devuelve los flags).
- Vas a saber que está bien cuando: pueda correr un `SELECT` desde el cliente y reciba los flags de vuelta sin errores.
- Esto NO se va a hacer: no se va a implementar el feature flag system del cliente (eso es HDU-003), ni auth de usuarios, ni el splash.

---

## Problema / Motivación

El proyecto Supabase de Zeiki ya está creado (Hugo, 2026-07-29) con `assets/.env` configurado con `SUPABASE_URL` y `SUPABASE_ANON_KEY`. Pero el backend está **vacío**: no hay tablas, no hay RLS, no hay edge functions, no hay nada que el cliente pueda consultar.

Esta HDU es la base del backend. Sin ella, la HDU-003 (feature flag system del cliente) no puede sincronizar, y todas las features que necesitan gating (incluido el splash) quedan bloqueadas.

El proyecto Supabase es **nuevo y separado del legacy** (decisión de Hugo, alineada con ADR-009 — reescritura desde cero). NO se heredan tablas, RLS, ni edge functions del legacy `seiki_app`. Se diseña desde cero con la arquitectura actual.

---

## Criterios de aceptación

- [ ] **AC1:** La tabla `app_tier_features` existe en el schema `public` con las columnas: `id` (uuid PK), `feature_key` (text NOT NULL UNIQUE), `tier` (text NOT NULL), `enabled` (boolean NOT NULL DEFAULT false), `created_at` (timestamptz NOT NULL DEFAULT now()), `updated_at` (timestamptz NOT NULL DEFAULT now()), con `UNIQUE(feature_key, tier)`.
- [ ] **AC2:** La tabla tiene **RLS habilitada**. Política de SELECT para `anon` y `authenticated` (los flags son datos públicos del producto, cualquier cliente puede leerlos). Política de INSERT/UPDATE/DELETE solo para `service_role`.
- [ ] **AC3:** El seed inicial tiene al menos el feature `splash` habilitado para los tiers `free` y `pro` (los tiers reales se definirán cuando haya auth).
- [ ] **AC4:** La edge function `feature-flags` existe en `supabase/functions/feature-flags/index.ts`, está deployada, y devuelve un JSON con los flags actuales (formato: `{ "flags": { "splash": true, ... } }`).
- [ ] **AC5:** El cliente puede hacer un `SELECT` a la tabla `app_tier_features` usando `supabase_flutter` con las credenciales del `.env` y recibe filas (verificable por un integration test).
- [ ] **AC6:** La edge function `feature-flags` es invocable desde el cliente (con `supabase.functions.invoke('feature-flags')`) y devuelve el JSON esperado.
- [ ] **AC7:** Las migraciones SQL son **idempotentes** (`IF NOT EXISTS` en CREATE, `ON CONFLICT DO NOTHING` en INSERT, siguiendo `conventions.md §12`).
- [ ] **AC8:** El cliente puede **arrancar** sin crashear: `supabase_flutter` se inicializa correctamente con las credenciales del `.env`, aunque la BD esté vacía.
- [ ] **AC9:** Ningún secreto se commitea al repo. `assets/.env` está en `.gitignore`. La `service_role_key` se configura como secret de Supabase y NUNCA se usa en el cliente.
- [ ] **AC10:** `flutter analyze` 0 warnings, `flutter test` pasa, `flutter build apk --debug` compila. La edge function pasa `deno check index.ts`.

---

## Archivos afectados

**Nuevos:**
- `supabase/migrations/YYYYMMDD_HHMMSS_create_app_tier_features.sql` — schema + RLS.
- `supabase/migrations/YYYYMMDD_HHMMSS_seed_app_tier_features.sql` — seed inicial (idempotente).
- `supabase/functions/feature-flags/index.ts` — edge function stub (Deno).
- `supabase/functions/feature-flags/deno.json` — config de Deno.
- `lib/core/supabase/supabase_client.dart` — inicialización de `supabase_flutter` (en `lib/core/` porque es transversal).
- `test/integration/supabase_health_test.dart` — test de health check (integration test, lee de `.env`).
- `test/integration/feature_flags_function_test.dart` — test de invocación de edge function.

**Modificados:**
- `lib/main.dart` — agregar `await Supabase.initialize(...)` antes de `runApp` (sigue siendo placeholder, pero ahora con Supabase real).
- `pubspec.yaml` — confirmar que `supabase_flutter` está declarado (ya lo está desde HDU-001, no requiere cambio).
- `docs/runbooks/secrets.md` — registrar la rotación de la `service_role_key` de Supabase (no el valor, el procedimiento).

**Eliminados:** ninguno.

---

## Plan técnico (pasos verificables)

1. **Crear la migración SQL de schema.** Archivo `supabase/migrations/20260729_HHMMSS_create_app_tier_features.sql`. Contenido: CREATE TABLE con las columnas del AC1, índices en `feature_key` y `(feature_key, tier)`. Idempotente con `IF NOT EXISTS`.
2. **Aplicar la migración.** Hugo corre `supabase db push` desde su terminal (o la aplica manualmente desde el panel de Supabase → SQL Editor). El implementer **NO** debe asumir acceso al proyecto Supabase — Hugo lo hace.
3. **Habilitar RLS y crear políticas.** En la misma migración (o una segunda): `ALTER TABLE public.app_tier_features ENABLE ROW LEVEL SECURITY;` + `CREATE POLICY ...` para SELECT (anon + authenticated) y para ALL (service_role only). Idempotente con `DROP POLICY IF EXISTS` antes de crear.
4. **Crear la migración de seed.** Archivo `supabase/migrations/20260729_HHMMSS_seed_app_tier_features.sql`. INSERT con `ON CONFLICT (feature_key, tier) DO NOTHING` para que sea idempotente. Inserta `('splash', 'free', true)` y `('splash', 'pro', true)`.
5. **Aplicar el seed.** Hugo corre de nuevo `supabase db push` o lo aplica manual.
6. **Crear la edge function `feature-flags`.** Deno + TypeScript. Hace un SELECT a la tabla, devuelve JSON con la forma `{ "flags": { "<feature_key>": <enabled>, ... } }`. Sin auth (los flags son públicos). Idempotente al deployar con `supabase functions deploy feature-flags`.
7. **Deploy de la edge function.** Hugo corre `supabase functions deploy feature-flags --no-verify-jwt` (los flags son públicos, no requieren JWT).
8. **Configurar la `service_role_key` como secret de Supabase.** Hugo corre `supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<valor>` (sin pasar el valor por chat — Hugo lo lee de su password manager). Esto es para uso futuro de la edge function si necesita escribir.
9. **Inicializar `supabase_flutter` en el cliente.** En `lib/core/supabase/supabase_client.dart`, función `initSupabase()` que lee `SUPABASE_URL` y `SUPABASE_ANON_KEY` del `.env` con `flutter_dotenv` y llama `Supabase.initialize(url: ..., anonKey: ...)`. Se llama desde `lib/main.dart` antes de `runApp`.
10. **Test de health check (cliente).** `test/integration/supabase_health_test.dart` — test que hace `await supabase.from('app_tier_features').select()` y verifica que devuelve al menos 1 fila (el seed del AC3).
11. **Test de edge function (cliente).** `test/integration/feature_flags_function_test.dart` — test que llama `await supabase.functions.invoke('feature-flags')` y verifica que el JSON tiene la forma `{ "flags": { "splash": true } }`.
12. **Verificar pipeline local:** `flutter analyze && flutter test && flutter build apk --debug`. Para Deno: `deno check supabase/functions/feature-flags/index.ts`.
13. **Commit con Conventional Commits:** `feat(supabase): setup app_tier_features table, RLS, edge function, and client init [HDU-002]`.

---

## Tests a escribir (basado en matriz de criticidad)

| Componente | Criticidad | Tipo de test mínimo | Notas |
|------------|------------|---------------------|-------|
| Schema de la tabla | Alta | Verificación manual (migración idempotente + SELECT desde panel) | Lo valida el AC1 y AC7. |
| RLS de la tabla | **Muy alta** (afecta seguridad) | Test de integración que verifica que `anon` puede SELECT pero NO puede INSERT/UPDATE/DELETE. | TDD crítico aquí. |
| Edge function | Alta | Unit test Deno + integration test desde cliente. | Stub: solo lee, no escribe. |
| Inicialización del cliente | Alta | Test de integración: app arranca con Supabase real, sin crashear. | AC8. |
| Health check | Media | Integration test (puede ser flaky si Supabase está caído, marcar con `@Tags(['integration'])`). | AC5. |
| App sigue compilando y linter pasa | Alta | Pipeline. | AC10. |

Referencia: §11 de Target Architecture (matriz de criticidad).

---

## Fuera de scope

- Implementar el **feature flag system del cliente** (TierService con cache local + sync periódico) — eso es HDU-003.
- Auth de usuarios (magic link, OAuth, biometría) — eso es HDU-004.
- El splash — HDU-005.
- Cualquier otra feature del MVP listada en Target §15.
- Tests de carga / performance de la edge function (llegan en Fase 3).
- Documentación auto-generada de la API de la edge function.

---

## Riesgos

- **El implementer NO tiene acceso al proyecto Supabase de Zeiki.** Las migraciones SQL y los deploys de edge functions los tiene que aplicar Hugo manualmente. Si el implementer intenta hacerlo solo, va a fallar. **Mitigación:** el spec asume que Hugo aplica las migraciones y los deploys, y el implementer solo prepara los archivos.
- **La `service_role_key` NO debe quedar en código ni en logs.** Mitigación: el spec la configura como secret de Supabase con `supabase secrets set`, no la pasa al cliente. El cliente solo usa la `anon_key` (pública).
- **Las migraciones SQL deben ser idempotentes.** Si Hugo las aplica dos veces (ej. por error), NO deben duplicar tablas ni datos. Mitigación: conventions §12 + tests de re-aplicación.
- **El `flutter_dotenv` se carga como asset, pero el `.env` real está en `.gitignore`.** Si el asset del `.env` no se incluye en el build, la app crashea al iniciar. **Mitigación:** documentar en conventions §10 que el `.env` real se inyecta en build con `--dart-define-from-file`, no como asset. **PERO para dev**, sí va como asset (asumiendo que Hugo crea el `.env` antes de `flutter run`).
- **Si la edge function devuelve un JSON con forma distinta a la esperada, el cliente falla.** Mitigación: el test de integración (AC6) verifica la forma exacta.
- **El test de integración puede ser flaky si Supabase está lento.** Mitigación: marcar con `@Tags(['integration'])` y excluirlos del `flutter test` por default. CI los corre en un job separado.

---

## Review checklist

- [ ] Cumple con §1-§3 de Target Architecture (principios, atributos, restricciones).
- [ ] No introduce anti-patrones (§14 de Target).
- [ ] Clean code (conventions §2: nombres, funciones chicas, comentarios del porqué).
- [ ] Security (conventions §6: RLS habilitada, sin secrets en código, sin secrets en logs, RLS de la tabla verificada por test).
- [ ] Tests pasan (unit + integration de la edge function + health check del cliente + pipeline local).
- [ ] `flutter analyze` 0 warnings.
- [ ] `flutter build apk --debug` compila.
- [ ] Deno: `deno check` + `deno test` pasan en la edge function.
- [ ] Hugo verificó que las migraciones y el deploy de la edge function funcionaron en el panel de Supabase.
- [ ] QA local: Hugo puede correr `flutter run` en su celu y la app muestra el placeholder sin crashear, **y** un test de health check en consola muestra los flags de la BD.

---

## Notas

- **Sobre la auth de la edge function:** los flags son datos del PRODUCTO, no del usuario. Cualquier cliente puede leerlos sin auth. Por eso `--no-verify-jwt` en el deploy. Si en el futuro hay flags por usuario, se cambia.
- **Sobre el seed:** solo inserta `splash`. Otras features (ej. `exportar_reportes`, `chat_ia`) se agregarán en HDUs futuras. No scope creep.
- **Sobre `tier`:** por ahora `free` y `pro` son los únicos. El modelo de tiers real se define en ADR-010 y TierService (HDU-003).
- **Sobre `flutter_dotenv`:** el `.env` real se carga al inicio. Si la variable no existe, la app falla rápido. NO se defaultean valores — fail fast es preferible a "funciona con valores incorrectos".
- **Sobre el directorio `supabase/`:** es nuevo. Se crea con `supabase init` (Hugo lo hace) o manualmente. NO se commitea `supabase/.env` ni nada con secrets.
- **Sobre la posición del cliente de Supabase:** `lib/core/supabase/` (no `lib/features/<dominio>/`) porque Supabase es transversal a todos los dominios (todos consumen el cliente, pero ninguno es dueño).
- **Sobre el orden de las migraciones:** el timestamp del nombre del archivo determina el orden de aplicación. La primera migración es la del schema; la segunda es la del seed. Si se corre `supabase db reset` desde cero, se aplican en orden.
