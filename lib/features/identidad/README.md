# `lib/features/identidad/`

**Dominio:** Identidad. Responsable de quién es el usuario, cómo se autentica y cómo se recupera la sesión.

**Features esperadas (Target §6 y §15):**

- Login con email.
- Login con Google (OAuth via proxy, ver ADR-007).
- Biometría para re-autenticación.
- Recuperación de sesión.

**Estructura interna (cuando se implemente):**

```
identidad/
├── data/        # Repositorios (Supabase, secure storage)
├── domain/      # Entidades (User, Session) + casos de uso
└── presentation/ # Pages (LoginPage, etc.) + BLoCs
```

Referencia: `docs/architecture/target-architecture.md §6`.
