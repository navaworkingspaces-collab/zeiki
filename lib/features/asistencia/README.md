# `lib/features/asistencia/`

**Dominio:** Asistencia. Interacción con el usuario asistida por modelos (LLM).

**Features esperadas (Target §6 y §15):**

- Cálculo fiscal básico asistido.
- Recomendaciones al usuario.
- (Fase 2+) Chat fiscal.

**Restricción CRÍTICA (Target §6 Aclaración):** Asistencia es **cross-cutting solo-lector**. Lee de Reportes, Fiscal y Clientes para dar contexto al LLM. **NO escribe directamente en ningún otro dominio.**

Si Asistencia recomienda una acción (ej. "clasificar este CFDI como deducible"):

1. Asistencia expone un `RecommendationEntity` con la sugerencia.
2. La UI muestra la sugerencia al usuario.
3. Si acepta, se dispara el caso de uso del **dominio dueño** (Fiscal).
4. Asistencia no se entera.

**Estructura interna (cuando se implemente):**

```
asistencia/
├── data/        # Cliente LLM
├── domain/      # Entidades (Recommendation, ChatMessage) + casos de uso
└── presentation/
```

Referencia: `docs/architecture/target-architecture.md §6`.
