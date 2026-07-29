# ADR-001: Clean Architecture

**Estado:** Aceptado
**Fecha:** 2026-07-29

## Contexto

Zeiki necesita una estructura de código que sobreviva a cambios en frameworks, bases de datos, proveedores externos y equipos. La complejidad del dominio (CFDI 4.0, descarga SAT, eFirma) merece estar protegida de la volatilidad del stack técnico.

## Decisión

Clean Architecture por feature / dominio. Cada feature/dominio sigue tres capas:

- **`domain/`** — entidades, casos de uso, interfaces de repositorios. Sin dependencias de Flutter ni de Supabase. Puro Dart.
- **`data/`** — implementación de los contratos de `domain/`. Habla con Supabase, SAT, Facturama. Convierte DTOs a entidades.
- **`presentation/`** — UI, BLoCs, widgets. Solo consume `domain/`. Nunca importa de `data/` directamente.

**Reglas:**

- `presentation → domain → data`. La dirección de las dependencias siempre va hacia adentro.
- `data` implementa interfaces de `domain`.
- `domain` no conoce Flutter ni Supabase.

## Por qué

- **Testabilidad:** los casos de uso se prueban sin Flutter ni red.
- **Mantenibilidad:** cambiar de BLoC a Riverpod toca solo `presentation/`.
- **Reemplazo de piezas:** cambiar Facturama por otro PAC solo toca la capa `data` del dominio Fiscal.
- **Onboarding:** la separación es estándar de la industria, los devs nuevos la reconocen.

## Alternativas consideradas

- **MVC clásico:** más simple pero no aísla el dominio de la UI. Reemplazar UI requiere tocar reglas de negocio.
- **Arquitectura por capas tradicional** (`services/`, `controllers/`, `models/`): funciona para apps pequeñas, no escala a 6 dominios con integraciones externas.
- **Sin arquitectura (carpetas por tipo de archivo):** rápido al inicio, infierno al año dos.

## Trade-offs

- **A favor:** las razones de la decisión. Y se gana la reutilización de conocimiento entre features (los casos de uso de un dominio no se mezclan con los de otro).
- **En contra:** más archivos y más capas para features muy simples (ej. un toggle). Aceptable: el costo se paga en organización, no en lógica.

## Cuándo se revisa

- N/A. Decisión estructural. Solo se reconsidera si la arquitectura completa cambia (ej. migración a microservicios), no por features nuevas.
