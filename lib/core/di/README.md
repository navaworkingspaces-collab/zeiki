# `lib/core/di/`

Configuración de **inyección de dependencias** (GetIt, ver [ADR-005](../../../docs/adr/ADR-005-getit.md)).

Aquí vivirá el `service_locator.dart` que registra los singletons y factories del proyecto.

**Regla:** todos los features consumen dependencias vía `getIt<T>()`, nunca instancian directamente.

**Estado:** vacío. Se llena cuando la primera feature (Identidad) necesite servicios.
