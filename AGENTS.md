# AGENTS.md — Zeiki

> **Bootstrap de sesión.** Mavis (o cualquier agente) lee este archivo **PRIMERO** al abrir una sesión en este proyecto. Sin leer el resto del repo, este archivo da el contexto mínimo para no perderse.
>
> **Última actualización:** 2026-07-30 (post-HDU-004)

---

## Identidad del proyecto

- **Nombre:** Zeiki (con Z). **Cero "Seiki"** — el proyecto legacy es `seiki_app`, no se mezclan.
- **Qué es:** App móvil (Flutter) para facturación CFDI 4.0 en México. Reescritura desde cero.
- **Estado:** Fase 1 — MVP. **Código base + backend Supabase + feature flag system del cliente + navegación con go_router listos** (HDU-001, HDU-002, HDU-003 y HDU-004 cerradas).
- **Stack:** Flutter 3.38.3 + Supabase (Postgres + Auth + Edge Functions) + Deno para edge functions. Detalle en `target-architecture.md`.
- **Sin clientes en producción** → no hay riesgo de "valle" en la reescritura.

---

## Orden de lectura OBLIGATORIO al iniciar sesión

Si la nueva sesión abre este repo, lee estos archivos **en este orden** antes de proponer nada:

1. `docs/architecture/target-architecture.md` — el plano maestro.
2. `docs/conventions.md` — reglas del código.
3. `docs/workflow.md` — cómo se trabaja (12 pasos + DoD).
4. `docs/git.md` — comandos y CI/CD.
5. `docs/adr/ADR-009-rewrite-with-knowledge-reuse.md` — la decisión de ir de cero.

Después de leer esos 5:

- **Revisa `docs/current-state.md`** — snapshot del estado del proyecto y próximas HDUs.
- Revisa `target-architecture.md` → sección "Documentos pendientes" (qué falta crear).
- Si la sesión es de implementación, revisa `docs/adr/` (las otras 9 decisiones de stack).

**NO empieces a codear, NO propongas features, NO generes specs sin haber leído los 5 archivos de arriba + current-state.md.**

---

## Lo que NO existe (a propósito)

- **No hay HDUs abiertas.** Cero. Si quieres abrir una, créala con el spec chiquito del `workflow.md §2`.
- **No hay agente `zeiki-pipeline-runner` todavía** (workflow §8 lo referencia). Se crea cuando se configure CI.

---

## Lo que existe (lo que sí está)

- **Código del cliente:** Flutter app con placeholder, 6 carpetas en `lib/core/` (auth, di, logging, constants, services, tiers), 6 carpetas en `lib/features/` (identidad, fiscal, clientes, reportes, asistencia, configuracion), 7 dependencias declaradas, smoke test.
- **Backend Supabase:** proyecto `iocbqjzmoneulydmeavr` (región `us-east-2`). Tabla `app_tier_features` con RLS + seed + GRANTs. Edge function `feature-flags` deployada (devuelve los flags en JSON). Cliente Dart inicializado en `main.dart`.
- **Runbooks:** `docs/runbooks/secrets.md` (gestión de secretos).
- **Reportes de investigación:** `docs/research/HDU-EXPLORE-001-splash-legacy-report.md`.
- **Tracking de HDUs:** `.mavis/hdu.md` (local, en `.gitignore`).
- **Snapshot del estado:** `docs/current-state.md` (commiteado, en repo).
- **Agentes del orquestador:** `zeiki-implementer`, `zeiki-auditor`, `zeiki-reviewer` en `C:\Users\Pc\.minimax\agents\`.
- **Documentación completa:** Target Architecture, Conventions, Workflow, Git, 11 ADRs (ADR-010 deprecated, movido a `deprecated/`), 1 plantilla (HDU-EXPLORE).
- **Repositorio legacy** `navaworkingspaces-collab/seiki_app` en **read-only indefinido** como respaldo histórico.
  - **Para qué sirve:** consultar algoritmos validados, integraciones probadas, reglas de negocio aprendidas.
  - **Qué NO se hace:** no se commitea ahí, no se reabren HDUs cerradas, no se traen tareas como activas.
  - **Regla clave:** el legacy es **referencia, NO verdad**. Lo que el legacy dice sobre sí mismo (ej. "este bug ya está arreglado") debe verificarse antes de aceptarlo.

---

## Recordatorios clave

- **NO INFERENCIA, SOLO PRUEBAS.** Fuente única: `target-architecture.md §0`. Aplica a TODO (debugging, code review, debates, ADRs, investigación).
- **Check de entendimiento de 3 líneas.** Hugo redacta con sus palabras, Mavis refina sin cambiar la intención. La verificación es trivial: Hugo lee su propia versión refinada y dice "sí, eso es lo que quise decir".
- **Feature flag obligatorio para features nuevas.** CD seguro: una feature nunca llega a usuarios sin pasar por flag primero (Target §10).
- **Conventional Commits + Conventional Comments.** Detalles en `git.md §2` y `workflow.md §7`.
- **Una sola fuente de verdad por concepto.** Si está en dos archivos, es bug. La filosofía vive en Target §0, no se duplica.
- **Los planos NO se preguntan, se aplican.** Si algo está en Target/Conventions/ADR, se hace. Las preguntas son sobre cosas NO documentadas, no sobre decisiones ya tomadas.
- **Lo que el auditor marca, se hace.** Cualquier salida de un agente de revisión requiere acción inmediata, no "follow-up". (Regla 7.)

---

## Cómo se trabaja en Zeiki (resumen)

- **Mavis orquesta, no implementa.** La implementación la hace una sesión de `zeiki-implementer` en background.
- **HDU-EXPLORE previa** (plantilla en `docs/templates/hdu-explore.md`) cuando una HDU toca un sistema externo (SAT, Facturama, código legacy, etc.).
- **Workflow de 12 pasos:** spec → branch → test red → implement → test green → review (3 gates) → pipeline → QA local → commit → PR → cleanup.
- **Review en 3 gates:** `zeiki-reviewer` valida clean code + security + architecture. `zeiki-auditor` valida minimalismo y relevancia.
- **Definition of Done** del workflow es la checklist de cierre.
- **Conventional Comments en code review:** prefijos `nit:` / `issue:` / `question:` / `praise:` / `suggestion:` / `chore:` / `thought:`.
- **Mono-repo:** el código vive en este repo `zeiki`. No hay sub-proyectos ni monorepos separados.
- **Servicios transversales en `lib/core/`** (auth, tiers, services, logging, di, constants). Features en `lib/features/<dominio>/`. Regla: `features → core` permitido, `core → features` prohibido.
- **Carpetas de features/ en español** (`identidad/`, `fiscal/`, etc.) — decisión documentada en `conventions.md §1`. El resto del proyecto sigue `snake_case` en inglés.
- **Formato de migraciones Supabase:** `YYYYMMDDHHMMSS_<slug>.sql` (14 dígitos, sin guión bajo). Idempotentes con `IF NOT EXISTS`. (conventions §12.)

---

## Si la nueva sesión llega aquí y NO arranca por ahí

**Indicadores de contexto perdido** (la sesión está mal, debe parar y releer):

- Menciona "Seiki" o HDUs del legacy (HDU-MANUAL-004/007, HDU-021, etc.) sin que se le pregunte.
- Dice "no hay código" o "vamos de cero" cuando ya hay HDU-001 y HDU-002 mergeadas.
- Sugiere abrir un `current-state.md` "para no perder contexto" (ya existe desde la HDU-001).
- Pregunta qué es Zeiki (la respuesta está arriba, en este archivo).
- Habla de Fase 2 o superior sin haber leído Target §4.

**Si la sesión muestra estos indicadores:** pedirle que relea el orden de lectura obligatorio (incluyendo `current-state.md`). Si insiste, escalar a Hugo.

---

## Cómo se mantiene este archivo

- **Cuándo se actualiza:** cada vez que cambia la estructura del proyecto (nuevos docs, cambio de fase, HDU cerrada que afecta al bootstrap, etc.).
- **Quién lo actualiza:** Mavis (orquestador) con aprobación de Hugo.
- **Formato de cambio:** commit con prefijo `docs(agents):`.
- **Regla:** si este archivo entra en conflicto con `target-architecture.md`, gana Target. Este archivo es el bootstrap, no la fuente de verdad.

---

*Si acabas de llegar a este proyecto: bienvenido. Lee los 5 archivos del orden de lectura + `current-state.md` antes de hacer cualquier otra cosa.*
