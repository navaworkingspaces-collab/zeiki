# ADR-004: BLoC para state management

**Estado:** Aceptado
**Fecha:** 2026-07-29

## Contexto

Zeiki tiene pantallas con estado no trivial: loading, error, datos asíncronos, transiciones complejas. El estado a veces es local a una pantalla, a veces compartido entre varias. La UI no debe conocer la fuente de los datos, solo consumirlos.

## Decisión

**`flutter_bloc`** para todo estado no trivial.

- **Eventos:** verbos en pasado o sustantivos (`AuthSignInWithEmailRequested`).
- **Estados:** adjetivos o sustantivos (`AuthLoading`, `AuthAuthenticated`).
- **`Equatable`** en todos los eventos y estados.
- **Lógica de negocio en el BLoC** (vía casos de uso), nunca en widgets.
- **Side effects** (navegación, snackbars) en el `listener` del `BlocConsumer`, no en el BLoC.

## Por qué

- **Patrón explícito:** event → state. El flujo es visible, no implícito.
- **Testeable con `bloc_test`:** transiciones de estado se prueban sin widgets.
- **Separación UI / lógica:** el widget solo consume estado, no decide.
- **Estándar de la industria:** devs nuevos lo reconocen.

## Alternativas consideradas

- **`setState` puro:** simple pero no escala a estado compartido. Mezcla UI con lógica.
- **Provider / Riverpod:** viables, más simples que BLoC, pero menos explícitos en el flujo de eventos. Útiles para estado derivado simple, no para flujos complejos.
- **GetX:** todo-en-uno (state + DI + navegación). Acopla demasiado, fomenta anti-patrones (servicios estáticos).
- **Redux:**过度 para una app móvil. Boilerplate alto.

## Trade-offs

- **A favor:** explícito, testeable, separa UI de lógica.
- **En contra:** curva de aprendizaje (aceptable), boilerplate para pantallas muy simples (aceptable: el costo se paga en claridad, no en líneas).

## Cuándo se revisa

- N/A. Decisión de state management. Solo se reconsidera si se cambia el patrón completo (ej. a Flutter 4 con state nativo).
