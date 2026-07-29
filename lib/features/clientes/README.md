# `lib/features/clientes/`

**Dominio:** Clientes. Gestión de las entidades receptoras de CFDIs.

**Features esperadas (Target §6 y §15):**

- Alta de clientes.
- Validación de RFC.
- Direcciones fiscales.

**Restricción (Target §6):** este dominio NO accede a SAT ni Facturama. Si necesita información de un cliente que está en un CFDI, la pide al dominio Fiscal (no a la BD directo).

**Estructura interna (cuando se implemente):**

```
clientes/
├── data/
├── domain/
└── presentation/
```

Referencia: `docs/architecture/target-architecture.md §6`.
