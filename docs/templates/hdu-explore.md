# Plantilla — HDU-EXPLORE

> **Esta plantilla se usa para HDU-EXPLORE-XXX**, que son HDUs de **research** sobre sistemas externos (SAT, Facturama, cualquier proveedor cuyo contrato no controlamos). Se crean como pre-requisito de una HDU de implementación cuando el sistema externo es nuevo, su API cambió, o hay duda sobre el comportamiento.

## Estructura del archivo

`specs/HDU-EXPLORE-XXX-<slug>.md`

## Plantilla

```markdown
# HDU-EXPLORE-XXX — Título de la exploración

**Tipo:** chore (research)
**Prioridad:** alta | media | baja
**Estado:** pendiente | en_progreso | completado | cancelado
**Fecha:** YYYY-MM-DD
**Sistema externo a explorar:** SAT (WebService X) / Facturama / Otro
**HDU de implementación que depende de esto:** HDU-YYY (o "TBD")

---

## Contexto

¿Por qué se necesita esta exploración? Qué duda o riesgo justifica la inversión de tiempo.

## Pregunta(s) a responder

Lista concreta de lo que esta exploración debe resolver. Si la pregunta es "cómo se comporta X", reformular a verificable.

- ¿El campo `Estatus` del XML del CFDI existe? ¿Dónde? ¿Con qué valores?
- ¿Cuál es el timeout real del WebService de Solicitud de Descarga?
- ¿Cuántos reintentos soporta el SAT antes de marcar la solicitud como `5004`?

## Hipótesis inicial

Qué creemos que es cierto antes de investigar. Esto se valida o refuta en los hallazgos.

- Hipótesis 1: "el campo X está en la sección Y del XML".
- Hipótesis 2: "el timeout es de 6 minutos con backoff exponencial".

## Plan de experimentación

Pasos concretos para resolver las preguntas. Cada paso debe ser ejecutable sin ambigüedad.

1. Leer la documentación oficial de `<URL>`. Anotar la versión del documento y fecha.
2. Hacer una llamada real al WebService con credenciales de prueba.
3. Capturar el response completo (XML, headers, status).
4. Comparar con la documentación oficial.
5. Si hay diferencia, documentar la diferencia como "comportamiento real vs documentado".

## Hallazgos

Resultado de la experimentación. Se llena al FINAL, no durante.

- **Pregunta 1:** respuesta con evidencia (cita del response, captura, log).
- **Pregunta 2:** respuesta con evidencia.
- **Hallazgo sorpresa:** cualquier cosa que descubrimos que NO preguntamos pero es relevante.

## Conclusiones y recomendaciones

- ¿La hipótesis inicial era correcta? Sí/No/Parcial.
- ¿Qué cambia en el spec de la HDU de implementación gracias a esta exploración?
- ¿Hay riesgo nuevo descubierto? Si sí, describir.
- ¿Se requiere otra HDU-EXPLORE antes de implementar? (a veces una exploración abre más preguntas)

## Evidencia

- Capturas, logs, responses XML, links a docs.
- Cada pieza de evidencia con timestamp y condiciones (qué credenciales se usaron, qué endpoint, qué parámetros).

## Referencias

- Documentación oficial (URL, fecha de consulta, versión).
- Issues / tickets que motivaron la exploración.
- ADRs relacionados.
```

## Reglas

- **Una exploración = una pregunta o conjunto de preguntas relacionadas.** Si la exploración se bifurca, se divide en dos.
- **No se implementa código en una HDU-EXPLORE.** Solo research. Si necesitas implementar algo para probar, es una HDU-EXPLORE con un spike corto dentro.
- **El reporte se commitea al repo.** No queda en una sesión, no se pierde en chat.
- **Las conclusiones son vinculantes.** Si la exploración dice "X no se puede", la HDU de implementación respeta eso (o se reabre la exploración).
- **Status al cerrar:** `completado` (con reporte), `cancelado` (con razón), o `en_espera_input` (necesita algo externo).
