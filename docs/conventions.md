# Convenciones — Zeiki

> **Reglas permanentes del proyecto.** Este documento describe **qué** debe cumplir el código, no **cómo** se hace. El "cómo" vive en `workflow.md` y `git.md`. Si las convenciones cambian, este archivo cambia poco; si el stack cambia, este archivo no se reescribe.
>
> **Última actualización:** 2026-07-29 (v4 — frase de propósito, qué NO documentamos, errores, APIs, config, dependencias)

---

## 🧭 Por qué existen estas convenciones

> **Las convenciones existen para reducir decisiones repetitivas.** Si una decisión debe tomarse igual el 95% de las veces, deja de ser una decisión y se convierte en una convención.
>
> Las convenciones no son reglas arbitrarias: son decisiones que el equipo ya tomó y que se aplican por defecto. La excepción se documenta.

---

## 🧭 Filosofía

> Las convenciones y la operación de Zeiki siguen la **filosofía del proyecto definida en [Target Architecture §0](../architecture/target-architecture.md#0-filosofía-del-proyecto)**. Este documento la aplica al código, no la duplica.
>
> **Resumen:** **NO INFERENCIA, SOLO PRUEBAS.** Nunca "probablemente pasa X" sin evidencia. Cita el código con `archivo:línea`. Si no puedes demostrarlo, es hipótesis, no conclusión.

---

## 💚 Preferimos

Decisiones por defecto cuando hay empate. Documentan la jerarquía de valores del proyecto.

```
Código simple
  sobre
Código inteligente.
```

```
Funciones pequeñas
  sobre
Métodos de 400 líneas.
```

```
Duplicar 10 líneas
  sobre
Crear una abstracción innecesaria.
```

```
Legibilidad
  sobre
Micro optimización.
```

```
Estructura explícita
  sobre
Magia implícita.
```

```
Un test que falla y se arregla
  sobre
Diez tests que pasan sin probar nada.
```

```
Documentar el porqué
  sobre
Documentar el qué.
```

```
Una convención explícita
  sobre
Un juicio subjetivo en cada PR.
```

---

## 1. Naming

| Tipo | Convención | Ejemplo |
|------|-----------|--------|
| Carpetas | `snake_case`, en inglés | `auth/`, `sat_configuration/` |
| Archivos de código | `snake_case.<ext>` | `login_page.dart`, `auth_service.ts` |
| Archivos de test | `<archivo>_test.<ext>` | `auth_bloc_test.dart` |
| Specs | `HDU-XXX-slug-descriptivo.md` | `HDU-005-onboarding-flag.md` |
| Handoffs | `docs/handoffs/YYYY-MM-DD-hdu-XXX-slug.md` | `docs/handoffs/2026-07-27-hdu-021c.md` |
| Docs de features | `docs/features/<nombre-feature>.md` | `docs/features/sat-download.md` |

| Tipo | Convención | Ejemplo |
|------|-----------|--------|
| Clases / tipos | `PascalCase` | `LoginPage`, `AuthBloc` |
| Enums | `PascalCase` | `AuthStatus` |
| Extensiones | `PascalCase` + sufijo | `StringExtensions` |
| Variables | `camelCase` (privadas con `_` prefix) | `currentUser`, `_isLoading` |
| Funciones | `camelCase`, verbos | `signIn()`, `_handleLogin()` |
| Constantes | `camelCase` con `const` | `const maxRetries = 3;` |
| Variables de entorno | `SCREAMING_SNAKE_CASE` | `SUPABASE_URL` |

**Reglas transversales:**

- Nombres describen intención, no implementación.
- Getters sin prefijo `get`: `displayName` (no `getDisplayName`).
- BLoCs (cuando aplique): events en pasado/sustantivo, states como adjetivo/sustantivo, clase con sufijo `Bloc`.

---

## 2. Estilo de código

> Agnóstico del stack. Si mañana cambiamos de lenguaje, esto sigue valiendo.

### General

- El código se lee de arriba a abajo, como una carta.
- Líneas < 80 caracteres cuando sea posible (soft limit 100).
- Indentación consistente en todo el proyecto.
- Sin código muerto, sin TODOs sin issue, sin `print()` debug.

### Separación de capas

- La **capa de presentación** solo lee estado y dispara eventos. No hace lógica de negocio.
- La **capa de dominio** no conoce la UI ni el datasource. Pura lógica de negocio.
- La **capa de datos** implementa interfaces de la capa de dominio. No se importa desde la presentación.
- Dependencias apuntan hacia adentro: presentation → domain → data.
- Una función hace una cosa. Si su nombre necesita "y", se divide.

### Comentarios

**Regla única:** comenta el porqué. Nunca el qué.

Tres ejemplos suficientes:

```dart
// ✅ El SAT rechaza el CFDI si el campo tiene más de 254 caracteres (regla CFDI 4.0).
// ❌ Incrementar el contador.

// ✅ Workaround: el SAT no responde antes de 6h, así que el backoff llega a 50h.
// ❌ Backoff de 50 horas.

// ✅ Esta validación existe porque el cliente puede venir con o sin prefijo internacional.
// ❌ Validar el teléfono.
```

---

## 3. Testing (qué debe estar probado, no cuánto)

> **No usamos porcentajes de coverage.** Son engañosos. Usamos la **matriz de criticidad** definida en §11 de la [Target Architecture](architecture/target-architecture.md). El coverage % se reporta en el PR pero NO es criterio de aceptación.

### Reglas

- **TDD para flujos críticos:** el test se escribe ANTES del código, falla, luego se implementa, pasa.
- **Regression para cada bug arreglado:** un test que reproduce el bug. Falla antes del fix, pasa después.
- **Un test, un comportamiento.** Si un test tiene varios asserts no relacionados, se divide.
- **Mocks solo donde se necesita:** preferir dobles de prueba simples sobre mocks con `when().thenAnswer()` cuando es viable.
- **Tests viven con el código:** junto al archivo que prueban, sufijo `_test`.

### Cuándo usar mock vs fake vs stub

| Tipo | Cuándo usarlo | Costo |
|------|---------------|-------|
| **Stub** (devuelve valores fijos) | Cuando solo necesitas que el test compile y corra, sin verificar interacciones. | Cero. Sin `mockito` ni `build_runner`. |
| **Fake** (implementación simple, funcional) | Cuando la dependencia tiene lógica pero no quieres la real (ej. `InMemoryUserRepository` en vez de Supabase). | Cero. Una clase que implementa la interfaz. |
| **Mock** (verifica interacciones) | Cuando necesitas verificar QUE se llamó un método, con qué argumentos, cuántas veces. | Alto. `mockito` + `build_runner` + `codegen`. Solo si no hay otra forma. |

**Regla práctica:**

- Si el test solo necesita **que la dependencia devuelva algo**: usa **stub** o **fake**.
- Si el test necesita **verificar que el código llamó a la dependencia correctamente**: usa **mock**.
- **Nunca** uses mock cuando stub/fake bastan. El costo de `mockito` (build time, complejidad, dependencia) no se justifica para "solo necesito que devuelva X".

**Por qué:** `mockito` agrega `build_runner` y code generation real. No es gratis. La mayoría de los tests de Zeiki pueden usar stubs/fakes; los mocks son la excepción.

### Naming de tests

Describen comportamiento, no implementación:

```dart
// ✅
test('should return user when credentials are valid', () { ... });
test('should throw AuthException when password is wrong', () { ... });

// ❌
test('test the login method', () { ... });
```

### Estructura

Arrange (preparar) → Act (actuar) → Assert (verificar). Sin pasos extra.

---

## 4. Patrones recurrentes (Bug Cookbook)

> **Catálogo de bugs que ya detectamos.** Si encuentras un caso que coincide, sigue el fix documentado. Si es un caso nuevo, documéntalo aquí también. Con el tiempo esto se vuelve una "receta de cocina" donde alguien dice "esto ya nos pasó" y encuentra la solución en cinco minutos.

### State staleness on navigation

**Síntoma:** una página cachea estado en su inicialización que la página hija puede mutar. Al volver al padre, la UI muestra el estado viejo.

**Fix pattern:** refrescar el estado del padre al regresar de la página hija.

```dart
// ❌ Refresh solo al iniciar
onTap: () {
  Navigator.pushNamed(context, '/child');
},

// ✅ Refresh al volver
onTap: () async {
  await Navigator.pushNamed(context, '/child');
  if (mounted) await _loadStatus();
},
```

### Banners UX atómicos por feature

**Regla:** cada banner de estado vive en la página donde el usuario **actúa** sobre ese estado, no en páginas adyacentes.

- "Sincronizar desde la nube" → en la página de configuración de eFirma.
- "Descarga Automática Activa" → en la página de configuración SAT.
- NO duplicar el mismo banner en dos menús: confunde sobre dónde está la fuente de verdad.

---

## 5. Linter y analyzer

- El linter del stack debe pasar sin warnings por defecto.
- **Excepción documentada:** un warning es aceptable si tiene una justificación escrita (comentario en el código o nota en el PR). Ejemplos válidos:
  - `deprecated_member` durante una migración planeada.
  - `avoid_print` en código de debug que se quita antes de merge.
- **Excepción NO documentada:** el warning se arregla. No se acepta "lo arreglamos después" sin issue.

---

## 6. Seguridad (qué se hace, no cómo)

- Credenciales nunca en código. Variables de entorno o secret manager.
- Inputs validados en el cliente (UX) y en el servidor (verdad).
- Auth obligatorio en cada endpoint protegido. Sin endpoints "abiertos por compatibilidad".
- Datos sensibles encriptados en reposo y tránsito.
- Almacenamiento seguro para credenciales (nunca en `SharedPreferences` ni en archivos planos).
- Sin logs de información sensible (passwords, tokens, RFCs completos, eFirma).

El "cómo" se implementa depende del stack y vive en código + workflow.

---

## 7. Documentación (qué sí, qué no)

> **Documentamos decisiones, no implementación.** El código se documenta solo cuando hace algo no obvio. La documentación nunca duplica lo que el código dice.

### Qué SÍ documentamos

- **Decisiones** que el equipo tomó y el porqué (ADRs, justificación de patrones).
- **Reglas del negocio** que no son obvias desde el código (reglas del SAT, validación de RFC, cálculos fiscales).
- **Restricciones operacionales** (límites de proveedores externos, quotas, ventanas de mantenimiento).
- **Conocimiento que cuesta recuperar** (algoritmos validados, integraciones probadas, bugs ya documentados en el Bug Cookbook).
- **Contexto histórico** de por qué se hizo algo (handoffs de sesión, postmortems de incidentes).
- **Cómo se opera** el sistema (runbooks, procedimientos de rotación de secretos, disaster recovery).

### Qué NO documentamos

- **Implementación evidente** que el código ya dice.
- **Procesos temporales** que se van a descontinuar (si es temporal, va en el PR o en Slack, no en `docs/`).
- **Tutoriales paso a paso** de cosas que cualquier dev puede aprender con un `grep` (ej. "cómo crear un nuevo BLoC" — eso se aprende en una hora, no se documenta).
- **Decisiones que revertimos** (si se canceló, va al `current-state.md` como lección, no se conserva el spec cancelado).
- **Documentación que va a quedar obsoleta** sin que nadie la mantenga. Si nadie la va a actualizar, no se crea.

### Cuándo actualizar vs cuándo borrar

- Si un documento **aún aplica** pero cambió: actualizar.
- Si un documento **ya no aplica**: archivar en `docs/archive/` con fecha.
- Si un documento **nunca se consultó** en 6 meses: quemar (ver `workflow.md` §Quema de archivos legacy).
- Si un documento **se actualiza junto con código** que lo referencia: actualizar en el mismo PR.

---

## 8. Convenciones de errores

> **Los errores son parte del contrato de la API.** Cómo se lanzan, cómo se propagan y qué información llevan importa tanto como el happy path.

### Principios

- **Incluyen contexto suficiente** para diagnosticar sin abrir el código. Mínimo: qué operación falló, con qué input, por qué.
- **Nunca esconden la excepción original.** Si se traduce de un error de proveedor a un error de dominio, el original va en la causa o en el log.
- **Nunca muestran datos sensibles** al usuario final. El mensaje puede decir "credenciales inválidas", no "la contraseña 'micontraseña123' no coincide".
- **Usan excepciones tipadas cuando forman parte del dominio.** `AuthException`, `SatException`, `FacturamaException` son distintos y distinguibles.
- **Se loguean con nivel apropiado.** INFO para reintentos, WARN para validaciones esperadas, ERROR para fallos inesperados.
- **No se tragan errores silenciosamente.** Un `catch {}` vacío es bug o deuda documentada.
- **No se devuelven errores como strings.** El tipo del error debe ser inspeccionable, no parseable.

### Jerarquía sugerida (ajustar al stack)

```
DomainException        ← clase base
├── AuthException      ← identidad
├── SatException       ← descarga SAT
├── FacturamaException ← timbrado
├── NetworkException   ← red
└── ValidationException ← input del usuario
```

---

## 9. Convenciones de APIs

> **Los principios valen para REST, GraphQL, gRPC, lo que sea.** Si mañana cambiamos el transporte, esto sigue siendo válido.

### Principios

- **Las operaciones deben ser idempotentes cuando sea posible.** Una solicitud reenviada no debe generar un efecto distinto. Si no se puede hacer idempotente, se documenta explícitamente.
- **Las respuestas tienen una estructura consistente.** Mismo envoltorio para éxito y para error. Los nombres de campos no cambian entre endpoints.
- **Los códigos de error representan la causa real.** No devolver 200 con un campo `success: false`. No devolver 500 para input inválido.
- **Los contratos públicos no se rompen sin versionado.** Cualquier cambio incompatible requiere una nueva versión (`/v2/...`).
- **Los inputs se validan en ambos lados.** Cliente para UX (mostrar error inmediato), servidor para verdad (la fuente de verdad es el servidor).
- **Los endpoints protegidos requieren auth verificable.** Token válido, no expirado, con los scopes correctos.
- **Las operaciones largas devuelven un job_id**, no esperan. El cliente pregunta por el estado o se suscribe a un canal.

### Errores típicos a evitar

- Devolver 200 con `error: "..."` adentro.
- Devolver 500 cuando el error es de input (debería ser 400).
- Cambiar el shape de una respuesta sin versionar.
- "Endpoints abiertos por compatibilidad" que ya nadie usa y nadie se atreve a cerrar.
- Mezclar concerns (un endpoint que hace auth + negocio + notificación).

---

## 10. Convenciones de Configuración

> **Una sola fuente de verdad por configuración.** La duplicación de constantes es una de las fuentes más comunes de bugs sutiles.

### Reglas

- **Toda configuración tiene una única fuente de verdad.** Si un valor existe en más de un lugar, hay un bug latente.
- **Nunca duplicar constantes** entre archivos. Si necesitas el mismo valor en dos lados, impórtalo.
- **Nunca copiar valores** entre archivos de configuración. Si cambian, todos cambian.
- **Configuración por entorno separada de configuración por código.** `assets/.env` para credenciales, `core/constants/` para reglas de negocio.
- **Los valores por defecto se documentan.** Si la app arranca con `maxRetries = 3`, eso debe estar en un lugar visible, no enterrado en código.
- **Los secretos NUNCA van en código.** Variables de entorno, secret manager, o `assets/.env` con excepción en `.gitignore`.

### Capas de configuración

| Capa | Ejemplo | Dónde vive |
|------|---------|-----------|
| Secretos | API keys, tokens | Variables de entorno / secret manager |
| Configuración de entorno | URL de Supabase, region | `assets/.env` |
| Reglas de negocio | Catálogo de regímenes fiscales, topes de ISR | `core/constants/` |
| Feature flags | `AppFeature.nuevoDashboard` | Definidos en código como enum |
| Constantes técnicas | `maxRetries`, `timeout` | `lib/core/constants/technical.dart` (o en el archivo que las usa si son muy locales) |

---

## 11. Convenciones de Dependencias

> **Una dependencia más es una decisión que se paga para siempre.** Antes de agregar una, responder 4 preguntas.

### Las 4 preguntas antes de agregar una dependencia

1. **¿Ya existe algo en el proyecto** que resuelva esto? A veces un helper de 30 líneas evita un paquete de 3 MB.
2. **¿Lo resuelve el lenguaje?** Muchas cosas ya vienen en el stdlib del lenguaje o del framework.
3. **¿Lo resuelve el framework?** Flutter, Supabase, Dart ya cubren una cantidad enorme de casos. Antes de buscar afuera, busca en lo que ya tienes.
4. **¿Vale la pena mantener otra dependencia?** Cada dep es: actualización periódica, riesgo de CVE, deuda si el autor la abandona, código que no controlas.

Si la respuesta a las 4 es "no, sí, sí, no" — busca una alternativa. Si después de las 4 la respuesta sigue siendo "lo necesito", agrégala con justificación en el PR.

### Reglas adicionales

- **Deps se actualizan con intención**, no automáticamente. Un `pub upgrade` sin revisar changelog es bug esperando a pasar.
- **Las deps se declaran con versión exacta o rango conservador**, no "cualquier versión mayor".
- **Si una dep se abandona, se busca reemplazo antes de que rompa** el build.
- **Las deps de testing se separan** de las deps de runtime cuando el stack lo permite.

---

## 12. Migraciones SQL (mini-convention)

> **Status:** Diferido en `target-architecture.md §13.1` (sin versionado formal de BD). Pero "ad-hoc sin convention" es recipe for disaster. Esta mini-convention aplica **ya**, con el versionado formal llegando en Fase 3.

### Reglas

- **Nombre de archivo:** `YYYYMMDD_HHMMSS_<slug-descriptivo>.sql` (timestamp + slug).
  - Ejemplo: `20260729_143000_add-sat-cfdis-index.sql`.
  - El orden lexicográfico es el orden de ejecución. Timestamp asegura unicidad.
- **Ubicación:** `supabase/migrations/` (convención de Supabase CLI).
- **Idempotencia obligatoria:** usar `IF NOT EXISTS` en CREATE, `IF EXISTS` en DROP, `ON CONFLICT DO NOTHING` en INSERT.
- **Una migración por cambio lógico.** No mezclar "agregar tabla" con "agregar columna a otra tabla".
- **Migración va con código** en el mismo PR. Si la migración es de Fase 1+ (cuando se tenga), se taggea junto con el código que la consume.
- **Rollback explícito:** cada migración tiene un `_rollback.sql` en el mismo directorio. Si la migración es destructiva (DROP, ALTER COLUMN), el rollback se prueba en staging antes de producción.
- **No borrar migraciones aplicadas.** Marcar como `deprecated` con un comentario al inicio.
- **Backfill (llenar datos nuevos en columnas existentes):** va en una migración separada, después de la migración estructural.

### Aplicación

- **Local / dev:** `supabase db reset` aplica todas las migraciones desde cero.
- **Staging / prod:** `supabase db push` aplica solo las migraciones nuevas. La CLI lleva el tracking.

### Testing

- Después de aplicar, un test verifica que la migración no rompió el schema (comparar contra un snapshot del schema esperado).
- Backfill se prueba con datos sintéticos en staging.

---

*Mantener este archivo vivo. Si una convención no está aquí y se vuelve recurrente, agregarla. Si entra en conflicto con la Target Architecture, gana la Target Architecture.*
