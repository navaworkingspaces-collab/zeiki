# Plantilla — BUG-XXX

> **Esta plantilla se usa para BUG-XXX**, que son HDUs de **bug fix** (corrección de defectos detectados en producción o en QA). Son separadas de las HDU-XXX (features / explore / chore) porque tienen su propio contador y su propio lifecycle (típicamente cortos, enfocados, urgentes cuando son bloqueantes).

## Numeración

- **BUG-XXX:** bugs (este template).
- **HDU-XXX:** features / chores.
- **HDU-EXPLORE-XXX:** research sobre sistemas externos.

Los contadores son **independientes**: BUG-001, BUG-002, ... no comparten número con HDU-001, HDU-002, ... Si en una sesión se descubre un bug durante una HDU, se abre un BUG aparte (no se mete en el scope de la HDU en curso). El merge de la HDU no espera al fix del BUG (a menos que el BUG sea bloqueante, en cuyo caso se aborta la HDU y se trata el BUG primero).

## Estructura del archivo

`specs/BUG-XXX-<slug>.md`

## Plantilla

```markdown
# BUG-XXX — Título del bug (síntoma, NO causa)

**Tipo:** bug
**Prioridad:** alta | media | baja
**Estado:** pendiente | en_progreso | completado | cancelado | en_espera_input
**Fecha de apertura:** YYYY-MM-DD
**Reporter:** Hugo (QA en device) | Mavis (en sesión) | Usuario (producción) | Crash log
**HDU relacionada que introdujo el bug (o NO si es pre-existente):** HDU-XXX o "pre-existente"
**Sistemas externos afectados:** Google OAuth / Supabase Auth / Push / etc.

---

## Contexto

¿En qué HDU / feature se descubrió el bug? ¿Qué estaba haciendo el usuario? ¿Cuándo se detectó?

## Síntoma

Qué observa el usuario (NO la causa). Comportamiento observable, no implementación. Cita logs, capturas, o video si hay.

## Comportamiento esperado

Qué debería pasar en vez del síntoma. Cita el spec de la HDU relacionada o el contrato del sistema externo.

## Pasos para reproducir

Lista mínima de pasos para reproducir el bug de forma determinística. Cada paso debe ser ejecutable.

1. Cold start de la app (`flutter run -d <deviceId>`).
2. Navegar a `<ruta>`.
3. Tocar `<botón>`.
4. Seleccionar `<opción>`.
5. **Observar:** `<síntoma>`.

## Ambiente

- **Device:** Xiaomi 2203129G (Android 14 API 34) u otro.
- **OS:** Android / iOS / web.
- **App version:** commit SHA o tag.
- **Network:** WiFi del usuario / 4G / airplane mode.
- **Estado de sesión:** logged out / logged in.
- **Variables relevantes:** flag de Supabase X = true/false, etc.

## Causa probable

Hipótesis sobre la causa raíz. Cita con `archivo:línea`. Si hay varias hipótesis, rankéalas por probabilidad.

- **Hipótesis 1 (más probable):** `<descripción>` — ver `path/al/archivo.dart:LINE`.
- **Hipótesis 2:** `<descripción>` — ver `path/al/archivo.dart:LINE`.
- **Hipótesis 3 (menos probable):** `<descripción>`.

## Plan de investigación

Pasos para confirmar o descartar las hipótesis. **No empezar a programar hasta confirmar la causa raíz.**

1. Leer `<archivo>` y verificar el comportamiento actual.
2. Reproducir el bug con `flutter run` y capturar `adb logcat | grep -i '<keyword>'`.
3. Verificar config en `<Google Cloud Console / Supabase dashboard>`.
4. ...
5. **Si hipótesis 1 confirmada:** aplicar fix X. Si no, pasar a hipótesis 2.

## Plan de fix

Una vez confirmada la causa raíz, qué se cambia. Code sketch si ayuda. Cita el archivo y la línea que se va a modificar.

- `path/al/archivo.dart:LINE` — cambio: `<descripción del cambio>`.
- ...

## Acceptance Criteria (criterio de "listo")

Lista verificable de lo que debe pasar para considerar el BUG cerrado. Cada AC es testeable.

- [ ] **AC1:** reproducir el bug con los pasos de arriba antes del fix → debe fallar (síntoma presente).
- [ ] **AC2:** aplicar el fix.
- [ ] **AC3:** reproducir el bug con los mismos pasos después del fix → debe pasar (síntoma ausente).
- [ ] **AC4:** regression test automatizado: un test que cubra el happy path (puede ser con mocks si la integración real requiere credenciales). Falla si alguien revierte el fix.
- [ ] **AC5:** QA en device real (Xiaomi 2203129G): Hugo confirma que el flujo afectado funciona end-to-end.
- [ ] **AC6:** suite completa de tests sigue verde (no regresiones).
- [ ] **AC7:** `flutter analyze` 0 issues.

## Out of scope

Qué NO se arregla en este BUG (sale en HDU aparte).

- Refactor del código aunque se vea la oportunidad.
- Mejorar UX aunque el bug exponga una mala UX.
- Agregar features relacionadas.
- Otros bugs que se descubran durante la investigación (se abren como BUG aparte).

## QA esperado

Qué va a verificar Hugo en el Xiaomi antes de aprobar el merge.

1. Cold start con app cerrada (force-stop + reopen).
2. Navegar a `<ruta>`.
3. Tocar `<botón>` → debe completarse el flujo.
4. Verificar que no hay errores visuales / en logcat.

## Referencias

- Runbooks relevantes.
- HDU relacionada (la que introdujo el bug, si aplica).
- Documentación oficial de los sistemas externos.
- Capturas, logs, crash reports.
```

## Reglas

- **El síntoma va en el título, NO la causa.** "Google Sign-In no completa el flujo" ✅. "Falla el `signInWithGoogle()`" ❌ (eso es causa hipotética, no síntoma).
- **Una BUG = un síntoma.** Si la investigación descubre que el mismo síntoma tiene 2 causas distintas, NO se divide (se arreglan ambas en la misma BUG). Si descubre 2 síntomas distintos, se abren 2 BUGs.
- **El plan de investigación es OBLIGATORIO.** No se empieza a codear antes de confirmar la causa raíz. Un BUG donde "se asume la causa y se aplica el fix" tiene 50% de probabilidad de no arreglar nada.
- **El regression test es OBLIGATORIO** (AC4). Un fix sin regression test puede regresar en cualquier PR futuro. Esta es la diferencia entre "arreglar el bug" y "arreglar el bug + proteger contra su regreso".
- **El QA en device real es OBLIGATORIO** (AC5). Por la regla memoria #8: tests verde NO es app funcionando. Para BUGs de OAuth / push / deep links / biometría nativa / pagos, el QA en device es BLOQUEANTE.
- **Status al cerrar:** `completado` (con ACs verificados) o `cancelado` (con razón — ej. "el bug no se reproduce en versiones más nuevas, se cierra sin fix").
- **No se mezcla BUG con la HDU que la descubrió.** Si durante una HDU se descubre un bug, se aborta el PR de la HDU (si es bloqueante) o se mergea la HDU y se abre la BUG aparte (si no es bloqueante). El bug no se mete como "chore" en la HDU.
