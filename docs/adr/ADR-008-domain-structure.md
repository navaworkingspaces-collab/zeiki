# ADR-008: Estructura de dominios del negocio

**Estado:** Aceptado
**Fecha:** 2026-07-29

## Contexto

Zeiki organiza su código en features. La pregunta es: ¿qué es una feature? Si se define por UI (login, dashboard, configuración), se acopla el código a la pantalla actual y se rompe cuando la UI cambia. Si se define por dominio del negocio, se aísla mejor la complejidad.

## Decisión

Zeiki se organiza en **6 dominios del negocio** (ver Target Architecture §6 para detalle):

1. **Identidad** — sesión, autenticación, recuperación, biometría.
2. **Fiscal** — CFDIs, descarga SAT, timbrado Facturama, eFirma, cancelaciones.
3. **Clientes** — alta, validación RFC, direcciones.
4. **Reportes** — cálculos, dashboard, exportación.
5. **Asistencia** — LLM, recomendaciones, chat fiscal.
6. **Configuración** — perfil, planes, preferencias, notificaciones.

**Reglas:**

- Si un nuevo concepto no encaja en ningún dominio, se crea un dominio nuevo (no se mete a la fuerza).
- Si un dominio crece demasiado (> 15 archivos en `domain/`), se divide.
- Un dominio solo modifica SU data. Para escribir en otro, llama explícitamente al caso de uso del otro dominio (en MVP) o publica un evento (cuando exista el Event Bus).
- **El único dominio que habla con sistemas externos** (SAT, Facturama) es **Fiscal**. Eso aísla el riesgo de cambios de API externa.

## Por qué

- **Refleja las áreas naturales del problema** de facturación CFDI 4.0.
- **Suficientemente granulares** para que cada uno quepa en la cabeza de un dev.
- **Independientes entre sí:** cambios en Identidad no tocan Fiscal, etc.
- **Aísla el riesgo externo:** si el SAT cambia su API, solo se modifica el dominio Fiscal.

## Alternativas consideradas

- **Organización por capa técnica** (`services/`, `models/`, `controllers/`): rápido al inicio, infierno cuando hay 50 archivos en cada carpeta.
- **Organización por feature UI** (login, dashboard, settings): acopla código a UI, rompe cuando la UI cambia.
- **Menos dominios** (3-4 en vez de 6): tentador, pero "Clientes" y "Configuración" se vuelven cajones de sastre.
- **Más dominios** (10+): se gana granularidad, se pierde visión global.

## Trade-offs

- **A favor:** claridad, aislamiento de riesgo, escalabilidad.
- **En contra:** dos dominios relacionados (ej. Clientes + Fiscal) requieren contratos explícitos. Hoy eso es una llamada directa al caso de uso; en el futuro será un evento (ver Target §13.1 Decisiones diferidas — Event Bus diferido).

## Cuándo se revisa

- Un dominio supere 15 archivos en `domain/` o se vuelva claro que dos áreas no comparten reglas (entonces se divide).
- Un nuevo dominio del negocio aparezca naturalmente (ej. "Nómina" si en el futuro Zeiki se expande a recursos humanos).
- Dos dominios se vuelvan tan acoplados que la separación cause más fricción que beneficio (raro, pero posible).

## Ownership

Cada dominio tiene un dueño único. Hoy Hugo es dueño de todos. Si el equipo crece, se asigna un dueño por dominio. Ver Target Architecture §6.
