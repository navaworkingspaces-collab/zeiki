# `lib/core/logging/`

Logging centralizado del cliente. Hoy (MVP) usa `debugPrint`; en Fase 2 se introduce el proveedor dedicado (Sentry, ver Target §8).

**Regla:** los features **no** instancian su propio logger. Consumen la interfaz expuesta aquí.

**Estado:** vacío. Se implementa en la HDU de Observabilidad (Fase 2).
