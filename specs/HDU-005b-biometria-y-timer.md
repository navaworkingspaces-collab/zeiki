# HDU-005b — Biometría + timer de inactividad

**Tipo:** feature
**Prioridad:** alta
**Estado:** pendiente
**Fecha:** 2026-07-31
**Sistemas externos involucrados:** ninguno (todo es cliente — `local_auth` para biometría del SO)
**Dominio(s):** `lib/core/auth/` (extensión) + `lib/features/identidad/` (pantalla de activación)

---

## Check de entendimiento (3 líneas)

- Lo que quieres: que después de registrarme me pregunte si quiero usar huella, y que la app se bloquee solita si la dejo mucho tiempo sin usar.
- Vas a saber que está bien cuando: pueda entrar con huella (si la activé), que la app me bloquee a los X minutos sin actividad, y al volver me pida huella o contraseña según lo que haya elegido.
- Esto NO se va a hacer: vincular huella con cuenta de Google, opciones avanzadas de seguridad (whitelist de dispositivos, login desde nuevo dispositivo con confirmación), ni cambios en el flujo de auth más allá de lo que ya existe.

---

## Decisiones de producto (acordadas con Hugo en la planning de HDU-005)

> Esta sección documenta EL QUÉ, no el cómo.

### Flujo de activación de biometría (después del register/login)

1. El usuario completa su **primer** register o login exitoso con correo/Google.
2. La app le muestra un popup modal: **"¿Quieres usar tu huella para entrar más rápido la próxima vez?"**
3. El popup tiene 2 botones: **"Activar"** y **"Ahora no"**.
4. Si toca **"Activar"**: la app le pide la huella UNA vez (popup del SO). Si la huella es válida, se guarda el flag `biometricEnabled: true` en `flutter_secure_storage` y se cierra el popup.
5. Si toca **"Ahora no"**: el popup se cierra. **No se vuelve a mostrar en este login** (es one-shot por sesión).
6. **NO se ofrece activar biometría en la pantalla de login** (ya hay flujo normal). Solo el popup modal post-login.

### Flujo de re-auth con biometría (cold start / background largo / post-logout)

| Situación | Comportamiento |
|-----------|----------------|
| App cerrada completamente (cold start) | Si `biometricEnabled == true` y hay sesión persistida → pide huella. Si la huella es válida → navega a `/home`. Si falla 3 veces → fallback a login normal con correo/Google. |
| App en background < 5 minutos y vuelve | NO consulta nada. La app sigue donde estaba. |
| App en background > 5 minutos y vuelve | **Pide biometría** (si está habilitada) o **login normal** (si no). |
| Usuario hizo logout explícito | Próxima apertura: si `biometricEnabled == true` → pide huella. Si no → login normal. |

### Flujo del timer de inactividad (auto-logout)

1. Mientras la app está abierta y el usuario interactúa (taps, scrolls, gestos), el timer se **resetea**.
2. Si pasan **X minutos** (default 5, configurable) sin interacción, la app **se bloquea**.
3. Al desbloquear, la app pide biometría (si está habilitada) o login normal.
4. El timer solo aplica a la app en **foreground** — cuando está en background, el timer sigue corriendo (no se pausa). Esto matchea el comportamiento de los bancos.
5. **NO** hay un botón "bloquear ahora" (los bancos lo tienen, lo dejamos para HDU futura).

### Resolución de "logout → próxima vez"

- **LogOut explícito:** la sesión se limpia localmente. La próxima vez, la app **puede usar biometría** (si está habilitada) **o login normal**. El dispositivo sigue recordando al usuario.
- Esto es lo que acordamos en la planning de HDU-005: el logout es "ya terminé por hoy", no "soy un extraño".

### Configuración del timer

- Default: **5 minutos** sin actividad → bloqueo.
- Configurable vía `AuthServiceConfig.inactivityTimeout`.
- Sale como `const` en el código, ajustable en HDU futura de "settings" si hace falta.
- Si en uso real 5 min es muy agresivo, se sube a 15. **Se documenta como follow-up** para revisión con datos.

### Resoluciones explícitas

| Pregunta | Resolución |
|----------|------------|
| ¿Cuándo se ofrece la biometría? | Popup modal después del primer register/login exitoso. |
| ¿El popup se muestra cada vez? | No, es one-shot por sesión. |
| ¿Biometría funciona después de logout? | Sí, el dispositivo sigue confiando en el usuario. |
| ¿Timer aplica en background? | Sí, sigue corriendo. Si vuelve después de X min, pide biometría. |
| ¿Default del timer? | 5 minutos. Configurable. |
| ¿Biometría en login screen? | No, solo en el popup modal post-login. |
| ¿Vincular huella con Google? | No, sale en HDU futura. |
| ¿Whitelist de dispositivos? | No, sale en HDU futura. |

---

## Decisiones arquitectónicas

### Conectar `authStateChanges` al `GoRouter.refreshListenable`

> Esta es la pieza que el `zeiki-reviewer` de HDU-004 mencionó como "cuando llegue HDU-005b" y que el implementer de HDU-005 dejó como `GoRouterRefreshStream` ya construido pero sin conectar.

- `AuthService` ya expone `authStateChanges: Stream<sb.AuthState>` (es parte del AC1 de HDU-005).
- En esta HDU, el `service_locator` conecta ese stream al `GoRouter.refreshListenable`:
  ```dart
  getIt.registerLazySingleton<GoRouter>(() {
    final authService = getIt<AuthService>();
    return buildAppRouter(
      authServiceGetter: () => authService,
      refreshStream: authService.authStateChanges,  // ← NUEVO
    );
  });
  ```
- Resultado: cuando el usuario hace `signOut`, el `authStateChanges` emite, el router re-evalúa el `redirect`, y manda a `/login` automáticamente. **No más "tocar la pantalla para que el router reaccione"**.

### `BiometricService` separado de `AuthService`

- `AuthService` se mantiene enfocado en Supabase (register, login, logout, session).
- Nuevo `BiometricService` en `lib/core/auth/biometric_service.dart` encapsula la lógica de huella:
  - `isBiometricAvailable()` — checa si el dispositivo tiene huella/cara configurada.
  - `authenticate(reason)` — dispara el popup del SO.
  - `setBiometricEnabled(bool)` / `isBiometricEnabled()` — persiste el flag en `flutter_secure_storage`.
- `AuthService` consume `BiometricService` cuando es relevante (en el cold start, decide si pedir huella o login normal).

### Persistencia segura

- El flag `biometricEnabled` se guarda en `flutter_secure_storage` (NO en `SharedPreferences`, conventions §6).
- La KEY es por usuario: `biometric_enabled_<user_id>`. Si un usuario tiene 2 cuentas en el mismo dispositivo, cada una tiene su flag independiente.
- El session token de Supabase **sigue** en `SharedPreferences` (es un follow-up del review de HDU-005, no se mete en esta HDU).

---

## Problema / Motivación

HDU-005 dejó el auth básico funcionando: email + Google, sesión persistente, redirect del router. Pero le faltan 2 piezas que son **estándar en cualquier app de hoy**:

1. **Biometría** (huella/cara): los usuarios esperan poder entrar sin escribir contraseña. Sin esto, la app se siente "vieja".
2. **Timer de inactividad:** los usuarios esperan que la app se bloquee solita si la dejan desatendida. Sin esto, la app se siente "insegura".

El `zeiki-reviewer` de HDU-004 también dejó como follow-up explícito conectar `authStateChanges` al `GoRouter.refreshListenable` (que ya está construido como `GoRouterRefreshStream` en `app_router.dart`, esperando el stream real). Esta HDU cierra ese follow-up también.

---

## Criterios de aceptación

### BiometricService

- [ ] **AC1:** `lib/core/auth/biometric_service.dart` declara la clase `BiometricService` con API: `isBiometricAvailable()` (Future<bool>), `authenticate(String reason)` (Future<bool>), `setBiometricEnabled(bool)` (Future<void>), `isBiometricEnabled({String userId})` (Future<bool>).
- [ ] **AC2:** `BiometricService` está registrado en GetIt como singleton lazy en `lib/core/di/service_locator.dart`.
- [ ] **AC3:** El flag `biometricEnabled` se guarda en `flutter_secure_storage` con KEY por usuario: `biometric_enabled_<user_id>`. Se lee con la misma KEY.
- [ ] **AC4:** Si el dispositivo no tiene biometría configurada (huella/cara deshabilitadas en el SO), `isBiometricAvailable()` devuelve `false` y la app NO ofrece el popup de activación.

### Popup de activación (post-login)

- [ ] **AC5:** Después del primer register/login exitoso con correo/Google, la app muestra un `Dialog` modal con el texto **"¿Quieres usar tu huella para entrar más rápido la próxima vez?"** y 2 botones: **"Activar"** y **"Ahora no"**.
- [ ] **AC6:** Al tocar "Activar": la app llama a `BiometricService.authenticate("Activar biometría para Zeiki")`. Si la huella es válida, llama a `setBiometricEnabled(true)` y cierra el popup. Si falla o cancela, cierra el popup sin guardar.
- [ ] **AC7:** Al tocar "Ahora no": cierra el popup sin guardar nada. El popup **NO** se vuelve a mostrar en esta sesión.
- [ ] **AC8:** El popup es one-shot por sesión. Si el usuario hizo logout y vuelve a entrar, el popup vuelve a salir (porque es una "sesión de uso" nueva).
- [ ] **AC9:** Si `BiometricService.isBiometricAvailable() == false` al momento del popup, NO se muestra (porque no tiene sentido ofrecer algo que no se puede usar).

### Re-auth con biometría (cold start / background largo / post-logout)

- [ ] **AC10:** En el cold start de la app, si `biometricEnabled == true` Y hay sesión persistida, la app **NO navega a `/login`** — en su lugar muestra una pantalla de "Desbloquear con huella" (`UnlockScreen`) que llama a `BiometricService.authenticate()`.
- [ ] **AC11:** Si la huella es válida, navega a `/home` (sin pasar por login).
- [ ] **AC12:** Si la huella falla 3 veces consecutivas, la app **fallback a login normal** (limpia la sesión local y navega a `/login`).
- [ ] **AC13:** Si la huella falla 1-2 veces, el `UnlockScreen` muestra mensaje "Huella no reconocida, intenta de nuevo" y permite reintentar.
- [ ] **AC14:** Si el usuario cancela el popup del SO de huella, el `UnlockScreen` muestra "Huella cancelada" + botón "Usar contraseña" que navega a `/login`.
- [ ] **AC15:** El `UnlockScreen` vive en `lib/features/identidad/screens/unlock_screen.dart`. Se registra como ruta `/unlock` en el router.
- [ ] **AC16:** Si `biometricEnabled == false`, el cold start navega directamente a `/login` (no hay pantalla de unlock).

### Timer de inactividad

- [ ] **AC17:** `AuthService` o un nuevo `InactivityMonitor` (en `lib/core/auth/inactivity_monitor.dart`) detecta taps, scrolls y gestos del usuario. Cada interacción **resetea el timer**.
- [ ] **AC18:** Default: **5 minutos** sin interacción → la app llama a `AuthService.signOut()` y navega a `/login`.
- [ ] **AC19:** El timer **sigue corriendo cuando la app está en background**. Si la app vuelve al foreground después de > X minutos, la app se bloquea (equivalente a cold start: pide biometría o navega a `/login`).
- [ ] **AC20:** El `InactivityMonitor` está conectado al ciclo de vida de la app (se inicia en `main.dart` después de `runApp`, se detiene en dispose).
- [ ] **AC21:** El default de 5 min es `const AuthServiceConfig.inactivityTimeout = Duration(minutes: 5)`. Cambiar este valor cambia el comportamiento global.

### Conectar `authStateChanges` al router (Decisión A del review de HDU-004)

- [ ] **AC22:** El `service_locator` conecta `authService.authStateChanges` al `GoRouter.refreshListenable` vía el `refreshStream` del `buildAppRouter`:
  ```dart
  getIt.registerLazySingleton<GoRouter>(() {
    final auth = getIt<AuthService>();
    return buildAppRouter(
      authServiceGetter: () => auth,
      refreshStream: auth.authStateChanges,
    );
  });
  ```
- [ ] **AC23:** Después de esta conexión, hacer `signOut()` desde cualquier pantalla causa que el router re-evalúe el `redirect` automáticamente (sin tocar la pantalla).
- [ ] **AC24:** El `GoRouterRefreshStream` que el implementer de HDU-005 dejó construido se conecta por fin (era código defensivo esperando este momento).

### Tests

- [ ] **AC25:** `test/core/auth/biometric_service_test.dart` cubre con fakes: `isBiometricAvailable` según el SO, `authenticate` éxito y fallo, `setBiometricEnabled` + `isBiometricEnabled` round-trip en secure storage, KEY por usuario.
- [ ] **AC26:** `test/core/auth/inactivity_monitor_test.dart` cubre: tap resetea el timer, scroll resetea el timer, no-interacción por X tiempo llama a `signOut` + navega a `/login`.
- [ ] **AC27:** `test/features/identidad/screens/unlock_screen_test.dart` cubre: huella válida → navega a `/home`, huella falla 3 veces → fallback a `/login`, usuario cancela → botón "Usar contraseña".
- [ ] **AC28:** `test/features/identidad/screens/activation_dialog_test.dart` cubre: el popup aparece una vez, "Activar" llama a `authenticate`, "Ahora no" cierra sin guardar.
- [ ] **AC29:** `integration_test/biometric_flow_test.dart` cubre en Xiaomi: register → activar biometría → cerrar app → reabrir → UnlockScreen → huella simulada → home. (La huella simulada depende de `local_auth`'s test mode; se documenta cómo.)
- [ ] **AC30:** `integration_test/inactivity_flow_test.dart` cubre en Xiaomi: login → simular inactividad por 5+ min → verificar que la app se bloquea y pide auth. (Más difícil de automatizar; puede ser smoke test con timeout corto.)

### Pipeline + no regresión

- [ ] **AC31:** `flutter analyze` 0 warnings, `flutter test` 100% verde, `flutter test integration_test/` (en Xiaomi) pasa los flows nuevos, `flutter build apk --debug` compila.
- [ ] **AC32:** **NO regresión** (compromiso con Hugo, AC34 de HDU-005). Todos los tests de las 5 HDUs cerradas (001-005) siguen pasando después de esta HDU. Bloqueante si alguno falla.

---

## Archivos afectados

**Nuevos:**

- `lib/core/auth/biometric_service.dart` — `BiometricService` con la API del AC1.
- `lib/core/auth/inactivity_monitor.dart` — detecta taps/scrolls/gestos, resetea el timer, llama a `signOut` después de X min.
- `lib/core/auth/auth_service_config.dart` — `const AuthServiceConfig { inactivityTimeout = Duration(minutes: 5) }`.
- `lib/features/identidad/screens/unlock_screen.dart` — pantalla de "Desbloquear con huella".
- `lib/features/identidad/widgets/biometric_activation_dialog.dart` — el popup modal.
- `test/core/auth/biometric_service_test.dart` — unit tests.
- `test/core/auth/inactivity_monitor_test.dart` — unit tests.
- `test/features/identidad/screens/unlock_screen_test.dart` — widget tests.
- `test/features/identidad/widgets/biometric_activation_dialog_test.dart` — widget tests.
- `integration_test/biometric_flow_test.dart` — integration test.
- `integration_test/inactivity_flow_test.dart` — integration test.

**Modificados:**

- `pubspec.yaml` — agregar `local_auth: ^2.3.0` como dependencia directa.
- `lib/core/di/service_locator.dart` — registrar `BiometricService`, `InactivityMonitor`. Conectar `authStateChanges` al `GoRouter.refreshListenable` (AC22).
- `lib/core/auth/auth_service.dart` — agregar `currentUserId` getter para que el `BiometricService` use la KEY por usuario.
- `lib/core/router/app_router.dart` — agregar ruta `/unlock` y `buildAppRouter` acepta `refreshStream` (que ya existe del HDU-005, ahora se conecta).
- `lib/features/identidad/screens/home_screen.dart` — agregar botón "Activar/Desactivar biometría" en el menú (settings chiquito).
- `lib/features/identidad/screens/register_screen.dart` + `login_screen.dart` — después del éxito, mostrar el `BiometricActivationDialog` (one-shot por sesión).
- `lib/main.dart` — iniciar `InactivityMonitor` después de `runApp`.
- `docs/current-state.md` — actualizar al mergear (cleanup).
- `.mavis/hdu.md` (local) — registrar la HDU-005b cerrada.

**Eliminados:** ninguno.

---

## Plan técnico (pasos verificables)

1. **Agregar `local_auth: ^2.3.0` a `pubspec.yaml`.** Confirmar versión compatible con Flutter 3.38.3.
2. **Crear `lib/core/auth/auth_service_config.dart`** — `const AuthServiceConfig { inactivityTimeout = Duration(minutes: 5) }`.
3. **Crear `lib/core/auth/biometric_service.dart`** — la clase con la API del AC1. Usa `local_auth` internamente para `authenticate` y `canCheckBiometrics`. Usa `flutter_secure_storage` para el flag.
4. **Crear `lib/core/auth/inactivity_monitor.dart`** — un `StatefulWidget` o un `Notifier` que envuelve la app. Usa un `Timer` que se resetea con cada interacción (`Listener` widget o `WidgetsBindingObserver`).
5. **Modificar `lib/core/di/service_locator.dart`:**
   - Registrar `BiometricService` y `InactivityMonitor`.
   - Conectar `auth.authStateChanges` al `GoRouter.refreshStream` (AC22).
6. **Crear `lib/features/identidad/widgets/biometric_activation_dialog.dart`** — `AlertDialog` con el texto y 2 botones. **No-op en esta sesión** (one-shot) se implementa con un flag en memoria (no se persiste entre cierres de app).
7. **Crear `lib/features/identidad/screens/unlock_screen.dart`** — pantalla full-screen con icono de huella + texto "Toca el sensor" + botón "Usar contraseña" en la esquina.
8. **Modificar `lib/core/router/app_router.dart`** — agregar ruta `/unlock` que muestra `UnlockScreen`. El `redirect` debe actualizar la lógica: si destino es `/home` o cualquier ruta privada, no hay sesión Y `biometricEnabled == true` → ir a `/unlock` (no a `/login`).
9. **Modificar `lib/features/identidad/screens/register_screen.dart` y `login_screen.dart`** — después del éxito de Supabase, antes de navegar a `/home`, mostrar el `BiometricActivationDialog` (one-shot por sesión).
10. **Modificar `lib/features/identidad/screens/home_screen.dart`** — agregar botón "Activar/Desactivar biometría" en un `PopupMenuButton` (settings chiquito).
11. **Modificar `lib/main.dart`** — envolver la app en `InactivityMonitor`. Iniciar el monitor después de `runApp` (o el monitor se auto-inicia con el widget).
12. **Tests:**
   - `test/core/auth/biometric_service_test.dart` con fakes.
   - `test/core/auth/inactivity_monitor_test.dart` con `fakeAsync` para controlar el tiempo.
   - `test/features/identidad/screens/unlock_screen_test.dart` widget tests.
   - `test/features/identidad/widgets/biometric_activation_dialog_test.dart` widget tests.
   - `integration_test/biometric_flow_test.dart` y `inactivity_flow_test.dart` en Xiaomi.
13. **Pipeline local:** `flutter analyze`, `flutter test`, `flutter test integration_test/`, `flutter build apk --debug`. Todo verde.
14. **Regression check (AC32):** correr la suite completa de HDUs 001-005. Si alguna falla, **bloqueante** — corregir antes de reportar "listo".

---

## Notas / Decisiones explícitas

- **`local_auth` en iOS requiere permisos en `Info.plist`** (no aplica para Android-only MVP, se documenta en runbook para cuando se agregue iOS).
- **`local_auth` requiere que el dispositivo tenga biometría configurada** en el SO. Si el usuario la desactivó después de activar en Zeiki, `authenticate()` falla — el fallback a login normal cubre ese caso.
- **El timer de inactividad NO se pausa cuando la app está en background** (matchea comportamiento de bancos).
- **El popup de activación es one-shot POR SESIÓN** (se muestra una vez por login). No se persiste entre cierres de app — si quieres que sea "una vez cada 30 días" o "solo la primera vez absoluta", es HDU futura.
- **El flag de "popup ya mostrado en esta sesión"** vive en memoria (no se persiste). Si el usuario cierra la app, el popup vuelve a salir.
- **El `UnlockScreen` es full-screen, no modal.** Cuando el cold start lo muestra, la app no tiene nav bar ni back button.
- **`GoRouterRefreshStream` finalmente se conecta.** Esto era código defensivo de HDU-005 esperando este momento. El review de HDU-004 ya había mencionado que cuando llegue HDU-005b se conectaría.
- **El biometric flag se guarda por usuario** (no global). Si compartes el dispositivo con otra cuenta, cada una tiene su flag independiente.

---

## Fuera de scope (NO se hace en esta HDU)

- Vincular huella con cuenta de Google (sigue siendo "cada método de auth tiene su propio flag").
- Whitelist de dispositivos (rechazar login desde dispositivos nuevos).
- Login desde nuevo dispositivo con confirmación por email.
- Bloqueo manual (botón "bloquear ahora" en settings).
- Ajustar el timer de inactividad desde la UI (se hace editando `const AuthServiceConfig.inactivityTimeout`).
- Biometría para confirmar acciones destructivas (ej. "borrar cuenta") — eso es HDU futura de seguridad.
- Migrar el session token de Supabase a `flutter_secure_storage` (es follow-up del review de HDU-005, queda para HDU aparte).

---

## Riesgos

- **Riesgo medio — `local_auth` 2.x tiene cambios de API respecto a 1.x.** Si la doc indica breaking changes, el implementer los aplica.
- **Riesgo medio — biometría en Xiaomi puede ser simulada.** El `Xiaomi 2203129G` tiene huella configurada, pero la integración test no puede simular una huella real. Se documenta cómo correr la integración con `local_auth` en modo test, o se hace QA manual.
- **Riesgo bajo — el timer de inactividad puede ser molesto en desarrollo.** Si el dev está haciendo hot reload cada 30 segundos, el timer se resetea por la interacción. OK.
- **Riesgo bajo — `flutter_secure_storage` ya está declarada en `pubspec.yaml` desde HDU-001.** No se agrega dep nueva.
- **Riesgo bajo — el `refreshStream` en `GoRouter` puede causar loops si no se configura bien.** El implementer ya tiene la pieza (`GoRouterRefreshStream`) construida; solo se conecta.

---

## Sistemas externos involucrados

- **Ningún sistema externo backend** (todo es cliente).
- **`local_auth`** — el SO del dispositivo (huella/cara/IRIS según el modelo).
- **`flutter_secure_storage`** — ya declarado, se usa para el flag `biometricEnabled`.
