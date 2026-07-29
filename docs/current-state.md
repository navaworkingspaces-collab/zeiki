# Current State — Zeiki

> **Snapshot rápido del estado del proyecto.** Se actualiza en el cleanup (paso 12) de cada HDU cerrada. Para el detalle de una HDU específica, ver `specs/HDU-XXX-*.md`. Para el histórico, ver `.mavis/hdu.md`.

**Última actualización:** 2026-07-29 (post-HDU-EXPLORE-001 cerrada).

---

## 📍 Dónde estamos

- **Fase:** 1 (MVP).
- **Última HDU cerrada:** HDU-EXPLORE-001 — Exploración del splash legacy.
- **HDUs activas:** ninguna.
- **Rama `main`:** deployable.
- **Stack operativo:** Flutter 3.38.3 + Supabase (pendiente de credenciales) + Deno para edge functions (pendiente).

## ✅ HDUs cerradas recientemente

### HDU-001 — Base del proyecto Flutter (2026-07-29)
- PR #1 mergeado a main.
- Crea la base del proyecto: `lib/main.dart` con placeholder, 6 carpetas en `lib/core/` (auth, di, logging, constants, services, tiers), 6 carpetas en `lib/features/` (identidad, fiscal, clientes, reportes, asistencia, configuracion), `pubspec.yaml` con 7 dependencias, `analysis_options.yaml` estricto, smoke test.
- Crea los agentes `zeiki-implementer` y `zeiki-auditor` en `C:\Users\Pc\.minimax\agents\`.
- El primer build tuvo 3 warnings de Gradle (Java 8 obsoleto), no se reprodujeron en builds subsiguientes (cache frío).
- Post-HDU-001 se creó también el agente `zeiki-reviewer` (code review 3 gates: clean code + security + architecture).

### HDU-EXPLORE-001 — Exploración del splash legacy (2026-07-29)
- PR #2 mergeado a main.
- Lee el splash del proyecto legacy `seiki_app` (read-only) y produce reporte con: causa del bug del cortado, qué se puede migrar tal cual, qué se descarta, qué se mejora.
- **Lección:** el legacy es **referencia, no verdad**. Lo que el legacy "ya tiene arreglado" no es vinculante sin verificación propia.
- Las HDU-EXPLORE-002 (decisiones de marca) y HDU-EXPLORE-003 (diseño del feature flag system) propuestas por el agente de la sesión **se descartan** por decisión del orquestador. Se diseñan las decisiones en specs directos.

## 🔜 Próximos pasos sugeridos (secuencia decidida con Hugo)

- **HDU-002:** Sistema de feature flags (Target §10 + ADR-010 + ADR-005). Base para que el splash y otras features nazcan con flag desde el día 1. Owner: técnico.
- **HDU-003:** `go_router` + navegación básica (rutas reales, no solo el placeholder de HDU-001).
- **HDU-004:** Identidad / auth básico (mock primero si Supabase no está listo; RLS + magic link si está).
- **HDU-005:** Splash nuevo con feature flag, go_router y auth mínimo. Spec redactado con base en el reporte de HDU-EXPLORE-001.

## 🐛 Follow-ups activos (de HDUs cerradas)

| # | Origen | Descripción | Prioridad | Estado |
|---|--------|-------------|-----------|--------|
| 1 | HDU-001 | `zeiki-reviewer` creado (code review 3 gates). | media | **completado** |
| 2 | HDU-001 | Si vuelven a salir warnings de Gradle Java 8, abrir HDU para subir target a Java 11/17. | baja | watch (no se reprodujeron) |
| 3 | HDU-001 | 27 paquetes de `pub get` con updates disponibles. NO actualizar a ciegas — HDU dedicada de "actualizar deps base" cuando se decida. | baja | pendiente |
| 4 | HDU-001 | Documentar `assets/.env.example` no se incluye como asset cuando se conecte Supabase (usar `--dart-define-from-file`). | media | en próxima HDU de Identidad |
| 5 | HDU-EXPLORE-001 | Splash nuevo depende de feature flags + go_router + auth. No implementar antes de tener esos 3. | alta | bloqueante para HDU-005 |

## 📚 Lecciones aprendidas recientes

- **2026-07-29 — "Si los planos lo dicen, no se pregunta, se hace":** el spec de HDU-001 omitió `lib/core/tiers/`, pero Target §6 y ADR-010 la mencionan. No se pregunta al usuario, se corrige el spec y se crea la carpeta. Lección completa en `memory/MEMORY.md` (agente).
- **2026-07-29 — "Lo que el auditor marca, se hace":** las 5 notas del `zeiki-auditor` no se "registran como follow-up", se aplican en el momento (o se descartan con razón explícita). 2 aplicadas en este cleanup, 2 registradas como aprendizaje, 1 zona gris documentada en `conventions.md`.
- **2026-07-29 — "El legacy es referencia, no verdad":** la HDU-EXPLORE-001 reportó que el bug del cortado "ya estaba arreglado en el legacy". Eso es lo que el código legacy DICE, no es verdad verificada. **Lección:** tratar el legacy como referencia, no como fuente de verdad. Lo que el legacy afirma sobre sus propios bugs debe verificarse antes de aceptarlo como base.
