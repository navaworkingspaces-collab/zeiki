# `lib/core/services/`

Servicios transversales de infraestructura que no son auth ni DI ni logging. Ejemplos esperados:

- `BiometricService` (Target §6)
- `PostalCodeService` (Target §6)
- Servicios de plataforma (notificaciones locales, archivos, etc.)

**Regla:** si un servicio solo lo usa un feature, vive en `features/<dominio>/`. Aquí solo van los que son transversales.

**Estado:** vacío. Se llena cuando llegue la primera necesidad transversal.
