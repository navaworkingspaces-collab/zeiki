# Workflow de desarrollo — Zeiki

> **Cómo se trabaja en Zeiki.** Este documento es operacional: el "cómo". Las convenciones (qué debe cumplir el código) viven en `conventions.md`. Los comandos y CI/CD viven en `git.md`. Si este workflow cambia, se actualiza aquí.
>
> **Última actualización:** 2026-07-29 (v3 — separar de git, Definition of Done, Code Review, deuda técnica, NO INFERENCIA arriba)

---

## 🧭 Filosofía

> El workflow de Zeiki sigue la **filosofía del proyecto definida en [Target Architecture §0](../architecture/target-architecture.md#0-filosofía-del-proyecto)**. Este documento la aplica al proceso de trabajo, no la duplica.
>
> **Resumen:** **NO INFERENCIA, SOLO PRUEBAS.** Aplica a debugging, code review, debates técnicos, ADRs, investigación, todo. Sin duplicación entre documentos.

1. **Planos antes de código:** toda HDU que toque estructura, dominio o sistema externo arranca con un spec chiquito aprobado por Hugo.
2. **Test primero, código después:** TDD estricto para flujos críticos.
3. **Sin scope creep:** lo que no está en el spec no se hace. Si aparece algo, se registra como HDU nueva.
4. **Calidad de verdad, no métricas de vanidad:** testing basado en matriz de criticidad, no en porcentajes.
5. **Quema la deuda cuando la veas:** archivos legacy, anti-patrones, inconsistencias — se limpian, no se acumulan.
6. **Migración selectiva:** del repo anterior se trae conocimiento, no deuda.

---

## 🛑 Check de entendimiento (ANTES de cualquier paso formal)

**Toda HDU arranca con esto.** Es la salvaguarda principal contra "yo entendí otra cosa".

**Quién:** Mavis (orquestador) redacta, Hugo aprueba.

**Output (3 líneas exactas):**

```
Lo que quieres: <1 línea en palabras de Hugo>
Vas a saber que está bien cuando: <1 línea, criterio verificable>
Esto NO se va a hacer: <1 línea, fuera de scope explícito>
```

**Reglas:**
- Las líneas se escriben en lenguaje de negocio, no técnico.
- Hugo debe poder decir "sí" sin ambigüedad. Si duda, se reformula.
- Solo después del "va" se asigna folio HDU y se redacta el spec completo.
- Si en cualquier paso posterior el implementer descubre que la realidad contradice el check, **se para** y se vuelve a alinear con Hugo.

**Para implementer (agente o sesión dedicada):** antes de tocar código, devolver un resumen de 1-2 oraciones confirmando qué entendió. Si no coincide con el spec, se para.

---

## 📋 Los pasos (0 + 12)

### 0. CLASIFICACIÓN — ¿Toca un sistema externo?

**Quién:** Mavis.
**Cuándo:** apenas se identifica una HDU, antes del triage.

**Pregunta clave:** ¿esta HDU toca un sistema externo? (SAT, PACs, APIs de terceros, BD fuera del proyecto, cualquier sistema cuyo contrato no controlamos).

**Si SÍ:** crear `HDU-EXPLORE-NNN` previa con research + pruebas con credenciales reales. Reporte en `docs/research/`. Sin exploración NO se implementa.

**Si NO:** proceder al Paso 1.

**En la spec de CADA HDU declarar:** `Sistemas externos involucrados: SAT (WebService X) / Facturama / Ninguno`.

---

### 1. TRIAGE

**Quién:** Mavis.

**Output:**
- Folio `HDU-XXX`.
- Tipo: `bug` | `feature` | `refactor` | `chore`.
- Prioridad: `alta` | `media` | `baja`.
- **Estado:** `pendiente` | `en_progreso` | `en_espera_input` | `completado` | `cancelado`.

> **`en_espera_input`:** estado válido. Una HDU se queda aquí cuando necesita input externo (Hugo, un proveedor, evidencia) que no se puede generar ahora. No es "olvidada". Se revisa en el snapshot de current-state.

---

### 2. SPEC

**Quién:** Mavis redacta, Hugo aprueba.

**Archivo:** `specs/HDU-XXX-slug.md`.

**Plantilla OBLIGATORIA** (no se omite ninguna sección):

```markdown
# HDU-XXX — Título corto

**Tipo:** bug | feature | refactor | chore
**Prioridad:** alta | media | baja
**Estado:** pendiente | en_progreso | en_espera_input | completado | cancelado
**Fecha:** YYYY-MM-DD
**Sistemas externos involucrados:** SAT / Facturama / Ninguno
**Dominio(s):** Identidad / Fiscal / Clientes / Reportes / Asistencia / Configuración

## Check de entendimiento (3 líneas)
- Lo que quieres: …
- Vas a saber que está bien cuando: …
- Esto NO se va a hacer: …

## Problema / Motivación
¿Por qué? ¿Qué duele? (1-2 párrafos)

## Criterios de aceptación
- [ ] AC1: … (lo que Hugo ve)
- [ ] AC2: … (lo que el sistema hace, verificable por test)

## Archivos afectados
- `lib/...`
- `test/...`
- `supabase/functions/...`

## Plan técnico (pasos verificables)
1. Paso concreto.
2. Paso concreto.
3. ...

## Tests a escribir (basado en matriz de criticidad)
- Componente / Criticidad / Tipo de test mínimo
- Referencia: §11 de Target Architecture

## Fuera de scope
- …

## Riesgos
- …

## Review checklist
- [ ] Cumple con §1-§3 de Target Architecture
- [ ] No introduce anti-patrones (§14 de Target Architecture)
- [ ] Clean code (ver §Code Review abajo)
- [ ] Security (ver conventions §6)
- [ ] Tests pasan
- [ ] Pipeline completo pasa
- [ ] QA local

## Notas
```

Hugo debe aprobar el spec completo antes del paso 4.

---

### 3. BRANCH

**Quién:** Mavis.

| Tipo | Formato |
|------|---------|
| Bug fix | `fix/hdu-XXX-slug` |
| Feature | `feat/hdu-XXX-slug` |
| Refactor | `refactor/hdu-XXX-slug` |
| Chore | `chore/hdu-XXX-slug` |
| Hotfix | `hotfix/hdu-XXX-slug` |

Nunca trabajar directo en `main`.

---

### 4. TEST RED

**Quién:** seiki-tester o sesión dedicada.

Escribir tests que **deben fallar** antes de implementar. Para bugs: reproducen el bug. Para features: validan el comportamiento esperado.

`flutter test test/path/to/new_test.dart` debe mostrar FAILED.

**Para flujos críticos** (matriz §11 de Target Architecture): tests exhaustivos. Para criticidad baja: smoke test mínimo.

---

### 5. IMPLEMENT

**Quién:** seiki-implementer o sesión dedicada.

- Código mínimo para pasar los tests.
- NO features extra. NO refactors no relacionados.
- Respetar `conventions.md` y `target-architecture.md`.
- Si se reusa código del proyecto anterior, documentar el porqué.

---

### 6. TEST GREEN

Todos los tests pasan. Si falla alguno, volver al paso 5.

---

### 7. REVIEW

**Quién:** seiki-reviewer o sesión dedicada.

**Code Review (qué se busca, qué NO):**

✅ **Se busca:**
- **Bugs** reales o latentes.
- **Riesgos** (memory leaks, race conditions, validaciones faltantes).
- **Complejidad** innecesaria (funciones grandes, abstracciones prematuras).
- **Legibilidad** (nombres, comentarios, organización).
- **Cumplimiento** de Target Architecture y conventions.

❌ **NO se busca:**
- Gustos personales (estilo de código, naming bikeshedding).
- Refactors no relacionados.
- Cambios fuera del scope del spec.

> **Regla:** si el review encuentra algo fuera del scope, se levanta como HDU nueva, no se arregla en este PR.

**Tres gates:**

- **Gate 1 — Clean code:** nombres, funciones con una responsabilidad, sin código muerto, sin magic numbers, sin duplicación, sin TODOs sin issue.
- **Gate 2 — Security:** sin secrets hardcoded, inputs validados, auth checks, sin logs de datos sensibles, almacenamiento seguro.
- **Gate 3 — Architecture (NUEVO en v3):** verificar contra la Target Architecture:
  - Cumple con los principios arquitectónicos (§1).
  - No viola ninguna restricción (§3).
  - No introduce anti-patrones nuevos (§14). Si encuentra uno recurrente, agregarlo.
  - Los ADRs vigentes se respetan; si se propone romper uno, se crea un ADR-XXX nuevo en la misma PR.

---

### 8. PIPELINE

**Quién:** seiki-pipeline-runner o sesión dedicada.

Comandos específicos del stack viven en [`docs/git.md` §6](../git.md#6-pipeline-local). Aquí solo el contrato: **TODO debe pasar 0 errores antes de commitear.** Pre-condiciones de merge en [`docs/git.md` §3](../git.md#3-merge).

---

### 9. LOCAL QA

**Quién:** Hugo.

1. Probar en dispositivo real.
2. Verificar **todos** los criterios de aceptación del spec.
3. Probar edge cases.
4. Capturar logs si algo falla.

---

### 10. COMMIT

Convención completa en [`docs/git.md` §2](../git.md#2-commits). Resumen:

```
<tipo>(<scope>): <descripción corta> [HDU-XXX]

<cuerpo opcional>

Refs: specs/HDU-XXX-slug.md
```

---

### 11. PR

Template y proceso en [`docs/git.md` §5](../git.md#5-pull-requests). Resumen: descripción + check de entendimiento + checklist.

---

### 12. CLEANUP

1. **Merge a main** (`--no-ff`).
2. **Eliminar rama** (local + remoto).
3. **Actualizar `.mavis/hdu.md`:** estado, fecha de cierre, link al PR.
4. **Actualizar `docs/current-state.md`:** marcar la HDU en su nueva sección.
5. **Actualizar `target-architecture.md` si aplica:** nuevo ADR, anti-patrón nuevo, decisión diferida.
6. **Migración selectiva** (si aplica): traer del repo anterior lo que valga la pena.
7. **Quema de archivos legacy** (si aplica): limpiar lo que quedó obsoleto.
8. **Notificar a Hugo:** resumen de qué se hizo, links, follow-ups.

---

## ✅ Definition of Done (DoD)

Una HDU está **terminada** cuando se cumplen TODAS estas condiciones. Cualquier excepción se documenta con razón.

- [ ] Cumple los criterios de aceptación del spec (verificados en QA local).
- [ ] Tests escritos y pasando (al menos los definidos en la spec).
- [ ] Tests de regression incluidos si la HDU arregla un bug.
- [ ] `flutter analyze` sin warnings nuevos (los warnings preexistentes justificados siguen OK).
- [ ] Pipeline completo pasa (ver `docs/git.md`).
- [ ] Code review aprobado (3 gates: clean code, security, architecture).
- [ ] PR mergeado a `main` con `--no-ff`.
- [ ] Rama eliminada (local y remoto).
- [ ] `hdu.md` actualizado con estado y link.
- [ ] `current-state.md` actualizado.
- [ ] `target-architecture.md` actualizado si hubo cambio estructural.
- [ ] Migración selectiva hecha (si aplica).
- [ ] Quema de legacy hecha (si aplica).
- [ ] Hugo notificado con resumen + links.

**Si una DoD no se cumple:** la HDU vuelve a `en_progreso` y se asigna a quien pueda cerrarla.

---

## 💸 Deuda técnica

> **Regla v3 (NUEVO):** la deuda escondida nunca desaparece. Si se introduce, se documenta. Sin excepciones.

### Cuándo se introduce deuda

- Decisión consciente para salir de un bloqueo ("lo arreglo bien en la siguiente HDU").
- Workaround conocido para un bug de un proveedor externo.
- Migración parcial de una pieza que se completará después.

### Cómo se documenta

- **Issue o HDU** que la paga: `Deuda pagada por: HDU-XXX` o `Issue #N`.
- **Fecha de creación** de la deuda.
- **Justificación** de por qué se introdujo (1-2 líneas).
- **Costo estimado** de pagarla (cuándo se vuelve insoportable).

**Dónde:**

- Comentario en el código con el formato `// DEBT(hdu-XXX, YYYY-MM-DD): descripción. Pagada por HDU-YYY.`
- Entrada en `.mavis/technical-debt.md` (catálogo global).
- Mención en el PR que la introduce.

### Revisión periódica

- En el cleanup de cada HDU, revisar si la HDU cierra deudas pendientes.
- En el snapshot de `current-state.md`, listar las 5 deudas más viejas o más costosas.

---

## 🔄 Migración selectiva (del repo anterior al nuevo)

**Cuándo:** durante el cleanup de cualquier HDU que toque una feature migrada.

**Qué se trae:**

- ✅ Handoffs con contexto histórico valioso.
- ✅ Lecciones aprendidas que sigan vigentes.
- ✅ Algoritmos, validaciones o integraciones validadas (citando origen).
- ✅ Specs cerradas que documenten reglas de negocio.

**Qué NO se trae:**

- ❌ Código de la app (ya está reescrito).
- ❌ Tests viejos.
- ❌ Deuda técnica.
- ❌ Archivos que ya no apliquen.

**Procedimiento:**

1. Decisión caso por caso (Hugo + Mavis).
2. Copia al nuevo repo con header: `> Migrado de navaworkingspaces-collab/seiki_app@<commit> en YYYY-MM-DD.`
3. Si entra en conflicto con Target Architecture, gana Target Architecture.

---

## 🗑️ Quema de archivos legacy

**Cuándo:** durante cleanup, o cuando se detecta un archivo obsoleto.

**Procedimiento:**

1. **Detectar:** archivo sin uso por 6+ meses, o que no esté en ningún spec, o reemplazado.
2. **Verificar:** confirmar que no hay tests o specs que lo referencien.
3. **Decidir:** ¿se conserva en `docs/archive/YYYY-MM-DD-<filename>` o se borra directo?
4. **Ejecutar:** commit `chore(cleanup): archive <archivo> (legacy sin uso)`.
5. **Documentar:** si se conserva en archive/, agregar índice en `docs/archive/README.md`.

**Regla:** no acumular "por si acaso". Si lleva 6 meses sin uso y no está referenciado, se quema.

---

## 🚨 Excepciones al protocolo

### Hotfix de producción

1. Rama `hotfix/hdu-XXX-slug` directo desde `main`.
2. Spec **mínimo** (problema + fix + un test).
3. Skip review formal (revisión rápida de Hugo).
4. Merge + deploy inmediato.
5. Spec completo **después** como follow-up.

### Cambios triviales (typo, comentario, etc.)

- ✅ Triage, branch, implement, review, commit, PR, cleanup.
- ⚠️ Tests: solo si cambia comportamiento público.
- ⚠️ Pipeline: lite (solo analyzer).
- ⚠️ QA: smoke test.

### Cambios solo de docs

Cambios a `docs/`, `target-architecture.md`, este workflow, `conventions.md`, `git.md` no requieren tests ni pipeline, pero sí commit + push.

---

## 🤖 Para los agentes

Cuando un agente es invocado por este workflow:

1. **Leer el spec completo** antes de actuar.
2. **Devolver el check de entendimiento** (1-2 oraciones). Si no coincide, pararte.
3. **Seguir `target-architecture.md` y `conventions.md`.**
4. **Reportar al orquestador (Mavis)** con resumen estructurado.
5. **Nunca scope creep.** Lo que esté fuera, HDU nueva.
6. **Respetar la matriz de criticidad** para decidir tests obligatorios vs opcionales.

---

*Si este archivo entra en conflicto con `target-architecture.md`, gana la Target Architecture. Este workflow la implementa, no la contradice.*
