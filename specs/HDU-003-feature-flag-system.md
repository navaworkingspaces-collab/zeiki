# HDU-003 — Feature flag system del cliente (TierService)

**Tipo:** feature
**Prioridad:** alta
**Estado:** pendiente
**Fecha:** 2026-07-30
**Sistemas externos involucrados:** Supabase (edge function `feature-flags` deployada en HDU-002)
**Dominio(s):** transversal (afecta a todos los features que usen feature flags)

---

## Check de entendimiento (3 líneas)

- Lo que quieres: tener los cimientos del feature flag system del cliente en Zeiki (el enum `AppFeature`, el `TierService` con cache local, y la sincronización con la edge function `feature-flags` que ya existe).
- Vas a saber que está bien cuando: cualquier feature de la app pueda preguntar "¿está habilitado este flag?" con `TierService.has(AppFeature.x)` en microsegundos (sin pegarle a la red cada vez), y la respuesta se refresque periódicamente desde el backend.
- Esto NO se va a hacer: el gating por tier del usuario (eso es HDU-005 de Identidad), exponer flags al exterior, ni override de flags por usuario en dev.

---

## Problema / Motivación

La HDU-002 dejó lista la base del backend de Supabase: tabla `app_tier_features` con RLS, edge function `feature-flags` que devuelve los flags en JSON, y el seed inicial con `splash` para `free` y `pro`.

Pero el cliente (Flutter) **no tiene cómo consumir esos flags**. Sin el `TierService`, las features de la app no pueden gatear su comportamiento según la config del backend. Esto bloquea la HDU-006 (splash nuevo, que DEBE tener flag desde el día 1 por Target §10) y cualquier feature futura que necesite gating.

Esta HDU es la pieza que conecta el backend con el cliente.

---

## Criterios de aceptación

- [ ] **AC1:** `AppFeature` declarado como enum type-safe en `lib/core/tiers/app_feature.dart`, con al menos el valor `AppFeature.splash` (los demás features se agregan en HDUs futuras según necesidad, no en esta).
- [ ] **AC2:** `TierService` es singleton, expuesto vía `TierService.getInstance()` (sin injection manual) y vía GetIt (`TierServiceLocator.tierService`).
- [ ] **AC3:** `TierService.has(AppFeature.x)` es **sincrónica** (no async) — consulta el cache local en memoria. Latencia < 1 ms.
- [ ] **AC4:** El cache local se inicializa vacío al arrancar la app. Se llena la primera vez con un fetch a la edge function `feature-flags`.
- [ ] **AC5:** `TierService.refresh({bool force = false})` pega a la edge function y actualiza el cache. Si falla (red caída, Supabase caído), el cache anterior se conserva y se loguea un warning, **NO se rompe la UI**.
- [ ] **AC6:** `TierServiceConfig` permite configurar el intervalo de refresh (default 15 min) y overrides de debug (`Map<AppFeature, bool>` que sobreescribe el cache — solo en dev/debug).
- [ ] **AC7:** `TierService` registrado en el contenedor de GetIt (`lib/core/di/service_locator.dart`) como singleton lazy, siguiendo ADR-005.
- [ ] **AC8:** `TierService.initialize()` se llama en `lib/main.dart` después de `initSupabase(env)`. La app NO espera a que termine el refresh inicial para mostrar la primera pantalla (fire-and-forget).
- [ ] **AC9:** `feature_sync_test.dart` en `integration_test/` verifica que el enum `AppFeature` y la tabla `app_tier_features` estén sincronizados: cada valor del enum tiene al menos una fila en la BD (sirve de regression test contra "agregué feature al código pero no a la BD" o viceversa). Cubre Target §15 "Documentos pendientes" → `feature_sync_test.dart`.
- [ ] **AC10:** `flutter analyze` 0 warnings, `flutter test` pasa, `flutter test integration_test/` (en Xiaomi) pasa, `flutter build apk --debug` compila. Pipeline local completo.

---

## Archivos afectados

**Nuevos:**

- `lib/core/tiers/app_feature.dart` — enum `AppFeature` con `name` y `description` por valor (ayuda a debugging y a la doc auto-generada del Target §15).
- `lib/core/tiers/tier_service.dart` — la clase `TierService` (singleton, cache, refresh, has, changes stream).
- `lib/core/tiers/tier_service_config.dart` — config inmutable (intervalo de refresh, overrides de debug).
- `lib/core/tiers/tier_change.dart` — tipo del stream `changes` (qué feature cambió, nuevo valor, source).
- `integration_test/tier_service_sync_test.dart` — verifica que el cache se actualiza con la respuesta real de la edge function.
- `integration_test/feature_sync_test.dart` — verifica que enum y tabla están sincronizados (AC9, requisito de Target §15).
- `test/core/tiers/tier_service_test.dart` — unit tests del cache, refresh, overrides, error handling.
- `test/core/tiers/app_feature_test.dart` — unit tests del enum (verifica que tiene al menos 1 valor, que los nombres son únicos, etc.).

**Modificados:**

- `lib/core/di/service_locator.dart` (si no existe, se crea) — registrar `TierService` como singleton.
- `lib/main.dart` — llamar `await TierService.initialize()` después de `initSupabase(env)`.
- `docs/current-state.md` — actualizar con la HDU-003 cerrada cuando se mergeé (parte del cleanup).
- `.mavis/hdu.md` (local, en `.gitignore`) — registrar la HDU-003 cerrada.

**Eliminados:** ninguno.

---

## Plan técnico (pasos verificables)

1. **Crear `lib/core/tiers/app_feature.dart`** con el enum. Empezar solo con `splash` (Target §10 sugiere "Agregar al menos un feature por HDU"). El método `name` del enum es el `feature_key` que se usa en la tabla. El método `description` documenta el propósito. Ejemplo:
   ```dart
   enum AppFeature {
     splash('splash', description: 'Splash screen on app launch.');

     const AppFeature(this.name, {required this.description});
     final String name;
     final String description;
   }
   ```
2. **Crear `lib/core/tiers/tier_service_config.dart`** con config inmutable. Campos: `refreshInterval` (Duration, default 15 min), `debugOverrides` (Map<AppFeature, bool>, default vacío), `debugEnabled` (bool, default false, activa los overrides solo en dev).
3. **Crear `lib/core/tiers/tier_service.dart`**:
   - Singleton (`TierService.getInstance()` con constructor privado).
   - `Map<AppFeature, bool> _cache` — el estado del cache. Inicia vacío.
   - `TierServiceConfig _config` — inyectado o default.
   - `bool has(AppFeature feature)` — devuelve `_cache[feature] ?? false` (fail-safe: si el feature no está en el cache, devuelve false en vez de tirar).
   - `Future<void> refresh({bool force = false})` — llama `supabase.functions.invoke('feature-flags')`, parsea la respuesta `{ flags: { splash: true, ... } }`, actualiza el cache. Si falla, loguea `warning` y conserva el cache anterior.
   - `Future<void> initialize({TierServiceConfig? config})` — setea config, dispara un `refresh()` fire-and-forget (NO espera).
   - `Stream<TierChange> get changes` — notifica cuando el cache cambia (después de un refresh exitoso). Implementar con `StreamController.broadcast`.
   - `void dispose()` — cierra el StreamController (para tests).
4. **Crear `lib/core/tiers/tier_change.dart`** con la clase `TierChange`:
   ```dart
   class TierChange {
     final AppFeature feature;
     final bool newValue;
     final ChangeSource source; // .remote, .debugOverride, .reset
   }
   ```
5. **Registrar `TierService` en GetIt** (`lib/core/di/service_locator.dart`):
   - Si el archivo no existe, crearlo con la función `setupServiceLocator()` que registra `TierService` como singleton lazy.
   - Llamar `setupServiceLocator()` desde `main.dart` antes de `runApp`.
6. **Inicializar `TierService` en `lib/main.dart`** después de `initSupabase(env)`:
   ```dart
   await initSupabase(env);
   await TierService.getInstance().initialize();  // fire-and-forget refresh
   runApp(...);
   ```
   El `initialize()` no bloquea la primera pantalla — el `refresh()` corre en background y notifica a quien esté escuchando.
7. **Crear `test/core/tiers/app_feature_test.dart`** — unit tests del enum:
   - Tiene al menos 1 valor.
   - Todos los `name` son únicos.
   - Todos los `name` son `snake_case` (validación regex).
8. **Crear `test/core/tiers/tier_service_test.dart`** — unit tests del `TierService`:
   - `has()` con cache vacío devuelve `false`.
   - Después de un refresh exitoso, `has()` devuelve el valor correcto.
   - Después de un refresh fallido, `has()` conserva el valor anterior (no rompe).
   - Override de debug tiene prioridad sobre el cache.
   - `changes` stream emite cuando hay un cambio real (no emite si el valor es el mismo).
   - `dispose()` cierra el stream sin crashear.
   - Para los tests, usar un `FakeSupabaseClient` (no mock con `mockito`, conventions §3) que devuelve un `Map<AppFeature, bool>` controlado.
9. **Crear `integration_test/tier_service_sync_test.dart`** — integration test que verifica el flujo real:
   - Llama `TierService.initialize()` con config de test (refresh inmediato).
   - Verifica que `has(AppFeature.splash)` devuelve `true` después del refresh.
   - Verifica que el `changes` stream emite al menos 1 vez.
   - Marca con `@Tags(['integration'])` (aunque está en `integration_test/`, es redundante pero inofensivo, según el patrón de HDU-002).
10. **Crear `integration_test/feature_sync_test.dart`** — verifica que el enum y la tabla están sincronizados (AC9, requisito de Target §15):
    - Hace `SELECT DISTINCT feature_key FROM app_tier_features`.
    - Compara la lista de feature_keys con los `name` de `AppFeature.values`.
    - Cada valor del enum tiene al menos una fila en la tabla, y cada fila corresponde a un valor del enum.
    - Si hay drift, el test falla con un mensaje claro que dice qué feature falta o sobra.
    - Marca con `@Tags(['integration'])`.
11. **Verificar el pipeline local**:
    - `flutter analyze` → 0 warnings.
    - `flutter test` → pasan los unit tests.
    - `flutter test integration_test/` (en Xiaomi) → pasan los 2 integration tests + los 3 de HDU-002 (no se rompieron).
    - `flutter build apk --debug` → compila.
12. **Commit** con `feat(tiers): add TierService, AppFeature enum, and integration with feature-flags edge function [HDU-003]`.

---

## Tests a escribir (basado en matriz de criticidad)

| Componente | Criticidad | Tipo de test mínimo | Notas |
|------------|------------|---------------------|-------|
| Enum `AppFeature` | Media | Unit | No tiene lógica, solo validación de shape. |
| `TierService.has()` con cache | **Alta** (afecta toda la UI) | Unit | El comportamiento por defecto (cache frío → false) es crítico. |
| `TierService.refresh()` éxito | **Alta** | Unit (con fake client) + integration | Debe actualizar el cache y emitir `changes`. |
| `TierService.refresh()` fallo | Alta | Unit | El cache anterior se conserva. La UI no rompe. |
| `feature_sync_test` (enum ↔ tabla) | **Alta** (afecta CD seguro de Target §10) | Integration | Cubre el requisito de Target §15 de "verificar que el enum y la tabla estén sincronizados". |
| Override de debug | Baja | Unit | Útil para dev, no es crítico. |
| `tier_service_config` | Baja | Unit | Solo config inmutable. |

Referencia: §11 de Target Architecture (matriz de criticidad).

---

## Fuera de scope

- **Gating por tier del usuario** (HDU-005 Identidad). El `TierService` actual NO considera al usuario — devuelve el mismo flag para todos. Cuando haya auth, se agrega el filtrado por tier.
- **Override de flags por usuario en dev** (no necesario en MVP).
- **Telemetría de `flag_evaluated`** (Fase 2 Observabilidad, Target §9).
- **Refresh automático con `Timer.periodic`** — la primera versión es pull-based (el consumidor llama `refresh()` cuando necesita). Un timer se agrega en HDU futura si se necesita. No es bloqueante.
- **Documentación auto-generada de feature flags** (Target §15 aspiración, "se implementa cuando > 5 features").
- **Interfaz admin para cambiar flags** (operador usa el SQL Editor de Supabase directamente).

---

## Riesgos

- **El spec puede omitir cosas** (lección de HDU-001/HDU-002). Crucé contra Target §6, ADR-010, ADR-005, ADR-003. Si el implementer descubre otra omisión, la maneja in-line como "decisión que tomé" en su reporte.
- **La edge function usa `service_role` con `--no-verify-jwt`** (nota del reviewer de HDU-002). Hoy está OK porque los flags son del producto. Cuando llegue HDU-005 y haya auth, hay que revisar el diseño para que los flags personalizados por usuario NO usen este atajo.
- **Si el refresh falla en cold start**, el usuario ve la app con cache vacío (todos los flags en `false`). Esto puede causar UI rota si un feature asume `true` por default. **Mitigación:** documentar en el doc del feature que `has()` puede devolver `false` aunque el flag esté habilitado en la BD, y que la UI debe asumir el peor caso. Para el splash específicamente, el splash DEBE mostrarse siempre que el flag esté habilitado en la BD — el refresh en background lo activará cuando llegue.
- **El test `feature_sync_test` requiere la BD con datos.** Si la BD está vacía (no se aplicó el seed), el test falla. **Mitigación:** documentar que el test requiere la HDU-002 aplicada, y agregar al setup del test un seed mínimo si es necesario.
- **`AppFeature` enum + tabla `app_tier_features` pueden divergir** si alguien agrega un valor al enum pero olvida la BD, o viceversa. El test `feature_sync_test` lo detecta, pero el feedback es lento (solo en CI / device). **Mitigación:** documentar en `conventions.md` que agregar un feature requiere 2 pasos (enum + seed).
- **`flutter_dotenv` carga `.env` al inicio**, pero `TierService` puede inicializarse antes de que `.env` esté disponible si el orden en `main.dart` es incorrecto. **Mitigación:** el spec del plan técnico es explícito sobre el orden: `initSupabase(env)` → `TierService.initialize()` → `runApp()`.

---

## Review checklist

- [ ] Cumple con §1-§3 de Target Architecture (principios, atributos, restricciones).
- [ ] No introduce anti-patrones (§14 de Target). Específicamente: NO `setState` para lógica de negocio, NO lógica de negocio en widgets, NO `mockito` (usar fakes), NO rutas hardcoded.
- [ ] Clean code (conventions §2: nombres, funciones chicas, comentarios del porqué).
- [ ] Security (conventions §6: sin secrets en código, sin secrets en logs, errores no exponen stack traces sensibles).
- [ ] Tests pasan (unit + integration).
- [ ] `flutter analyze` 0 warnings.
- [ ] `flutter build apk --debug` compila.
- [ ] QA local: Hugo corre `flutter run` en su Xiaomi, la app muestra el placeholder del splash, y `TierService.has(AppFeature.splash)` devuelve `true` después del refresh.
- [ ] El reviewer (zeiki-reviewer) y el auditor (zeiki-auditor) aprueban con cero bloqueantes.

---

## Notas

- **Sobre el orden de inicialización:** `initSupabase(env)` debe ir antes de `TierService.initialize()` porque el refresh usa `supabase.functions.invoke('feature-flags')`. Si el orden es incorrecto, el refresh falla. El spec es explícito sobre esto.
- **Sobre el cache vacío en cold start:** el primer `has()` después de `runApp` puede devolver `false` aunque el flag esté habilitado. Esto es por diseño: el refresh es async, y el primer paint no espera. Las features que asuman `true` por default deben documentarlo explícitamente.
- **Sobre la integración con GetIt:** `TierService` se registra como singleton lazy. NO se inyecta en constructores — se accede vía `getIt<TierService>()`. Esto evita acoplamiento (un feature que use `TierService` no necesita pasarlo por constructor). Es un trade-off de Clean Architecture (regla "dependencias hacia adentro"): se sacrifica testabilidad por simplicidad, justificado por el patrón target `app_tier_features` que es leído por muchos.
- **Sobre el `changes` stream:** las features que quieran reaccionar a cambios de flags (no solo consultar el estado actual) se suscriben a `TierService.getInstance().changes`. Esto es útil para invalidar caches locales, refrescar UI, etc. La primera versión (HDU-003) NO usa el stream activamente — solo el splash lo consultará en `initState`. HDUs futuras lo aprovecharán.
- **Sobre el override de debug:** el override es un mapa `Map<AppFeature, bool>` que sobreescribe el cache. Solo se activa si `TierServiceConfig.debugEnabled = true`. Sirve para QA/dev: "quiero forzar que `splash` esté deshabilitado para probar la pantalla de login". El override NO se persiste — solo aplica mientras la app corre.
- **Sobre `flutter_dotenv` y la config:** el `TierServiceConfig` recibe la `EnvConfig` del paso de inicialización (que ya leyó del `.env`). Si en el futuro hay config de feature flags por entorno (dev/staging/prod), se puede pasar un `EnvConfig.environment` al `TierServiceConfig`.
- **Sobre el enum `AppFeature` y el seed de la BD:** el seed de la HDU-002 ya tiene `('splash', 'free', true)` y `('splash', 'pro', true)`. El `feature_sync_test` lo valida automáticamente. Si en HDU-005 (Identidad) se agregan tiers o features, se actualiza el seed y el enum al mismo tiempo.
- **Sobre el warning del tag `integration`:** el test runner de Flutter puede quejarse de que el tag `integration` no está declarado en `dart_test.yaml`. Es ruido, no rompe nada. Si en HDUs futuras se vuelve molesto, agregamos un `dart_test.yaml` que defina el tag.

---

## Cambios desde la HDU-002 (lecciones aplicadas)

- **Lección "spec omite cosas":** cruzado contra Target §6, ADR-010, ADR-005, ADR-003. Carpetas mencionadas: `lib/core/tiers/`, `lib/core/di/`, `lib/core/constants/`. Listo.
- **Lección "el implementer no declara deps":** el spec de la HDU-002 omitió `integration_test` en `pubspec.yaml`. El de la HDU-003 NO agrega deps nuevas (todo es código nuevo en `lib/`, `test/`, `integration_test/`, todas con paquetes ya declarados).
- **Lección "el implementer no respeta el formato de archivos":** no aplica a esta HDU (no hay migraciones SQL).
- **Lección "spec ambiguo sobre GRANTs / secrets":** la HDU-003 NO toca Supabase directamente — solo consume la edge function deployada en HDU-002. No hay GRANTs ni secrets nuevos.
- **Lección "spec del implementer omite el reporte de cambios sutiles":** el plan técnico es explícito sobre el orden de inicialización (`initSupabase` → `TierService.initialize` → `runApp`), el comportamiento del cache frío, y el manejo de errores del refresh. No hay ambigüedad.
