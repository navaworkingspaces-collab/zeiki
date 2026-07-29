# ADR-009: Reescritura desde cero, con reutilización de conocimiento

**Estado:** Aceptado
**Fecha:** 2026-07-29

## Contexto

Zeiki venía acumulando deuda técnica: rutas hardcoded en `main.dart`, features sin Clean Architecture, anti-patrones recurrentes, dependencias cruzadas. Cada cambio nuevo rompía algo viejo. La deuda crecía más rápido que las features.

**Punto crítico:** la app NO tiene clientes en producción. No hay riesgo de "valle" donde los usuarios se quedan sin herramienta.

## Decisión

**Reescritura desde cero**, sin migración del código del proyecto anterior. Lo que SÍ se conserva: el conocimiento (algoritmos validados, integraciones probadas, reglas de negocio aprendidas).

- **NO se migra código:** el código del proyecto anterior no se copia. Se reescribe siguiendo la Target Architecture.
- **SÍ se reutiliza conocimiento:** si hay un algoritmo para calcular impuestos que ya está validado, se lee, se entiende, y se reimplementa en el código nuevo (citando el origen). Si hay una integración con el SAT que costó 2 semanas validar, se usa el mismo approach.
- **Disciplina:** toda reutilización se documenta con la razón. Si no se puede explicar por qué se reusa, se reescribe.

## Por qué

- **La deuda técnica acumulada hace más rápida la reescritura que la mejora incremental.** Mejorar 6 rutas hardcoded, migrar 7 features a Clean Architecture, limpiar deprecaciones: es más trabajo que reescribir desde la Target Architecture.
- **App sin clientes en producción elimina el riesgo del "valle"** (período donde la app vieja no funciona y la nueva tampoco). No hay nadie a quien dejar sin herramienta.
- **Reutilizar conocimiento no es arrastrar deuda.** Un algoritmo validado es conocimiento, no código muerto. La disciplina está en distinguir uno de otro.

## Alternativas consideradas

- **Mejora incremental** (feature por feature, ir pagando deuda): más segura en proyectos con clientes, pero más lenta. La deuda crecía más rápido que el ritmo de pago.
- **Migración gradual** (BFF, strangler pattern): válida para proyectos grandes, excesiva para un equipo de 1 persona con app sin clientes.
- **Fork del proyecto anterior y refactor en el mismo repo:** arrastra toda la historia de git, las dependencias rotas, el esquema de base de datos. La deuda viaja con el código.
- **Tirar todo (código Y conocimiento):** pierde 6+ meses de aprendizaje sobre CFDI 4.0, descarga SAT, validaciones. Innecesario.

## Trade-offs

- **A favor:** arranque limpio, sin deuda, arquitectura correcta desde el día 1, conocimiento conservado.
- **En contra:** se requiere disciplina para distinguir "reutilizar lo bueno" de "arrastrar lo malo". Sin esa disciplina, la reescritura se convierte en copia disfrazada.

## Procedimiento de reutilización

1. **Identificar qué se quiere reusar** del proyecto anterior (algoritmo, integración, validación).
2. **Leer el código original** y entender la intención (no copiar y pegar).
3. **Reimplementar** en el código nuevo siguiendo la Target Architecture.
4. **Documentar** con: `> Basado en: navaworkingspaces-collab/seiki_app@<commit>.<archivo>:<línea>. Adaptado a la Target Architecture v2.`
5. **Testear** exhaustivamente — no se asume que porque funcionaba antes, funciona ahora (el contexto cambió).

## Cuándo se revisa

- N/A. Ya se ejecutó. Se reconsidera solo si la reescritura misma resulta ser un error (ej. aparecen problemas que no se anticiparon), en cuyo caso se documenta como lección.

## Migración selectiva de docs (no código)

- ✅ Handoffs con contexto histórico valioso: SÍ se migran.
- ✅ Lecciones aprendidas que sigan vigentes: SÍ se migran.
- ✅ Specs cerradas que documenten reglas de negocio: SÍ se migran.
- ❌ Código de la app: NO.
- ❌ Tests viejos: NO.
- ❌ Deuda técnica: NO.

Procedimiento detallado en `docs/workflow.md` §Migración selectiva.
