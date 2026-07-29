# `lib/core/auth/`

Servicios transversales de autenticación: gestión de tokens, refresh, logout.

**Regla arquitectónica (Target §6):** `core/` NO importa de `features/`. Si una feature necesita auth, expone un caso de uso en `features/<dominio>/`, no se invierte la dependencia.

**Estado:** vacío. Se llena cuando se implemente la primera HDU de Identidad.
