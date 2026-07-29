# Convenciones — Zeiki v2

> **Reglas de código, naming, commits y PRs.** Cualquier contribución debe seguirlas. Alineado con la [Target Architecture](architecture/target-architecture.md).
>
> **Última actualización:** 2026-07-29 (v2 — testing basado en matriz de criticidad, no en porcentajes)

---

## 1. Naming

### Archivos y carpetas

| Tipo | Convención | Ejemplo |
|------|-----------|--------|
| Carpetas | `snake_case`, en inglés | `auth/`, `sat_configuration/` |
| Archivos Dart | `snake_case.dart` | `login_page.dart`, `auth_bloc.dart` |
| Archivos de test | `<archivo>_test.dart` | `auth_bloc_test.dart` |
| Specs | `HDU-XXX-slug-descriptivo.md` | `HDU-005-onboarding-flag.md` |
| Handoffs | `docs/handoffs/YYYY-MM-DD-hdu-XXX-slug.md` | `docs/handoffs/2026-07-27-hdu-021c.md` |
| Docs de features | `docs/features/<nombre-feature>.md` | `docs/features/sat-download.md` |

### Clases y tipos

| Tipo | Convención | Ejemplo |
|------|-----------|--------|
| Clases | `PascalCase` | `LoginPage`, `AuthBloc` |
| Enums | `PascalCase` | `AuthStatus` |
| Extensiones | `PascalCase` + sufijo | `StringExtensions` |
| Typedefs | `PascalCase` + sufijo | `AuthCallback` |

### Variables y funciones

| Tipo | Convención | Ejemplo |
|------|-----------|--------|
| Variables locales | `camelCase` | `currentUser` |
| Variables privadas | `_camelCase` | `_isLoading` |
| Constantes | `camelCase` con `const` | `const maxRetries = 3;` |
| Funciones | `camelCase`, verbos | `signIn()`, `getCurrentUser()` |
| Funciones privadas | `_camelCase` | `_handleLogin()` |
| Getters | `camelCase`, sin `get` prefix | `displayName` |

### BLoC

| Elemento | Convención | Ejemplo |
|----------|-----------|--------|
| Events | `PascalCase` + sufijo o sustantivo | `AuthSignInWithEmailRequested` |
| States | `PascalCase` + sufijo o adjetivo | `AuthLoading`, `AuthAuthenticated` |
| BLoC class | `PascalCase` + sufijo `Bloc` | `AuthBloc` |

### Variables de entorno

- `SCREAMING_SNAKE_CASE` para keys.
- Ejemplo: `SUPABASE_URL`, `SUPABASE_ANON_KEY`.

---

## 2. Estilo de código Dart

### Reglas generales

- `flutter analyze` debe pasar sin warnings.
- `dart format` antes de commit.
- Líneas < 80 caracteres (soft limit 100).
- Indentación: 2 espacios (no tabs).

### Imports

**Orden:**

```dart
// 1. Dart/Flutter SDK
import 'package:flutter/material.dart';

// 2. Third-party packages
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

// 3. Project imports (con prefix package:)
import 'package:zeiki/core/...';
import 'package:zeiki/features/auth/...';

// 4. Relative imports (solo mismo feature)
import '../widgets/header.dart';
import 'auth_bloc.dart';
```

**Regla:** preferir `package:zeiki/...` sobre relative imports.

### Strings

- Comillas simples por defecto.
- Comillas dobles solo con interpolación que mejora legibilidad.
- Multi-línea con triple comilla simple.

### Null safety

- Tipos explícitos `String?` en vez de `dynamic`.
- `late` solo cuando sea seguro.
- `?.` y `??` sobre null checks manuales.

### Async

- `async`/`await` por defecto.
- Capturar errores con `try`/`catch` o `try`/`on Type catch`.
- Streams con `await for` o `.listen` con handler de error.

---

## 3. Commits

### Conventional Commits

```
<tipo>(<scope>): <descripción corta> [HDU-XXX]

<cuerpo opcional>

<footer>
```

### Tipos

| Tipo | Uso | Ejemplo |
|------|-----|--------|
| `feat` | Feature nueva | `feat(auth): add biometric login button` |
| `fix` | Bug fix | `fix(splash): persist onboarding flag` |
| `refactor` | Sin cambio de comportamiento | `refactor(auth): migrate login to BLoC` |
| `chore` | Mantenimiento | `chore(deps): upgrade flutter_bloc to 8.1.3` |
| `docs` | Solo documentación | `docs(arch): add ADR-005 specs decision` |
| `test` | Solo tests | `test(auth): add login_bloc_test.dart` |
| `style` | Formato | `style: apply dart format` |
| `perf` | Performance | `perf(invoices): cache SAT catalogs` |

### Descripción corta

- Imperativo presente ("add" no "added").
- Sin punto final.
- < 72 caracteres.

### Cuerpo (opcional)

- Explicar **qué** y **porqué**, no **cómo**.
- Wrap a 72 chars.

### Footer

- Referencia a spec: `Refs: specs/HDU-XXX.md`
- Breaking changes: `BREAKING CHANGE: <descripción>`
- Issues cerrados: `Closes #123`

### Ejemplo

```
fix(splash): persist onboarding completion flag [HDU-005]

SplashPage navigated to /onboarding on every launch with no session.
Now saves onboarding_completed to SharedPreferences after first view
and skips onboarding if true.

- Add SharedPreferences key constant
- Set flag in OnboardingPage after user views all 4 slides
- Check flag in SplashPage before navigating
- Add unit tests for flag logic

Refs: specs/HDU-005-onboarding-flag.md
```

---

## 4. Pull Requests

### Título

Mismo formato que commits:

```
fix(splash): persist onboarding completion flag [HDU-005]
```

### Descripción (template)

```markdown
## Resumen
<1-3 bullets>

## Check de entendimiento
- Lo que quieres: …
- Vas a saber que está bien cuando: …
- Esto NO se va a hacer: …

## Spec
Ver: [specs/HDU-XXX-slug.md](specs/HDU-XXX-slug.md)

## Cambios
- Bullet list

## Checklist de review
- [ ] Tests rojos → verdes documentado
- [ ] Clean code review pasó
- [ ] Security review pasó
- [ ] **Architecture review pasó** (cumple con Target Architecture §1-§3, no introduce anti-patrones §14)
- [ ] `flutter analyze` sin warnings
- [ ] `flutter test` pasa
- [ ] `flutter build apk --debug` compila
- [ ] Deno tests pasan (si toca edge functions)
- [ ] QA local en Xiaomi verificó criterios de aceptación

## Screenshots / Logs
<si aplica>
```

### Reviewers

- 1 reviewer mínimo (Hugo).
- Auto-merge OK para MVP, code review estricto para producción.

---

## 5. Comentarios

### Cuándo comentar

✅ **Sí:**
- Lógica de negocio no obvia (el "porqué").
- Workarounds conocidos con link al issue.
- Constraints del SAT o APIs externas.
- Excepciones reguladas (CFDI, RFC validation).

❌ **No:**
- Lo que el código ya dice.
- Código obsoleto (eliminarlo).
- TODOs sin issue asociado.

### TODO format

```dart
// TODO(hdu-XXX): descripción de lo que falta
// Ejemplo:
// TODO(hdu-013): agregar integration test para flujo de auth
```

> ⚠️ **GOTCHA del analyzer:** el lint marca `// TODO` como warning incluso cuando aparece en prosa. Evitar la palabra suelta "TODO" en comentarios que no sean TODOs reales.

---

## 6. Testing (matriz de criticidad, NO porcentajes)

> **Cambio importante en v2:** ya no usamos porcentajes de coverage. Son engañosos. Usamos la **matriz de criticidad** definida en §11 de la [Target Architecture](architecture/target-architecture.md).

### Principio

**Objetivo:** que todo flujo crítico esté protegido por tests que fallan si se rompe. **No** buscamos un número de coverage.

### Matriz de criticidad (resumen, ver Target Architecture §11 para detalle)

| Componente | Criticidad | Tipo de test mínimo |
|------------|------------|---------------------|
| Casos de uso fiscales (timbrado, cálculo) | **Muy alta** | Unit + integration |
| Descarga SAT | **Muy alta** | Unit (mockeando SAT) + integration |
| Login | **Muy alta** | Unit + widget + integration |
| Cálculo de impuestos | **Muy alta** | Unit |
| Repositorios | Alta | Unit con mocks |
| BLoCs | Alta | Unit con `bloc_test` |
| Edge Functions | Alta | Unit Deno |
| Widgets visuales no críticos | Baja | Widget selectivo |
| Helpers / utils | Media | Unit si la lógica no es trivial |
| Migraciones SQL | Alta | Test contra DB staging |

### Reglas

- **TDD para flujos críticos:** escribir el test que falla ANTES de implementar.
- **Regression para cada bug:** un test que reproduce el bug (falla antes del fix, pasa después).
- **Pipeline:** todo test debe pasar antes de mergear a `main`.
- **Coverage como derivado, no como meta:** el coverage % se reporta en el PR pero NO es criterio de aceptación. Lo que importa es que los flujos críticos estén cubiertos.

### Naming de tests

```dart
// ✅ OK
test('should return user when credentials are valid', () { ... });
test('should throw AuthException when password is wrong', () { ... });

// ❌ Evitar
test('test the login method', () { ... });
```

### Estructura AAA (Arrange-Act-Assert)

```dart
test('login should authenticate user', () async {
  // Arrange
  final mockRepo = MockAuthRepository();
  when(mockRepo.signIn(...)).thenAnswer((_) async => testUser);
  final bloc = AuthBloc(signInUseCase: SignInUseCase(mockRepo));

  // Act
  bloc.add(AuthSignInWithEmailRequested(email: '...', password: '...'));
  await Future.delayed(Duration.zero);

  // Assert
  expect(bloc.state, isA<AuthAuthenticated>());
});
```

---

## 7. Patrones recurrentes (bug classes conocidas)

> **Patrones de bugs que ya detectamos.** Si encuentras un caso que coincide, seguir el fix documentado. Si es un caso nuevo, documentarlo aquí también.

### State staleness on navigation (HDU-MANUAL-002c)

**Síntoma:** Una página padre cachea estado que la página hija puede mutar. Al volver al padre, la UI muestra el estado viejo.

**Fix pattern:** refrescar el estado del padre al regresar de la página hija:

```dart
// ❌ Antes — refresh solo en initState
onTap: () {
  Navigator.of(context).pushNamed('/child-page');
},

// ✅ Después — refresh on return
onTap: () async {
  await Navigator.of(context).pushNamed('/child-page');
  if (mounted) {
    await _loadStatus();
  }
},
```

### Banners UX atómicos por feature (HDU-MANUAL-003)

**Regla:** cada banner de estado vive en la página donde el usuario **actúa** sobre ese estado, no en páginas adyacentes.

- "Sincronizar desde la nube" → en `efirma_configuration_page`.
- "Descarga Automática Activa" → en `sat_configuration_page`.
- **NO** duplicar el mismo banner en 2 menús.

---

## 8. Git workflow

### Branching

- `main` — siempre deployable, protegido.
- `feat/*`, `fix/*`, `refactor/*`, `chore/*` — trabajo en progreso.
- `hotfix/*` — solo para emergencias.

### Commits

- Squash OK para features pequeñas.
- Commits atómicos para features grandes (un commit por paso lógico).

### Merge

- **No fast-forward** para features (`--no-ff`) — preserva historia.
- Fast-forward OK para hotfixes.
- Eliminar rama después de merge.

---

## 9. Documentación en código

### Docstrings para APIs públicas

```dart
/// Authenticates a user with email and password.
///
/// Throws [AuthException] if credentials are invalid.
/// Returns the authenticated [UserEntity] on success.
Future<UserEntity> signIn({
  required String email,
  required String password,
});
```

### Comentarios regulatorios

Cuando el código toca temas regulados (SAT, CFDI), referenciar la fuente:

```dart
// CFDI 4.0 - SAT spec sección X.Y
// Ver: http://www.sat.gob.mx/.../cfdv40.xsd
```

---

## 10. Pipeline local completo

> **Regla:** el pipeline local debe correr **TODOS** los tipos de tests del repo.

### Flutter (cliente)

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

### Deno (edge functions) — TODAS

```powershell
foreach ($fn in Get-ChildItem "supabase/functions") {
  Push-Location $fn
  deno check index.ts
  deno test --allow-read --allow-env
  Pop-Location
}
```

### Si hay migraciones SQL nuevas

Aplicar a staging y verificar idempotencia.

### Baseline documentado

El conteo de tests por suite se mantiene en `docs/test-baseline.md`. Si una HDU cambia el conteo, actualizar el baseline en la misma PR.

---

## 11. Regla de oro: NO INFERENCIA, SOLO PRUEBAS

> **Cuando estés debuggeando un bug, NUNCA digas "probablemente pasa X" o "debe ser Y".**
>
> **Cita el código exacto:** archivo, línea, método.
>
> Si no puedes demostrar algo con código o test corriendo, **dilo explícitamente** como hipótesis, no como conclusión.

### ❌ Lo que NO se hace

```
"Probablemente el bug es que el listener no se desuscribe"
"Debe ser un problema de timing en el async"
"Seguro el SAT rechaza porque la firma está mal"
```

### ✅ Lo que SÍ se hace

```
"En efirma_service.dart línea 1492-1510, hasCertificate() lee de
 _secureStorage. Después de 'Borrar datos', FlutterSecureStorage queda
 vacío pero Supabase (user_efirma_credentials, línea 1814) mantiene
 el registro. Inconsistencia confirmada en código."
```

### Por qué

- La inferencia lleva a fixes incorrectos.
- Hugo pierde confianza cuando le "adivinas".
- Las sesiones futuras no pueden verificar claims vagos.
- Los tests no pueden reproducir bugs descritos con "probablemente".

### Cuándo SÍ se permite hipótesis

- Cuando explícitamente dices "hipótesis a verificar:".
- La hipótesis viene con el código/línea que la generaría.
- Propones cómo verificarla (qué test correr, qué log capturar).

---

*Mantener este archivo vivo. Si una convención no está aquí y se vuelve recurrente, agregarla. Si entra en conflicto con la Target Architecture, gana la Target Architecture.*
