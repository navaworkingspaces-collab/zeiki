# Workflow de desarrollo — Zeiki v2

> **Protocolo de trabajo alineado con la [Target Architecture](architecture/target-architecture.md).** Cada cambio (bug, feature, refactor, chore) sigue este flujo.
>
> **Última actualización:** 2026-07-29 (v2 — feedback de Hugo: check de entendimiento, fuera de scope, estados de espera, quema de legacy, migración selectiva)

---

## 🎯 Filosofía

1. **Planos antes de código:** toda HDU que toque estructura, dominio o sistema externo arranca con un spec chiquito aprobado por Hugo.
2. **Test primero, código después:** TDD estricto para flujos críticos.
3. **No inferencia, solo pruebas:** cuando se debuggea, se cita código con archivo:línea.
4. **Sin scope creep:** lo que no está en el spec no se hace; si aparece algo, se registra como HDU nueva.
5. **Calidad de verdad, no métricas de vanidad:** testing basado en matriz de criticidad, no en porcentajes.
6. **Quema la deuda cuando la veas:** archivos legacy, rutas hardcoded, anti-patrones — se limpian, no se acumulan.
7. **Migración selectiva:** del repo anterior se trae solo conocimiento (algoritmos, integraciones), no deuda.

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

**Pregunta clave:** ¿esta HDU toca un sistema externo?

**Sistemas externos incluyen:** SAT, PACs de facturación, APIs de terceros, BD fuera del proyecto, cualquier sistema cuyo contrato no controlamos.

**Si SÍ toca sistema externo:**
1. Crear `HDU-EXPLORE-NNN` previa (research, no implementación).
2. El agente investiga con docs oficiales + pruebas con credenciales reales.
3. Entrega reporte en `docs/research/YYYY-MM-DD-<topic>.md`.
4. La HDU de implementación refina su spec basándose en el reporte.
5. **Sin la exploración, NO se implementa.**

**Si NO toca sistema externo (trabajo interno):** proceder al Paso 1.

**En la spec de CADA HDU declarar:** `Sistemas externos involucrados: SAT (WebService X) / Facturama / Ninguno`.

---

### 1. TRIAGE — Clasificar y priorizar

**Quién:** Mavis.
**Cuándo:** apenas Hugo reporta algo o se detecta una mejora.

**Output:**
- Folio `HDU-XXX` (siguiente número disponible en `.mavis/hdu.md`).
- Clasificación: `bug` | `feature` | `refactor` | `chore`.
- Prioridad: `alta` | `media` | `baja`.
- **Estado:** `pendiente` | `en_progreso` | `en_espera_input` | `completado` | `cancelado`.

> **Nota sobre `en_espera_input`:** es un estado válido. Una HDU se queda en `en_espera_input` cuando necesita input externo (Hugo, un proveedor, evidencia) que no se puede generar ahora. No se considera "olvidada" ni "rota". Se revisa en el snapshot de current-state.

**Acción:** agregar entrada en `.mavis/hdu.md` con folio, título, link al spec.

---

### 2. SPEC — Documentar el problema y la solución

**Quién:** Mavis redacta, Hugo aprueba.
**Cuándo:** después del check de entendimiento y el triage, antes de tocar código.

**Archivo:** `specs/HDU-XXX-slug.md`.

**Plantilla del spec (OBLIGATORIA, no se omite ninguna sección):**

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
- [ ] Cumple con §1-§3 de Target Architecture (principios, atributos, restricciones)
- [ ] No introduce anti-patrones (§14 de Target Architecture)
- [ ] Clean code: …
- [ ] Security: …
- [ ] Tests pasan
- [ ] Pipeline completo pasa
- [ ] QA local con flutter run

## Notas
Links, referencias, contexto adicional.
```

**Acción:** crear spec, linkearlo desde `.mavis/hdu.md`. Hugo debe aprobar el spec completo antes del paso 4.

---

### 3. BRANCH — Rama dedicada

**Quién:** Mavis.
**Cuándo:** spec listo y aprobado.

**Convención:**

| Tipo | Formato |
|------|---------|
| Bug fix | `fix/hdu-XXX-slug` |
| Feature | `feat/hdu-XXX-slug` |
| Refactor | `refactor/hdu-XXX-slug` |
| Chore | `chore/hdu-XXX-slug` |
| Hotfix | `hotfix/hdu-XXX-slug` |

**Comandos:**

```powershell
git checkout main
git pull origin main
git checkout -b fix/hdu-XXX-slug
```

**Regla:** nunca trabajar directo en `main`.

---

### 4. TEST RED — Escribir tests que fallen

**Quién:** agente `seiki-tester` o sesión dedicada.
**Cuándo:** después de crear la rama.

**Objetivo:** escribir tests que **deben fallar** antes de implementar. Esto valida que el test detecta el problema.

- **Bugs:** tests que reproducen el bug.
- **Features:** tests que validan el comportamiento esperado.

**Verificación:** `flutter test test/path/to/new_test.dart` debe mostrar FAILED.

**Para flows críticos** (matriz §11 de Target Architecture): tests más exhaustivos. Para flows de criticidad baja: smoke test mínimo.

---

### 5. IMPLEMENT — Escribir el código

**Quién:** agente `seiki-implementer` o sesión dedicada.
**Cuándo:** tests rojos confirmados.

**Reglas:**
- Código mínimo para pasar los tests.
- **NO** features extra (scope creep).
- **NO** refactorizar código no relacionado.
- Respetar convenciones de `docs/conventions.md`.
- Respetar arquitectura de `docs/architecture/target-architecture.md`.
- Si se reusa código del proyecto anterior, documentar con el porqué.

**Output:** código en los archivos listados en el spec.

---

### 6. TEST GREEN — Validar que ahora pasan

**Quién:** agente `seiki-tester` o sesión dedicada.

```powershell
flutter test test/path/to/new_test.dart
flutter test
```

**Criterio:** todos los tests pasan. Si alguno falla, volver al paso 5.

---

### 7. REVIEW — Clean code + Security + Architecture

**Quién:** agente `seiki-reviewer` o sesión dedicada.

**Gate 1 — Clean code:** nombres, funciones con una responsabilidad, sin código muerto, sin `print()`, sin magic numbers, sin duplicación, sin TODOs sin issue.

**Gate 2 — Security:** sin secrets hardcoded, inputs validados, auth checks, HTTPS, sin logs de datos sensibles, almacenamiento seguro.

**Gate 3 — Architecture (NUEVO en v2):** verificar contra la Target Architecture:
- Cumple con los principios arquitectónicos (§1).
- No viola ninguna restricción (§3).
- No introduce anti-patrones nuevos (§14). Si encuentra uno recurrente, agregarlo.
- Los ADRs vigentes se respetan; si se propone romper uno, se crea un ADR-XXX nuevo en la misma PR.

**Output:** checklist firmado en el spec, sección "Review checklist".

---

### 8. PIPELINE — Suite completa + verify

**Quién:** agente `seiki-pipeline-runner` o sesión dedicada.

**Comandos obligatorios:**

**Flutter (cliente):**
```powershell
flutter analyze
flutter test
flutter build apk --debug
```

**Deno (edge functions) — TODAS, no solo las tocadas en esta HDU:**
```powershell
foreach ($fn in Get-ChildItem "supabase/functions") {
  Push-Location $fn
  deno check index.ts
  deno test --allow-read --allow-env
  Pop-Location
}
```

**Si hay migraciones SQL nuevas:** aplicar a staging, verificar idempotencia.

**Criterio:** TODO pasa 0 errores. Si falla, NO se commitea.

---

### 9. LOCAL QA — Probar en dispositivo real

**Quién:** Hugo.
**Cuándo:** pipeline pasa.

1. `flutter run` en Xiaomi.
2. Verificar **todos** los criterios de aceptación del spec.
3. Probar edge cases (sin internet, con datos vacíos).
4. Capturar logs si algo falla.

**Output:** AC marcados o reporte de qué falló.

---

### 10. COMMIT — Versionar el cambio

**Convención:** ver `docs/conventions.md §3`.

```
<tipo>(<scope>): <descripción corta> [HDU-XXX]

<cuerpo opcional>

Refs: specs/HDU-XXX-slug.md
```

---

### 11. PR — Pull Request

**Quién:** Mavis.
**Cuándo:** commit listo.

```powershell
git push origin <rama>
gh pr create --base main --title "<tipo>(<scope>): <descripción> [HDU-XXX]" --body "..."
```

**Template de PR:** ver `docs/conventions.md §4`.

---

### 12. CLEANUP — Cerrar el ciclo

**Quién:** Mavis.
**Cuándo:** PR mergeado.

1. **Merge a main** (`--no-ff`).
2. **Eliminar rama** (local + remoto).
3. **Actualizar `.mavis/hdu.md`:** estado, fecha de cierre, link al PR.
4. **Actualizar `docs/current-state.md`:** marcar la HDU en su nueva sección.
5. **Actualizar `docs/architecture/target-architecture.md` si aplica:**
   - Si cambió arquitectura → nuevo ADR.
   - Si descubrió anti-patrón nuevo → agregar a §14.
   - Si se difirió una decisión → agregar a §13.1.
6. **Migración selectiva (NUEVO en v2):** si la HDU aporta algo que vale la pena preservar del repo anterior, copiar a `docs/handoffs/` o `docs/features/`. Decisión documentada.
7. **Quema de archivos legacy (NUEVO en v2):** si la HDU dejó archivos obsoletos (código viejo, specs canceladas, docs que ya no aplican), quemarlos según el procedimiento abajo.
8. **Notificar a Hugo:** resumen de qué se hizo, links, follow-ups.

---

## 🔄 Migración selectiva (del repo anterior al nuevo)

**Cuándo se hace:** durante el cleanup de cualquier HDU que toque una feature migrada.

**Qué se trae del repo anterior:**

- ✅ Handoffs con contexto histórico valioso (`docs/handoffs/YYYY-MM-DD-hdu-XXX-*.md` que documenten decisiones o bugs que vale recordar).
- ✅ Lecciones aprendidas que sigan vigentes.
- ✅ Algoritmos, validaciones o integraciones validadas (citando el archivo:línea original).
- ✅ Specs cerradas que documenten reglas de negocio que no están en el código nuevo todavía.

**Qué NO se trae:**

- ❌ Código de la app (ya está reescrito en el nuevo).
- ❌ Tests viejos (se reescriben con el código).
- ❌ Deuda técnica (es la razón de la reescritura).
- ❌ Archivos que ya no apliquen.

**Procedimiento:**

1. Hugo (o Mavis en sesión con Hugo) decide caso por caso.
2. Se copia al nuevo repo con un header que cita el origen: `> Migrado de navaworkingspaces-collab/seiki_app@<commit> en YYYY-MM-DD.`
3. Si el contenido entra en conflicto con la Target Architecture, gana la Target Architecture.

---

## 🗑️ Quema de archivos legacy

**Cuándo se hace:** durante el cleanup, o cuando se detecta un archivo obsoleto.

**Procedimiento:**

1. **Detectar:** archivo sin uso por 6+ meses, o que ya no esté en ningún spec, o reemplazado por algo en la Target Architecture.
2. **Verificar:** confirmar que no hay tests o specs que lo referencien.
3. **Decidir:** ¿se conserva en `docs/archive/YYYY-MM-DD-<filename>` para referencia histórica, o se borra directo?
4. **Ejecutar:** commit dedicado con mensaje `chore(cleanup): archive <archivo> (legacy sin uso)`.
5. **Documentar:** si se conserva en archive/, agregar índice en `docs/archive/README.md`.

**Regla:** no acumular archivos "por si acaso". Si lleva 6 meses sin uso y no está referenciado, se quema.

---

## 🐛 Regla de debug: NO INFERENCIA, SOLO PRUEBAS

**Cuando se debuggea un bug (paso 4-5 del workflow):**

- ❌ NUNCA decir "probablemente pasa X" sin evidencia.
- ✅ SIEMPRE citar código: `archivo:línea`, método, snippet.
- ✅ Si no puedes demostrar algo, marcarlo como "hipótesis a verificar".

**Template de reporte de bug:**

```
🐛 SÍNTOMA
- Usuario reporta: <lo que ve/pasa>

🔍 CÓDIGO INVOLUCRADO (con citas)
- archivo:línea — <qué hace>
- archivo:línea — <qué hace>

🧪 EVIDENCIA
- Test/log/output que confirma

💡 HIPÓTESIS (si aplica)
- "Podría ser X si pasa Y" — cómo verificar

🎯 FIX PROPUESTO
- archivo:línea — cambiar <X> por <Y>
```

---

## 🚨 Excepciones al protocolo

### Hotfix de producción

1. Rama `hotfix/hdu-XXX-slug` directo desde `main`.
2. Spec **mínimo** (problema + fix + un test).
3. Skip review formal (revisión rápida de Hugo).
4. Merge + deploy inmediato.
5. Spec completo **después** como follow-up.

### Cambios triviales (typo, comentario, etc.)

- ✅ Triage
- ✅ Branch
- ⚠️ Tests (solo si cambia comportamiento público)
- ✅ Implement
- ✅ Review
- ⚠️ Pipeline (lite — solo `flutter analyze`)
- ⚠️ QA local (smoke test)
- ✅ Commit + PR + Cleanup

### Cambios solo de docs

Cambios a `docs/`, `target-architecture.md`, este workflow no requieren tests ni pipeline, pero sí commit + push.

---

## 🤖 Para los agentes

Cuando un agente (implementer, tester, reviewer, pipeline-runner) es invocado por este workflow:

1. **Leer el spec completo** antes de actuar.
2. **Devolver el check de entendimiento** (1-2 oraciones de lo que entendiste). Si no coincide con el spec, pararte.
3. **Seguir `target-architecture.md` y `conventions.md`.**
4. **Reportar al orquestador (Mavis)** con resumen estructurado.
5. **Nunca scope creep.** Si encuentras algo fuera de scope, registrarlo como HDU nuevo pero no tocarlo.
6. **Respetar la matriz de criticidad** de §11 de Target Architecture para decidir qué tests son obligatorios y cuáles opcionales.

---

## 📊 Métricas (opcionales, no de vanidad)

Por cada HDU completado, registrar en el PR:

- Tiempo total (triage → cleanup).
- Número de commits.
- Líneas de código agregadas/eliminadas.

**NO se mide:** porcentaje de coverage (es engañoso), número de tests (puede inflarse con tests inútiles).

---

*Si este archivo entra en conflicto con `target-architecture.md`, gana la Target Architecture. Este workflow la implementa, no la contradice.*
