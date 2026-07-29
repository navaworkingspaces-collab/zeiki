# `lib/core/supabase/`

> **Cliente de Supabase compartido por toda la app.**

## ¿Qué vive aquí?

- **`supabase_client.dart`**: función `initSupabase(EnvConfig env)` que inicializa el cliente global con `Supabase.initialize`. Se llama desde `main()` antes de `runApp`.

## Regla arquitectónica (Target §6)

- `lib/core/supabase/` es **transversal**: lo consumen todos los dominios (`lib/features/<dominio>/`).
- `features → core` permitido. `core → features` **prohibido**.
- Si un dominio necesita lógica de Supabase específica (ej. descarga SAT, eFirma), crea su propio servicio dentro de `lib/features/<dominio>/data/` que use este cliente compartido. NO metas esa lógica acá.

## Estado

Inicializado en `main()` desde HDU-002. Antes de esa HDU, el cliente no existía (el proyecto estaba en Fase 0 / setup).

## Variables de entorno (conventions §10)

El cliente se inicializa desde `EnvConfig` (en `lib/core/constants/env_config.dart`), que a su vez lee de `assets/.env` con `flutter_dotenv`. Si falta una variable requerida, la app falla rápido con un mensaje claro (no se defaultean valores).

## Referencias

- `lib/core/constants/env_config.dart` — cómo se carga la config.
- `docs/conventions.md §10` — capas de configuración.
- `docs/runbooks/secrets.md` — dónde y cómo se gestionan los secretos.
