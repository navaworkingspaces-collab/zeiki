# Archive — specs y documentos históricos de Zeiki

Esta carpeta guarda specs, runbooks y documentos de HDUs cerradas cuya descripción ya no refleja el estado actual del proyecto. NO son fuente de verdad: sirven como referencia histórica de qué se pensó y por qué.

## Política de archivo

- **Cuándo se archiva:** cuando un spec describe una implementación que ya no existe (ej. una pantalla removida, un flujo redirigido) y mantenerlo mintiendo en `specs/` confundiría a un implementer futuro.
- **Cuándo NO se archiva:** cuando el spec describe un comportamiento vigente, aunque tenga referencias históricas internas. En ese caso se actualiza el texto, no se archiva.
- **Convención de nombre:** `YYYY-MM-DD-<slug-descriptivo>.md` (la fecha del archivo, no de la HDU original).

## Índice

- `2026-08-06-HDU-007-original-with-verify-email-screen.md` — spec original de HDU-007. Archivado porque describe la implementación con la pantalla `VerifyEmailScreen`, que se removió en el cleanup HDU-007b (la pantalla nunca se renderizaba en runtime — Supabase procesa el token del deep link antes de que el handler de Dart enrute la app, y el `redirect` del router evalúa con la sesión ya creada → user va directo a `/home` o `/login`). El estado actual está documentado en:
  - `docs/current-state.md` (entrada "HDU-007b — Cleanup VerifyEmailScreen (never rendered) — 2026-08-06")
  - `docs/runbooks/google-signin-supabase.md` (sección "Email confirmation")
  - El test de regresión `'pasa emailRedirectTo al callback de Supabase (HDU-007, AC1)'` en `test/core/auth/auth_service_test.dart` líneas 94-112 (red de seguridad que evita repetir el bug del PR #20).
