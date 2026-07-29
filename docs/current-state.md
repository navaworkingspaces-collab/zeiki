# Current State — Zeiki

> **Snapshot rápido del estado del proyecto.** Se actualiza en el cleanup (paso 12) de cada HDU cerrada. Para el detalle de una HDU específica, ver `specs/HDU-XXX-*.md`. Para el histórico, ver `.mavis/hdu.md`.

**Última actualización:** 2026-07-29 (post-HDU-001, post-creación de zeiki-reviewer).

---

## 📍 Dónde estamos

- **Fase:** 1 (MVP).
- **Última HDU cerrada:** HDU-001 — Base del proyecto Flutter.
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

## 🔜 Próximos pasos sugeridos (no comprometidos)

- **HDU-002:** Splash — migrar el splash del proyecto legacy con la arquitectura actual (Target §0, §10 feature flags). Necesita un HDU-EXPLORE previa para entender qué reglas de decisión tenía el splash viejo. *Pendiente de triaje con Hugo para definir alcance.*
- **HDU-003 (Fase 1):** Identidad — login con email. Primera feature real del MVP (Target §15). Bloqueada hasta tener Supabase configurado (credenciales, RLS, edge function de magic link).

## 🐛 Follow-ups activos (de HDUs cerradas)

| # | Origen | Descripción | Prioridad | Estado |
|---|--------|-------------|-----------|--------|
| 1 | HDU-001 | `zeiki-reviewer` creado (code review 3 gates). | media | **completado** |
| 2 | HDU-001 | Si vuelven a salir warnings de Gradle Java 8, abrir HDU para subir target a Java 11/17. | baja | watch (no se reprodujeron) |
| 3 | HDU-001 | 27 paquetes de `pub get` con updates disponibles. NO actualizar a ciegas — HDU dedicada de "actualizar deps base" cuando se decida. | baja | pendiente |
| 4 | HDU-001 | Documentar `assets/.env.example` no se incluye como asset cuando se conecte Supabase (usar `--dart-define-from-file`). | media | en próxima HDU de Identidad |

## 📚 Lecciones aprendidas recientes

- **2026-07-29 — "Si los planos lo dicen, no se pregunta, se hace":** el spec de HDU-001 omitió `lib/core/tiers/`, pero Target §6 y ADR-010 la mencionan. No se pregunta al usuario, se corrige el spec y se crea la carpeta. Lección completa en `memory/MEMORY.md` (agente).
- **2026-07-29 — "Lo que el auditor marca, se hace":** las 5 notas del `seiki-auditor` no se "registran como follow-up", se aplican en el momento (o se descartan con razón explícita). 2 aplicadas en este cleanup, 2 registradas como aprendizaje, 1 zona gris documentada en `conventions.md`.
