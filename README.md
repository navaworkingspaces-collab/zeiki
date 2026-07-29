# Zeiki

> App de facturación CFDI 4.0 con descarga masiva de CFDIs del SAT. Reescritura desde cero con Target Architecture.

**Estado:** Fase 1 — MVP. Reescritura iniciada el 2026-07-29.

## Cómo correr (un comando)

```powershell
flutter pub get && flutter run
```

Requisitos: Flutter 3.38+ estable, Dart 3.10+, Android SDK (la app es Android-only en MVP — ver [Target §Fuera de scope](docs/architecture/target-architecture.md)).

Para build de debug directo (sin emulador):

```powershell
flutter build apk --debug
```

APK queda en `build/app/outputs/flutter-apk/app-debug.apk`.

> **Variables de entorno:** cuando se conecte Supabase, copiar `assets/.env.example` a `assets/.env` y rellenar los valores. El `.env` real está en `.gitignore`.

## Documentación

- **[Target Architecture](docs/architecture/target-architecture.md)** — el plano maestro. Léelo primero.
- **[Workflow](docs/workflow.md)** — cómo se trabaja (12 pasos, check de entendimiento, Definition of Done).
- **[Convenciones](docs/conventions.md)** — qué debe cumplir el código (agnóstico del stack).
- **[Git + CI/CD](docs/git.md)** — comandos, branches, pipeline, PRs.

## Slogan

> La arquitectura soporta las features, no las dicta.
