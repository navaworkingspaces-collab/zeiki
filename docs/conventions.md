# Convenciones — Zeiki

> **Reglas permanentes del proyecto.** Este documento describe **qué** debe cumplir el código, no **cómo** se hace. El "cómo" vive en `workflow.md` y `git.md`. Si las convenciones cambian, este archivo cambia poco; si el stack cambia, este archivo no se reescribe.
>
> **Última actualización:** 2026-07-29 (v3 — separar reglas de procesos, abstraer del stack, agregar "Preferimos")

---

## 🧭 Filosofía

### NO INFERENCIA, SOLO PRUEBAS (filosofía del proyecto, no solo de debugging)

> **Nunca digas "probablemente pasa X" o "debe ser Y" sin evidencia.** Cita el código exacto: archivo, línea, método, snippet. Si no puedes demostrarlo, márcalo como hipótesis explícita con su plan de verificación.
>
> Aplica a debugging, code review, debates técnicos, reportes a Hugo, todo.

**Por qué:** la inferencia lleva a fixes incorrectos, erosiona confianza, y bloquea que las sesiones futuras verifiquen claims. Los equipos de infraestructura grandes arreglan evidencia, no hipótesis.

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

- Nombres describen intención, no implementación (`userRepository` no `UserRepoImpl2`).
- Getters sin prefijo `get`: `displayName` (no `getDisplayName`).
- BLoCs (cuando aplique): events en pasado/sustantivo, states como adjetivo/sustantivo, clase con sufijo `Bloc`.

---

## 2. Estilo de código

> **Lo que sigue aplica a cualquier stack. Si mañana cambiamos de lenguaje, esto sigue valiendo.**

### General

- El código se lee de arriba a abajo, como una carta.
- Líneas < 80 caracteres cuando sea posible (soft limit 100).
- Indentación consistente en todo el proyecto.
- Sin código muerto, sin TODOs sin issue, sin `print()` debug.

### Separación de capas

> Agnóstico del stack. Si mañana BLoC se reemplaza por Riverpod, esto sigue valiendo.

- La **capa de presentación** solo lee estado y dispara eventos. No hace lógica de negocio.
- La **capa de dominio** no conoce la UI ni el datasource. Pura lógica de negocio.
- La **capa de datos** implementa interfaces de la capa de dominio. No se importa desde la presentación.
- Dependencias apuntan hacia adentro: presentation → domain → data.
- Una función hace una cosa. Si su nombre necesita "y" ("handleLoginAndNavigate"), se divide.

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
- **Mocks solo donde se necesita:** preferir dobles de prueba simples (`fakeRepository`) sobre mocks con `when().thenAnswer()` cuando es viable.
- **Tests viven con el código:** junto al archivo que prueban, sufijo `_test`.

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

*Mantener este archivo vivo. Si una convención no está aquí y se vuelve recurrente, agregarla. Si entra en conflicto con la Target Architecture, gana la Target Architecture.*
