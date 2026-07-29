# `lib/features/fiscal/`

**Dominio:** Fiscal. Único dominio que habla con SAT y Facturama (Target §6 Context Map).

**Features esperadas (Target §6 y §15):**

- Descarga masiva de CFDIs del SAT.
- Timbrado con Facturama.
- Gestión de eFirma.
- Cancelaciones.

**Riesgo de aislamiento:** si el SAT o Facturama cambia su API, **solo** este dominio se modifica. Ningún otro dominio toca esos sistemas externos.

**Estructura interna (cuando se implemente):**

```
fiscal/
├── data/        # Repositorios + datasources (SAT SOAP, Facturama REST)
├── domain/      # Entidades (Cfdi, Factura) + casos de uso
└── presentation/ # Pages + BLoCs
```

Referencia: `docs/architecture/target-architecture.md §6`.
