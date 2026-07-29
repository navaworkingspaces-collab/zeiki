# `lib/features/reportes/`

**Dominio:** Reportes. Cálculos y vistas sobre los datos fiscales.

**Features esperadas (Target §6 y §15):**

- Dashboard con IVA, ISR y totales.
- Métricas fiscales.
- Exportación.

**Restricción CRÍTICA (Target §5 caso especial):** este dominio es **cross-cutting solo-lector**. Lee de Fiscal y Clientes, pero **NUNCA escribe**. Si una vista lleva a una acción (ej. "marcar como deducible"), la dispara el dominio dueño de esa data.

**Estructura interna (cuando se implemente):**

```
reportes/
├── data/        # Repos que apuntan a repos de otros dominios (NO a la BD directo)
├── domain/      # Entidades + casos de uso (devuelven agregados, no CRUD)
└── presentation/
```

Referencia: `docs/architecture/target-architecture.md §6`.
