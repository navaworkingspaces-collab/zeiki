# AGENTS.md — Zeiki

> **Bootstrap de sesión.** Mavis (o cualquier agente) lee este archivo **PRIMERO** al abrir una sesión en este proyecto. Sin leer el resto del repo, este archivo da el contexto mínimo para no perderse.
>
> **Última actualización:** 2026-07-29

---

## Identidad del proyecto

- **Nombre:** Zeiki (con Z).
- **Qué es:** App móvil (Flutter) para facturación CFDI 4.0 en México. Reescritura desde cero.
- **Estado:** Fase 1 — MVP. **Sin código todavía.**
- **Stack:** Flutter + Supabase (Postgres + Auth + Edge Functions + Storage). Detalle en `target-architecture.md`.
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

- Revisa `target-architecture.md` → sección "Documentos pendientes" (qué falta crear).
- Si la sesión es de implementación, revisa `docs/adr/` (las otras 9 decisiones de stack).

**NO empieces a codear, NO propongas features, NO generes specs sin haber leído los 5 archivos de arriba.**

---

## Lo que NO existe (a propósito)

- **No hay HDUs abiertas.** Cero. Si quieres abrir una, créala con el spec chiquito del `workflow.md §2`.
- **No hay `current-state.md`.** No se necesita hasta cerrar la primera HDU.
- **No hay código.** Vamos de cero.
- **No hay sistema de tracking de HDUs.** `.mavis/hdu.md` se crea cuando abras la primera HDU.
- **No hay agentes/skills específicos del repo todavía** (`.harness/reins/`, `.harness/skills/`). Se crean cuando arranque la primera implementación.

---

## Lo que existe (lo que sí está)

- Documentación completa: Target Architecture, Conventions, Workflow, Git, 10 ADRs, 1 plantilla (HDU-EXPLORE).
- Repositorio legacy `navaworkingspaces-collab/seiki_app` en **read-only indefinido** como respaldo histórico.
  - **Para qué sirve:** consultar algoritmos validados, integraciones probadas, reglas de negocio aprendidas.
  - **Qué NO se hace:** no se commitea ahí, no se reabren HDUs cerradas, no se traen tareas como activas.

---

## Recordatorios clave

- **NO INFERENCIA, SOLO PRUEBAS.** Fuente única: `target-architecture.md §0`. Aplica a TODO (debugging, code review, debates, ADRs, investigación).
- **Check de entendimiento de 3 líneas.** Hugo redacta con sus palabras, Mavis refina sin cambiar la intención. La verificación es trivial: Hugo lee su propia versión refinada y dice "sí, eso es lo que quise decir".
- **Feature flag obligatorio para features nuevas.** CD seguro: una feature nunca llega a usuarios sin pasar por flag primero (Target §10).
- **Conventional Commits + Conventional Comments.** Detalles en `git.md §2` y `workflow.md §7`.
- **Una sola fuente de verdad por concepto.** Si está en dos archivos, es bug. La filosofía vive en Target §0, no se duplica.

---

## Cómo se trabaja en Zeiki (resumen)

- **Mavis orquesta, no implementa.** La implementación la hace una sesión de `zeiki-implementer` (cuando se cree).
- **HDU-EXPLORE previa** (plantilla en `docs/templates/hdu-explore.md`) cuando una HDU toca un sistema externo (SAT, Facturama, etc.).
- **Workflow de 12 pasos:** spec → branch → test red → implement → test green → review → pipeline → QA local → commit → PR → cleanup.
- **Definition of Done** del workflow es la checklist de cierre.
- **Conventional Comments en code review:** prefijos `nit:` / `issue:` / `question:` / `praise:` / `suggestion:` / `chore:` / `thought:`.
- **Mono-repo:** el código vive en este repo `zeiki`. No hay sub-proyectos ni monorepos separados.
- **Servicios transversales en `lib/core/`** (auth, tiers, services, logging, di, constants). Features en `lib/features/<dominio>/`. Regla: `features → core` permitido, `core → features` prohibido.

---

## Si la nueva sesión llega aquí y NO arranca por ahí

**Indicadores de contexto perdido** (la sesión está mal, debe parar y releer):

- Menciona "Seiki" o HDUs del legacy (HDU-MANUAL-004/007, HDU-021, etc.) sin que se le pregunte.
- Propone migrar código del proyecto anterior.
- Pregunta qué es Zeiki (la respuesta está arriba, en este archivo).
- Habla de Fase 2 o superior sin haber leído Target §4.
- Sugiere abrir un `current-state.md` "para no perder contexto" (ya platicamos que no se necesita hasta cerrar la primera HDU).

**Si la sesión muestra estos indicadores:** pedirle que relea el orden de lectura obligatorio. Si insiste, escalar a Hugo.

---

## Cómo se mantiene este archivo

- **Cuándo se actualiza:** cada vez que cambia la estructura del proyecto (nuevos docs, cambio de fase, nuevo doc raíz, etc.).
- **Quién lo actualiza:** Mavis (orquestador) con aprobación de Hugo.
- **Formato de cambio:** commit con prefijo `docs(agents):`.
- **Regla:** si este archivo entra en conflicto con `target-architecture.md`, gana Target. Este archivo es el bootstrap, no la fuente de verdad.

---

*Si acabas de llegar a este proyecto: bienvenido. Lee los 5 archivos del orden de lectura antes de hacer cualquier otra cosa.*
