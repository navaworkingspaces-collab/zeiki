# `lib/core/constants/`

Reglas de negocio que no son obvias desde el código y constantes técnicas recurrentes.

**Capas (conventions §10):**

- **Reglas de negocio** (catálogo de regímenes fiscales, topes de ISR) → aquí.
- **Constantes técnicas** (`maxRetries`, `timeout`) → también aquí o en el archivo que las usa si son muy locales.

**Regla:** una sola fuente de verdad por constante. Si un valor existe en dos archivos, hay un bug latente.

**Estado:** vacío. Se llena cuando la primera feature necesite reglas de negocio.
