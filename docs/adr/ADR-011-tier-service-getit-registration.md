# ADR-011: TierService registrado en GetIt como singleton lazy

**Estado:** Aceptado
**Fecha:** 2026-07-30
**Reemplaza a:** [ADR-010 (deprecated)](deprecated/ADR-010-tier-service.md)

## Contexto

El [ADR-010](deprecated/ADR-010-tier-service.md) (2026-07-29) decidió que `TierService` NO se registraba en `sl` (GetIt) por considerarlo state global cross-cutting, mismo patrón que `AuthStateChangeNotifier` o `ThemeController`. La justificación era evitar la fricción de registrar y pasar el tier por cada feature.

Durante la implementación de la HDU-003 (feature flag system del cliente, 2026-07-30) se descubrió que esa decisión generaba más fricción que la que evitaba:

1. **Tests rompen el patrón de `getIt.reset()`.** El `tearDown` estándar del proyecto es `getIt.reset()` + re-registro de fakes. Si `TierService` vive aparte, los tests tienen que mantener una referencia manual al servicio y reinicializarlo a mano, fuera del ciclo de GetIt. Esto rompe la uniformidad.
2. **Inicialización order-sensitive.** `TierService.initialize()` necesita correr después de `initSupabase()` pero antes de `runApp()`. Si vive en GetIt como singleton lazy, el orden se respeta naturalmente: GetIt crea la instancia en el primer `getIt<T>()`.
3. **Mismo principio de "dependencia inyectable vive en GetIt" se respeta.** El `TierService` no es state mutable compartido por toda la app — es un servicio con estado cacheable que expone `has()`, `refresh()` y un stream. Encaja en GetIt sin violencia.
4. **El `AuthStateChangeNotifier` no es realmente comparable.** El ADR-010 lo citaba como precedente, pero ese notifier es un wrapper sobre el stream de Supabase Auth — no tiene cache ni test doubles. El `TierService` sí los tiene (inyección de `FeatureFlagsFetcher`), y los tests con fakes se benefician del patrón GetIt.

## Decisión

**`TierService` SÍ se registra en GetIt (`sl`)** como singleton lazy, desde `lib/core/di/service_locator.dart`. El `setupServiceLocator()` se llama UNA vez desde `main.dart` después de `initSupabase(env)`.

**Patrón:**

```dart
if (!getIt.isRegistered<TierService>()) {
  getIt.registerLazySingleton<TierService>(TierService.new);
}
```

**Acceso desde features y otros lugares de la app:**

```dart
final tierService = getIt<TierService>();
```

**Exposición a la UI** (sin cambios respecto a ADR-010):

- **Síncrona:** `tierService.has(AppFeature.splash)`.
- **Reactiva:** `ValueListenableBuilder` o `BlocBuilder` sobre `tierService.changes`.

## Por qué

- **Consistencia con el resto de servicios:** todos los singletons viven en GetIt. Excluir a `TierService` rompía la regla "un solo lugar para instanciar".
- **Tests más simples:** `getIt.reset()` + re-registro de fakes es el patrón universal del proyecto. `TierService` ahora lo sigue.
- **Orden de inicialización explícito y testeable:** `initSupabase()` → `setupServiceLocator()` (registra `TierService` lazy) → `TierService.initialize()` (primer uso) → `runApp()`. Cada paso está en una línea.
- **Sin cambio de contrato para la UI:** `has()` y `changes` siguen siendo la API pública. La UI no nota la diferencia.
- **Precedente honesto:** el código en `lib/core/di/service_locator.dart:12-16` documenta explícitamente que ADR-010 se revirtió y por qué. La trazabilidad queda en el repo.

## Alternativas consideradas

- **Mantener ADR-010 (singleton manual, no en GetIt).** Opción original. Se descartó por la fricción en tests y la inconsistencia con el resto de servicios.
- **Provider / Riverpod solo para `TierService`.** Acopla la decisión de DI a un paquete de state management. El proyecto usa GetIt por convención (ADR-005); desviarse solo para un servicio es peor que la fricción que evita.
- **Singleton global con `static` y `getInstance()`.** Funciona, pero pierde la integración con el ciclo de `getIt.reset()` en tests y con el patrón de inyección de `FeatureFlagsFetcher`.

## Trade-offs

- **A favor:** consistencia, tests más simples, orden de init explícito, sin cambio de contrato para la UI.
- **En contra:** ninguno significativo. El "singleton global" como dios potencial se mitiga igual que antes: surface mínima (`has()`, `refresh()`), tests de unidad, regla de que **solo `core/tiers/` puede importarlo directamente**. Los features lo consumen vía `getIt<TierService>()` y solo leen (`has()`, `listen`), no escriben.

## Sincronización con la base de datos

Sin cambios. El enum `AppFeature` sigue siendo la fuente canónica en el código. La tabla `app_tier_features` en Supabase define qué features tiene cada tier. El test `feature_sync_test.dart` (integration test) verifica que ambos estén sincronizados.

## Cuándo se revisa

- El número de servicios en `setupServiceLocator()` crece tanto que el archivo `service_locator.dart` se vuelve inmanejable. Ahí se divide por dominio (mismo criterio que ADR-005 §Cuándo se revisa).
- Aparece un caso donde un servicio NO encaja en GetIt (ej. un wrapper sobre un singleton externo con ciclo de vida propio). Ahí se reabre este ADR.
- La UI de Zeiki migra de GetIt a `provider` o Riverpod. Ahí se reescribe este ADR.
