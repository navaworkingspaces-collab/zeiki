# HDU-005 — Auth básico (email + Google) con router redirigido por sesión

**Tipo:** feature
**Prioridad:** alta
**Estado:** pendiente
**Fecha:** 2026-07-30
**Sistemas externos involucrados:** Supabase Auth (email + password + Google OAuth), Google Sign-In (OAuth client)
**Dominio(s):** `lib/features/identidad/` (migración de placeholders) + `lib/core/auth/` (servicio transversal) + `lib/core/router/` (cambio de home del router)

---

## Check de entendimiento (3 líneas)

- Lo que quieres: que la app pueda registrar, entrar, salir y acordarse del usuario con **correo o Google** (las dos opciones de entrada, no vinculadas entre sí).
- Vas a saber que está bien cuando: pueda crear cuenta con cualquiera de los dos métodos, cerrar la app, reabrir y seguir logueado, hacer logout y al volver me pida auth de nuevo, y el router me mande solito al `/login` si nunca he entrado o al `/home` si ya estoy dentro.
- Esto NO se va a hacer: biometría, timer de inactividad por seguridad, pantallas con diseño visual final, vincular Google↔correo en la misma cuenta, recuperación de contraseña, ni cambio de email/password (todo eso es HDU-005b o futuras).

---

## Decisiones de producto (acordadas con Hugo el 2026-07-30)

> Esta sección documenta EL QUÉ del flujo de auth, no el cómo. Es la fuente de verdad para los criterios de aceptación.

### Flujo de register (crear cuenta nueva)

1. El usuario entra a `/register`.
2. Ve dos opciones de método de entrada: **"Con correo"** y **"Con Google"**.
3. Si elige **correo**: pide email + contraseña (mínimo 8 caracteres), botón "Crear cuenta". Al confirmar → navega a `/home`. La pantalla `/login` se omite.
4. Si elige **Google**: dispara el flujo de Google Sign-In. Al confirmar Google → navega a `/home`. La pantalla `/login` se omite.
5. **NO** se ofrece activar biometría en este paso. Eso sale en HDU-005b.

### Flujo de login (cuenta existente)

1. El usuario entra a `/login`.
2. **El sistema detecta con qué método se registró** (correo o Google) y muestra solo la opción correspondiente. No hay selector.
3. Si fue **correo**: pide email + contraseña, botón "Entrar". Al confirmar → navega a `/home`.
4. Si fue **Google**: botón "Entrar con Google". Al confirmar → navega a `/home`. NO pide contraseña.
5. **NO hay checkbox de "recordarme".** La sesión es persistente por default (es lo que hace Supabase). El usuario no necesita marcar nada.

### Flujo de logout (salir explícito)

1. El usuario está en `/home`, ve su email y un botón "Salir".
2. Toca "Salir" → se limpia la sesión local.
3. Navega a `/login`.
4. **El dispositivo sigue recordando al usuario** (la sesión se puede re-establecer con el mismo método). El logout NO borra la cuenta ni el método de auth — solo termina la sesión actual.

### Flujo de re-apertura de la app (sin logout explícito)

| Situación | Comportamiento |
|-----------|----------------|
| App cerrada completamente (cold start, sin importar cuánto tiempo) | El router consulta la sesión. Si existe → `/home`. Si no → `/login`. |
| App en background < 5 minutos y vuelve | NO consulta nada. La app sigue donde estaba. |
| App en background > 5 minutos y vuelve | **Por ahora NO se bloquea** (eso es el timer de seguridad, sale en HDU-005b). El router solo consulta al cold start. |
| Usuario hizo logout explícito | Próxima apertura → `/login`. |

### Vinculación de métodos

- **NO se permite** vincular Google↔correo en la misma cuenta en esta HDU.
- El método de auth es único por cuenta: si te registraste con correo, esa cuenta SOLO tiene login con correo.
- Vincular métodos sale en HDU futura (no se prioriza por ahora).

### Resoluciones explícitas (de la sesión de planning con Hugo)

| Pregunta | Resolución |
|----------|------------|
| ¿Google funciona para register y para login? | Sí, pero solo el método con el que te registraste. |
| ¿"Recordarme" checkbox? | No. Sesión persistente por default. |
| ¿Logout → próxima vez pide contraseña o huella? | En esta HDU: contraseña o Google (lo que use). La huella sale en HDU-005b. |
| ¿Biometría? | HDU-005b. |
| ¿Timer de inactividad (bloqueo a los X minutos)? | HDU-005b. |
| ¿Recuperar contraseña? | HDU futura. |
| ¿Cambiar email/password? | HDU futura. |

---

## Decisión arquitectónica (acordada con Hugo el 2026-07-30)

> Decisión A del review de HDU-004: **mover `appRouter` a GetIt como singleton lazy desde el día 1 de esta HDU.** Sin esto, el `redirect` del router no puede consultar `AuthService` limpiamente.

### Por qué

- `AuthService` vive en GetIt (es transversal, como `TierService`).
- El `redirect` de `go_router` se ejecuta antes de cada navegación. Para decidir a dónde redirigir (login vs home), necesita consultar `AuthService.currentSession`.
- Si `appRouter` vive en un archivo como singleton global mutable (como hasta ahora en HDU-004) y `AuthService` vive en GetIt, el `redirect` no tiene forma limpia de obtener el servicio. Tendría que usar un truco (variable global, import circular, etc.).
- Mover `appRouter` a GetIt lo resuelve de raíz: el `redirect` hace `final auth = getIt<AuthService>();` y consulta. Limpio, testeable, sin trucos.

### Cómo se hace

```dart
// lib/core/di/service_locator.dart (extendido)
if (!getIt.isRegistered<GoRouter>()) {
  getIt.registerLazySingleton<GoRouter>(() => buildAppRouter(refreshStream: ...));
}
if (!getIt.isRegistered<AuthService>()) {
  getIt.registerLazySingleton<AuthService>(() => AuthService());
}
```

`appRouter` deja de ser una variable global. Las pantallas que ya lo usaban se actualizan para hacer `getIt<GoRouter>()`.

---

## Problema / Motivación

HDU-004 dejó el router de la app con 4 rutas y placeholders. HDU-003 dejó el sistema de feature flags. Pero **la app no sabe quién es el usuario**: no puede entrar, salir, ni decidir a dónde mandarlo según si ya está autenticado.

Esto bloquea HDU-006 (splash nuevo), que necesita poder decidir "¿lo mando al login o al home?" según el estado de auth. Sin auth, el splash no puede hacer nada útil.

El flujo "estilo banco" que acordamos (registro con correo/Google, sesión persistente, redirect del router) es el estándar que la gente espera hoy. Implementarlo desde cero sienta las bases para HDU-006 y para cualquier feature que necesite saber "quién está viendo esto".

---

## Criterios de aceptación

> Cada AC es verificable con un test automatizado o una inspección manual con un comando concreto.

### AuthService (servicio transversal)

- [ ] **AC1:** `lib/core/auth/auth_service.dart` declara la clase `AuthService` con API mínima: `signUpWithEmail({email, password})`, `signInWithEmail({email, password})`, `signInWithGoogle()`, `signOut()`, `getCurrentSession()`, `authStateChanges` (stream). Todo async, todo devuelve `Result<AuthResult>` o lanza `AuthException` con mensaje accionable.
- [ ] **AC2:** `AuthService` está registrado en GetIt como singleton lazy en `lib/core/di/service_locator.dart`. `getIt<AuthService>()` funciona.
- [ ] **AC3:** `AuthService` envuelve `supabase.auth` (no lo expone directamente). Los features consumen `AuthService`, no `supabase.auth` (regla de arquitectura: core no expone infraestructura).

### Register con correo

- [ ] **AC4:** `lib/features/identidad/screens/register_screen.dart` existe. Tiene un formulario con: email, password (mínimo 8 caracteres, validación en cliente), botón "Crear cuenta".
- [ ] **AC5:** Al tocar "Crear cuenta" con email válido + password ≥ 8 chars: llama a `AuthService.signUpWithEmail`, navega a `/home` al recibir éxito.
- [ ] **AC6:** Si email es inválido o password < 8 chars, muestra error en pantalla sin llamar al servicio.
- [ ] **AC7:** Si `signUpWithEmail` falla (email ya registrado, red caída, etc.), muestra mensaje accionable ("Este correo ya está registrado", "Revisa tu conexión", etc.).

### Register con Google

- [ ] **AC8:** La pantalla de register tiene un botón "Continuar con Google" debajo del formulario de correo.
- [ ] **AC9:** Al tocar "Continuar con Google", dispara el flujo de Google Sign-In (popup del SO). Al confirmar, llama a `AuthService.signInWithGoogle`, navega a `/home` al recibir éxito.
- [ ] **AC10:** Si el usuario cancela el popup de Google, no se hace nada (no se muestra error, no se navega).
- [ ] **AC11:** El proyecto tiene `google_sign_in` como dependencia declarada en `pubspec.yaml` (no transitive).
- [ ] **AC12:** El proyecto de Supabase tiene el provider de Google configurado (Hugo debe hacerlo en el dashboard de Supabase antes de mergear; si no, el flujo de Google fallará en runtime — se documenta en el cleanup).

### Login (con el método del register)

- [ ] **AC13:** `lib/features/identidad/screens/login_screen.dart` reemplaza el placeholder de HDU-004. Detecta con qué método se registró el usuario (correo o Google) y muestra solo la opción correspondiente.
- [ ] **AC14:** Si la cuenta es de **correo**: formulario email + password + botón "Entrar". Al confirmar → `/home`.
- [ ] **AC15:** Si la cuenta es de **Google**: botón único "Entrar con Google". Al confirmar → `/home`.
- [ ] **AC16:** NO hay checkbox de "recordarme". La sesión es persistente por default.
- [ ] **AC17:** Si el login falla (credenciales incorrectas, red caída, etc.), muestra mensaje accionable.

### Home + sign out

- [ ] **AC18:** `lib/features/identidad/screens/home_screen.dart` reemplaza el placeholder de HDU-004. Muestra el email del usuario actual + un botón "Salir".
- [ ] **AC19:** Al tocar "Salir": llama a `AuthService.signOut()`, navega a `/login`.

### Sesión persistente

- [ ] **AC20:** Si el usuario cierra la app completamente (swipe kill) y la reabre, la sesión sigue viva: el router lo manda a `/home`, no a `/login`.
- [ ] **AC21:** Si el usuario hace logout explícito, la próxima vez que abra la app va a `/login`.
- [ ] **AC22:** La sesión expira según las reglas de Supabase (default 1 hora de access token, refresh automático). Si expira, próxima apertura → `/login`.

### Router + redirect (decisión A)

- [ ] **AC23:** `appRouter` deja de ser variable global mutable. Se registra en GetIt como singleton lazy. `getIt<GoRouter>()` devuelve la misma instancia siempre.
- [ ] **AC24:** `GoRouter` tiene un `redirect` global que consulta `AuthService.getCurrentSession()` antes de cada navegación:
  - Si la ruta destino es `/login` o `/register` Y hay sesión → redirige a `/home`.
  - Si la ruta destino es `/home` (o cualquier ruta privada futura) Y NO hay sesión → redirige a `/login`.
  - Si la ruta destino es `/splash` o `/onboarding` → no redirige (son públicas, igual que en HDU-004).
- [ ] **AC25:** Al cold start de la app, el primer redirect decide correctamente entre `/login` y `/home` según la sesión persistida.

### Onboarding + splash

- [ ] **AC26:** El placeholder de `/splash` (`lib/core/router/screens/splash_placeholder.dart`) y de `/onboarding` (`.../onboarding_placeholder.dart`) se quedan **tal cual** en esta HDU. No se tocan. La lógica de "a dónde ir" real del splash se hace en HDU-006.

### Tests

- [ ] **AC27:** `test/core/auth/auth_service_test.dart` cubre con fakes (no mocks de mockito): `signUpWithEmail` éxito, fallo por email duplicado, fallo por password débil. `signInWithEmail` éxito, fallo por credenciales inválidas. `signOut` limpia la sesión. `getCurrentSession` devuelve la sesión actual o `null`.
- [ ] **AC28:** `test/features/identidad/screens/register_screen_test.dart` cubre: render del formulario, validación de email y password, llamada a `AuthService.signUpWithEmail` al tocar el botón, navegación a `/home` en éxito, mensaje de error en fallo.
- [ ] **AC29:** `test/features/identidad/screens/login_screen_test.dart` cubre: detección de método (correo vs Google), render según método, login éxito, mensaje de error en fallo.
- [ ] **AC30:** `test/core/router/redirect_test.dart` cubre con fakes: redirect a `/home` si hay sesión y ruta destino es `/login`. Redirect a `/login` si NO hay sesión y ruta destino es `/home`. Sin redirect si la ruta es `/splash` o `/onboarding`.
- [ ] **AC31:** `integration_test/auth_flow_test.dart` cubre con device real (Xiaomi): register con correo → home → logout → login → home → cerrar app → reabrir → home. Cubre el flujo end-to-end incluyendo persistencia de sesión.

### Pipeline + integración con Supabase

- [ ] **AC32:** `flutter analyze` 0 warnings, `flutter test` 100% verde, `flutter test integration_test/auth_flow_test.dart -d 2203129G` pasa, `flutter build apk --debug` compila.
- [ ] **AC33:** El proyecto de Supabase tiene configurado el provider de Google en el dashboard (Hugo lo hace; está documentado en `docs/runbooks/` si no existe).

### No regresión (compromiso con Hugo)

- [ ] **AC34:** Todos los tests de las HDUs cerradas (001-004) siguen pasando después de esta HDU. **No se rompe nada de lo que ya funciona.** El implementer corre la suite completa antes de reportar "listo", y reporta cualquier regresión como bloqueante.
- [ ] **AC35:** Las 4 rutas de HDU-004 (`/splash`, `/onboarding`, `/login`, `/home`) siguen existiendo y siendo navegables. La pantalla de `/login` cambia de placeholder a real, pero la ruta es la misma. **No se renombran rutas** sin coordinación.

---

## Archivos afectados

**Nuevos:**

- `lib/core/auth/auth_service.dart` — la clase `AuthService` (signUp, signIn, signOut, getCurrentSession, authStateChanges).
- `lib/core/auth/auth_exception.dart` — excepción custom con mensajes accionables.
- `lib/core/auth/google_sign_in_handler.dart` — wrapper sobre `google_sign_in` con fakes para tests.
- `lib/features/identidad/screens/register_screen.dart` — pantalla de register (real, no placeholder).
- `lib/features/identidad/screens/home_screen.dart` — pantalla de home (real, no placeholder).
- `test/core/auth/auth_service_test.dart` — unit tests del AuthService con fakes.
- `test/core/auth/google_sign_in_handler_test.dart` — unit tests del wrapper de Google.
- `test/features/identidad/screens/register_screen_test.dart` — widget tests.
- `test/features/identidad/screens/login_screen_test.dart` — widget tests (reescribe el smoke test de HDU-004).
- `test/core/router/redirect_test.dart` — tests del redirect con fakes.
- `integration_test/auth_flow_test.dart` — integration test del flujo completo.

**Modificados:**

- `pubspec.yaml` — agregar `google_sign_in: ^6.0.0` (o versión compatible) como dependencia directa.
- `lib/core/di/service_locator.dart` — registrar `AuthService` Y `GoRouter` como singletons lazy.
- `lib/core/router/app_router.dart` — agregar `redirect` global. Cambiar de variable global mutable a factory `buildAppRouter(authService)`. El `errorBuilder` se mantiene igual que en HDU-004.
- `lib/core/router/screens/login_placeholder.dart` — **se elimina**. El placeholder es reemplazado por `lib/features/identidad/screens/login_screen.dart`.
- `lib/core/router/screens/home_placeholder.dart` — **se elimina**. El placeholder es reemplazado por `lib/features/identidad/screens/home_screen.dart`.
- `lib/main.dart` — usar `getIt<GoRouter>()` en vez de la variable global. Inicializar `AuthService` (la primera llamada a `getIt<AuthService>()` crea la instancia; lazy).
- `test/widget_test.dart` — actualizar los smoke tests para reflejar que `/login` ahora es real y no placeholder.
- `docs/current-state.md` — actualizar cuando se mergee (cleanup).
- `.mavis/hdu.md` (local, en `.gitignore`) — registrar la HDU-005 cerrada.
- `docs/runbooks/` (posible) — runbook nuevo para "Configurar Google provider en Supabase dashboard".

**Eliminados:**

- `lib/core/router/screens/login_placeholder.dart` — reemplazado por `lib/features/identidad/screens/login_screen.dart`.
- `lib/core/router/screens/home_placeholder.dart` — reemplazado por `lib/features/identidad/screens/home_screen.dart`.

---

## Plan técnico (pasos verificables)

1. **Agregar `google_sign_in` a `pubspec.yaml`.** Confirmar versión compatible con Flutter 3.38.3.
2. **Crear `lib/core/auth/auth_exception.dart`** — clase custom que envuelve errores de Supabase Auth con mensajes en español, accionables, sin exponer detalles internos.
3. **Crear `lib/core/auth/auth_service.dart`** — la clase `AuthService` con los métodos del AC1. Internamente usa `Supabase.instance.client.auth`. Por ahora sin stream de auth state changes (eso es para refresh reactivo de la UI, no es bloqueante en esta HDU).
4. **Crear `lib/core/auth/google_sign_in_handler.dart`** — wrapper sobre `google_sign_in: ^6.0.0`. Encapsula el popup del SO. Devuelve un idToken para que `AuthService` lo pase a `supabase.auth.signInWithIdToken`.
5. **Actualizar `lib/core/di/service_locator.dart`:**
   - Registrar `AuthService` como singleton lazy.
   - Registrar `GoRouter` como singleton lazy, llamando a `buildAppRouter(authService: getIt<AuthService>())`.
6. **Refactor `lib/core/router/app_router.dart`:**
   - Convertir `appRouter` de variable global a función `buildAppRouter({required AuthService authService})`.
   - Agregar `redirect` global según el AC24.
   - **NO** cambiar las rutas existentes ni sus paths.
7. **Crear `lib/features/identidad/screens/register_screen.dart`:**
   - Formulario email + password.
   - Validación en cliente (email regex, password ≥ 8).
   - Botón "Crear cuenta" llama a `AuthService.signUpWithEmail`.
   - Botón "Continuar con Google" llama a `AuthService.signInWithGoogle`.
   - Navega a `/home` en éxito.
8. **Crear `lib/features/identidad/screens/home_screen.dart`:**
   - Muestra email del usuario actual (`AuthService.getCurrentSession()?.user.email`).
   - Botón "Salir" llama a `AuthService.signOut()`, navega a `/login`.
9. **Reescribir `lib/features/identidad/screens/login_screen.dart` (reemplaza el placeholder):**
   - Detecta método de auth de la cuenta que intenta loguearse. Por ahora, simplificación: tiene un formulario de correo+contraseña Y un botón de Google. Cuando el usuario ingresa un email que ya existe, el sistema sabe con qué método se registró y muestra solo el correcto (futuro: en esta HDU mostramos ambos métodos y dejamos que Supabase rechace el incorrecto con mensaje claro).
   - **Decisión de scope:** para esta HDU, el login screen muestra AMBOS métodos (correo y Google). El usuario elige. Si elige el método incorrecto, Supabase devuelve error y mostramos "esta cuenta fue registrada con Google, intenta con el botón de Google" (o viceversa). Más simple que auto-detectar y más transparente.
10. **Eliminar `lib/core/router/screens/login_placeholder.dart` y `home_placeholder.dart`.** Migrar cualquier referencia a las pantallas reales.
11. **Actualizar `lib/main.dart`** para usar `getIt<GoRouter>()` en vez de la variable global. Inicializar `AuthService` (lazy, se hace en el primer `getIt<AuthService>()`).
12. **Tests:**
   - `test/core/auth/auth_service_test.dart` con fakes (no `mockito`).
   - `test/core/auth/google_sign_in_handler_test.dart` con fakes.
   - `test/features/identidad/screens/register_screen_test.dart` widget tests.
   - `test/features/identidad/screens/login_screen_test.dart` widget tests.
   - `test/core/router/redirect_test.dart` tests del redirect.
   - `integration_test/auth_flow_test.dart` integration test del flujo completo.
13. **Configurar Google provider en Supabase** (acción de Hugo, documentada en runbook si no existe).
14. **Pipeline local:** `flutter analyze`, `flutter test`, `flutter test integration_test/auth_flow_test.dart -d 2203129G`, `flutter build apk --debug`. Todo verde.
15. **Regression check (AC34):** correr la suite completa de tests (HDUs 001-004) y confirmar 0 regresiones. Si alguna falla, **bloqueante** — el implementer corrige antes de reportar "listo".

---

## Notas / Decisiones explícitas

- **NO hay redirección automática del login screen al método correcto.** El usuario ve ambos métodos, elige, y Supabase le dice si eligió el incorrecto. Es más simple, más transparente, y suficiente para MVP. La auto-detección sale en HDU futura.
- **`AuthService` no expone el stream `authStateChanges` en esta HDU.** No es necesario para los criterios actuales (el redirect consulta `getCurrentSession` en cada navegación, que es suficiente). El stream reactivo se agrega cuando alguna pantalla lo necesite (probablemente HDU-005b o HDU-006).
- **Pantallas son funcionales, no bonitas.** El diseño visual (colores de Zeiki, animaciones, micro-interacciones) sale en HDU futura. Esta HDU es el "esqueleto funcional".
- **Google Sign-In requiere config en el dashboard de Supabase.** El implementer documenta el paso a paso en `docs/runbooks/google-signin-supabase.md` (o el nombre que Hugo prefiera). Hugo hace el config antes de mergear.
- **`google_sign_in` requiere SHA-1 del certificado de debug en Firebase/Google Cloud Console.** Para HDU-005 MVP basta con el SHA-1 del debug. El de release se agrega cuando se configure CI/CD.
- **Decisión A (router a GetIt) está aprobada por Hugo.** Esta HDU la implementa.
- **No regresión (compromiso con Hugo).** El implementer corre la suite completa de tests de HDUs 001-004 antes de reportar "listo". Cualquier regresión es bloqueante.

---

## Fuera de scope (NO se hace en esta HDU)

- **Biometría** (huella, cara) → HDU-005b.
- **Timer de inactividad / auto-logout por seguridad** → HDU-005b.
- **Vincular Google↔correo en la misma cuenta** → HDU futura.
- **Recuperar contraseña** → HDU futura.
- **Cambiar email o contraseña desde la app** → HDU futura.
- **Verificar email (envío de correo de confirmación)** → se documenta como decisión de Supabase (probablemente se activa por default). Si falla, sale como follow-up.
- **Diseño visual final de las pantallas** (colores, tipografía, animaciones) → HDU futura.
- **Onboarding real** (introducción a la app, swipe pages, etc.) → el placeholder se queda, la lógica real sale en HDU futura.
- **Splash nuevo con lógica de "a dónde ir"** → HDU-006.
- **Auto-detección de método de auth en login** → HDU futura.

---

## Riesgos

- **Riesgo medio — Google Sign-In requiere config externo.** Hugo debe configurar el provider en Supabase dashboard y registrar el SHA-1 en Google Cloud Console. Sin esto, el botón de Google falla. **Acción:** runbook + checklist en cleanup para que Hugo lo haga antes de mergear.
- **Riesgo bajo — `google_sign_in` versión 6.x tiene cambios de API respecto a 5.x.** Si la doc indica breaking changes, el implementer los aplica. Si la versión no es compatible con `supabase_flutter` actual, se ajusta en `pubspec.yaml`.
- **Riesgo bajo — mover `appRouter` a GetIt rompe el patrón existente.** La `appRouter` se usa en `main.dart`, en los placeholders (que se eliminan), y en el `errorBuilder`. Hay que actualizar todas las referencias. Cubierto en el plan técnico paso 11.
- **Riesgo bajo — el redirect puede causar loops infinitos si está mal escrito.** Por ejemplo: si la lógica siempre redirige a `/login` y `/login` redirige a `/home`. Se cubre con el test del AC30 (verifica que no haya loop).
- **Riesgo bajo — `AuthService` envuelve Supabase, pero si alguien accede a `supabase.auth` directamente, rompe la abstracción.** El linter no puede detectarlo. Se documenta en conventions §X (a actualizar por el implementer o en cleanup).

---

## Sistemas externos involucrados

- **Supabase Auth (email + password):** nativo, ya configurado en HDU-002. Solo se usa.
- **Supabase Auth (Google OAuth):** requiere config en dashboard. Acción de Hugo.
- **Google Sign-In (`google_sign_in` package):** requiere SHA-1 del certificado de debug registrado. Acción de Hugo.
- **Google Cloud Console:** para registrar el OAuth client y el SHA-1. Acción de Hugo.
