# ADR-010: TierService como state global cross-cutting

**Estado:** Supersedido en la práctica (ver nota 2026-07-30)
**Fecha:** 2026-07-29

> **Nota (2026-07-30, HDU-003):** la decisión de NO registrar `TierService` en `sl` fue revertida en la práctica. `TierService` SÍ se registra en GetIt como singleton lazy desde `lib/core/di/service_locator.dart`. Razón y contexto completo en `specs/HDU-003-feature-flag-system.md` (AC2 + AC7) y en el comentario de cabecera de `service_locator.dart`. Este ADR se conserva como precedente histórico; si aparece fricción con el patrón GetIt, se reabre la discusión.

## Contexto

Zeiki tiene tres conceptos que afectan a TODA la app:

1. **Tier del usuario** (basic, pro, platinum): de qué plan es, qué features puede usar.
2. **Feature flags:** qué features están habilitadas para este usuario (release, experiment, ops).
3. **Permisos derivados:** combinación de tier + flags que la UI consulta para decidir qué mostrar.

Estos tres conceptos son consultados por todos los dominios, en cualquier momento, sin importar la pantalla actual. Inyectarlos por constructor o por `sl<T>()` añade fricción (registrar en cada feature, pasar por todos los `BuildContext`) y rompe el principio de que "state global vive aparte, dependencia inyectable vive en GetIt" (ver ADR-005).

## Decisión

**`TierService`** es un singleton **NO registrado en `sl`**. Vive como state global cross-cutting, mismo patrón que `AuthStateChangeNotifier` o `ThemeController`.

**Ubicación:** `lib/core/tiers/tier_service.dart`.

**Exposición a la UI:**

- **Síncrona:** `TierService.instance.has(AppFeature.nuevoDashboard)`.
- **Reactiva:** `ValueListenableBuilder` o `BlocBuilder` sobre `TierService.instance.listenable`.

**Componentes:**

| Archivo | Responsabilidad |
|---------|-----------------|
| `tier_service.dart` | Singleton. Tiene el tier actual y el set de features habilitadas. |
| `tier_repository.dart` | Lee el tier desde Supabase. |
| `tier_models.dart` | Enum `TierCode` (basic, pro, platinum). |
| `app_feature.dart` | Enum `AppFeature` con 15 features. La UI nunca usa strings sueltos. |
| `feature_gate.dart` | Widget que envuelve features según `AppFeature`. Reemplaza `GateWidget` deprecado. |
| `feature_manifest.dart` | CLI helper que sincroniza el enum con la BD. |

## Por qué

- **State global va aparte:** no tiene sentido inyectar el tier en cada caso de uso. Es transversal.
- **Acceso directo desde la UI:** la UI puede preguntar "¿puedo mostrar esto?" sin pasar por un use case que probablemente no aporta lógica de negocio.
- **Mismo patrón que AuthStateChangeNotifier:** consistencia con otros singletons cross-cutting que ya tenemos.
- **Feature flags type-safe:** `AppFeature` es enum, no string. La IDE autocompleta. Errores de compilación si se renombra.

## Alternativas consideradas

- **Inyectar TierService en cada feature vía GetIt:** posible, pero requiere registrar en `injection_container.dart` y pasarlo a cada use case. Fricción sin beneficio (el tier es read-only desde la perspectiva de un feature).
- **Provider / Riverpod como state global:** viable, pero acopla la decisión de state global con un paquete específico. El patrón de singleton puro sobrevive cambios de stack.
- **Server-driven (consultar el tier en cada request):** demasiado lento, la UI necesita decidir antes de hacer requests.
- **Hardcodear el tier en el cliente:** muerto el día que se ofrezcan tiers dinámicos.

## Trade-offs

- **A favor:** acceso simple, type-safe, no invade cada feature, consistente con el resto de singletons globales.
- **En contra:** un singleton es un "dios" potencial. Se mitiga con: tests de unidad, surface mínima (solo `has()` y similares), y la regla de que **solo `core/tiers/` puede importarlo**. Los features lo consultan, no lo modifican.

## Sincronización código ↔ BD

- El enum `AppFeature` es la fuente canónica en el código.
- La tabla `app_tier_features` en Supabase define qué features tiene cada tier.
- Un test (`feature_sync_test.dart`) verifica que ambos estén sincronizados: si el enum tiene una feature que la BD no, falla; si la BD tiene una feature que el enum no, falla.
- **Status:** TBD. El test esqueleto no está escrito todavía. Se documenta como aspiración honesta en `target-architecture.md §10`.

## Cuándo se revisa

- El número de features crece más allá de 30-40 y el enum se vuelve difícil de mantener.
- Aparece un caso donde dos features necesitan valores (ej. "límite de descarga por día") y `AppFeature` solo soporta booleanos. Ahí se migra a un modelo más rico.
- Se quiere multi-tenancy (cada organización tiene su tier). Entonces el singleton se vuelve per-tenant.
