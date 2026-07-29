# `lib/core/tiers/`

> **Servicios relacionados con la gestión de tiers (planes) y feature flags del usuario.**

## ¿Qué vive aquí?

- **`TierService`** (ADR-010): estado global del tier actual del usuario + caché de features habilitadas. Único punto de consulta para saber si una feature está disponible.
- **`AppFeature`** (enum type-safe): catálogo de todas las features que el sistema puede activar/desactivar. Ver `target-architecture.md §10`.
- **Lógica de feature flags**: helpers para evaluar si una feature está activa, registrar overrides de testing, sincronizar con la tabla `app_tier_features` de Supabase.

## Relación con otros dominios

- **Todos los dominios** (`lib/features/<dominio>/`) consumen `TierService` para gatear features. Ejemplo: si `AppFeature.exportarReportes` está off, el botón de exportar en `Reportes` no se muestra.
- **`lib/core/di/`**: `TierService` se registra como singleton en el contenedor de GetIt.
- **Supabase**: `TierService` lee de la tabla `app_tier_features` con caché local.

## Convenciones

- **NO** se importa desde `lib/features/` con lógica de feature flags — eso lo hace cada feature usando `TierService.has(AppFeature.x)`.
- El enum `AppFeature` es la **única** fuente de verdad sobre qué features existen. No strings sueltos.
- Cualquier feature nueva DEBE agregarse al enum ANTES de ser usada. Si no, el test `feature_sync_test.dart` (TBD en Target §10) va a fallar.

## Referencias

- `docs/architecture/target-architecture.md` §10 (Estrategia de Feature Flags).
- `docs/adr/ADR-010-tier-service.md`.
- `docs/adr/ADR-005-getit.md` (cómo se registra el servicio).
