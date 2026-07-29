# `lib/features/configuracion/`

**Dominio:** Configuración. Preferencias del usuario y de la app.

**Features esperadas (Target §6 y §15):**

- Perfil del usuario.
- Plan actual y upgrade.
- Preferencias (notificaciones, idioma).
- Feature flags overrides (testing).

**Restricción (Target §6 Context Map):** Configuración **gobierna** al usuario; no a otros dominios. No modifica data de Identidad, Fiscal, etc.

**Estructura interna (cuando se implemente):**

```
configuracion/
├── data/
├── domain/
└── presentation/
```

Referencia: `docs/architecture/target-architecture.md §6`.
