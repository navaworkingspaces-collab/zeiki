# HDU-007 — Flujo de confirmación de email + reset password con deep links

> **Tipo:** feature
> **Prioridad:** alta
> **Estado:** ✅ cerrada (PR #19 mergeado el 2026-08-03). **Cleanup verify-email aplicado el 2026-08-04** — la ruta `/auth/verify-email` y la `VerifyEmailScreen` se removieron (Supabase no emite un evento dedicado de "verify email exitoso"). El flujo de reset password sigue funcional.
> **Rama original:** `feat/HDU-007-email-callback-flow` (mergeada).
> **Rama del cleanup:** `chore/cleanup-verify-email-screen`.
> **PR original:** #19.

---

## Contexto

Hoy en Zeiki, cuando un user se registra con email + password, Supabase manda un email de confirmación. El link del email apunta al **Site URL** del proyecto (configurado en el dashboard de Supabase, NO `localhost:3000` como en la versión rota original). Para que el link abra la app directo (en vez del navegador), Supabase necesita el `emailRedirectTo` apuntando al deep link custom.

**Decisión de producto (post-merge, 2026-08-04):** la pantalla `/auth/verify-email` se removió del producto. Supabase no emite un evento dedicado de "verify email exitoso" — el flujo real es:
1. User hace click en el link del email → Supabase confirma la cuenta.
2. La app navega a `/login` (con sesión temporal creada al procesar el link).
3. El user hace sign in normal y entra a `/home`.

Como NO hay un evento "verify email exitoso" dedicado, no tiene sentido tener una pantalla intermedia que se muestre solo "después" de confirmar. El flujo legacy hacía esto pero era un parche visual, no un patrón.

**Reset password SÍ se mantiene** (HDU-007 funcionalidad real): la pantalla `/auth/reset-password` se sigue mostrando cuando el user llega por el deep link de reset, porque ahí SÍ hay una sesión temporal con `updateUser` pendiente.

**La app legacy `seiki_app` SÍ tenía el flujo de verify-email** (verificado el 2026-08-03 leyendo el legacy en `C:\Users\Pc\Documents\Seiki\seiki_legacy_temp`). Lo hacía con **deep links custom** (scheme `io.supabase.flutter://`) + intent-filter en el manifest. Sin dominio, sin App Links, sin assetlinks.json.

**Esta HDU replica ese patrón en Zeiki** (knowledge reuse, NO desde cero, según HDU-009). El patrón de deep link custom se preserva para reset password.

---

## Cambios

### 1. `lib/core/auth/auth_service.dart`

Agregar `resetPasswordForEmail` (módulo nuevo):

```dart
/// Manda un email al user con un link de reset. El link apunta al
/// deep link `io.supabase.flutter://reset-password/`. Cuando el user
/// hace click, la app abre directamente en la pantalla de reset.
Future<void> resetPasswordForEmail(String email) async {
  try {
    await _resetPasswordForEmailFn(email: email);
  } catch (e) {
    throw mapSupabaseAuthError(e);
  }
}
```

Más su typedef, default, y registro en el constructor (igual que el resto de métodos).

**Nota (post-merge, 2026-08-04):** el `emailRedirectTo` que se agregó originalmente a `signUpWithEmail` se removió. Supabase usa el **Site URL** del proyecto (configurado en el dashboard) como redirect default. El link del email sigue apuntando al Site URL (no a `io.supabase.flutter://`), pero como la sesión temporal se crea al procesar el token, el user puede hacer sign in normal después.

### 2. `android/app/src/main/AndroidManifest.xml`

Agregar dentro del `<activity>` (justo después del intent-filter existente), un nuevo intent-filter con 2 `<data>` (post-cleanup: se removió `verify-email`):

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="io.supabase.flutter" android:host="login-callback" />
    <data android:scheme="io.supabase.flutter" android:host="reset-password" />
</intent-filter>
```

### 3. `lib/core/router/app_links_handler.dart`

Agregar `reset-password` al set `_allowedDeepLinkHosts` y al mapa `_supabaseHostToPath`. Esto los hace válidos para `zeikiUriToPath` y permite que la navegación funcione.

**Nota (post-merge, 2026-08-04):** se removió `verify-email` de ambos sets (whitelist + mapa de traducción).

### 4. `lib/core/router/app_router.dart`

Agregar 1 ruta al enum `AppRoute` y al builder:

- `AppRoute.resetPassword` → `/auth/reset-password`

La ruta es **terminal** (como `/unlock`), no pública. Razón: cuando llega el deep link de reset password, Supabase crea una sesión temporal al procesar el token (necesaria para que `updateUser` funcione en `ResetPasswordScreen`). Si el redirect la tratara como `/login` y la mandara a `/home` con esa sesión temporal, el user nunca vería la pantalla de reset. Decisión técnica: `lib/core/router/app_router.dart:38-53` (bloque de cambios de HDU-007 en la cabecera del archivo).

**Nota (post-merge, 2026-08-04):** se removió `AppRoute.verifyEmail` y la `GoRoute` correspondiente. El enum pasó de 8 a 7 rutas.

### 5. `lib/features/identidad/screens/reset_password_screen.dart` (NUEVO)

Widget con:
- Campo de nueva password (con ojito opcional, ver con Hugo).
- Campo de confirmación de password.
- Botón "Cambiar contraseña".
- Al confirmar, llama a `authService.updateUserPassword(...)` y navega a `/home`.

También agregar la ruta en `_LoginScreenState._onSubmit` (botón "¿Olvidaste tu contraseña?" que llama a `authService.resetPasswordForEmail(...)` y muestra mensaje "Revisa tu correo").

---

## Acceptance Criteria (ACs)

> **Nota (post-merge, 2026-08-04):** los AC1-AC4 (confirmación de email) se removieron del scope. Solo AC5-AC9 siguen siendo el alcance real de esta HDU. El flujo de email confirmation sigue funcionando a nivel Supabase (el user confirma su cuenta), pero NO hay pantalla intermedia de éxito — el user hace click en el link → Supabase confirma → la app abre en /login → el user hace sign in normal.

- [ ] ~~**AC1:** Al registrar con email, Supabase manda email con link `io.supabase.flutter://verify-email/?token=...`.~~ (Removido en cleanup: el link usa el Site URL default del proyecto.)
- [ ] ~~**AC2:** Al hacer click en el link del email en el celular, la app Zeiki abre directamente (no el navegador).~~ (Sigue funcionando, pero el destino es `/login` con sesión temporal, no `/auth/verify-email`.)
- [ ] ~~**AC3:** La app navega a `/auth/verify-email` y muestra mensaje "Cuenta confirmada, ya puedes iniciar sesión".~~ (Removido en cleanup: la pantalla no existe.)
- [ ] ~~**AC4:** Después de confirmar, el user puede hacer sign in normal y entra a `/home`.~~ (Sigue siendo el flujo real, ahora sin pantalla intermedia.)
- [x] **AC5:** En LoginScreen, hay un botón "¿Olvidaste tu contraseña?".
- [x] **AC6:** Al tocar ese botón, se pide el email y se llama a `authService.resetPasswordForEmail(...)`.
- [x] **AC7:** Supabase manda email con link `io.supabase.flutter://reset-password/?token=...`.
- [x] **AC8:** Al hacer click en el link, la app abre en `/auth/reset-password` con la pantalla de nueva password.
- [x] **AC9:** Al confirmar la nueva password, el user queda logueado y va a `/home`.
- [x] **AC10:** `flutter analyze` 0 issues, `flutter test` 214/214 verde (era 220, -6 tests del cleanup), Code Magic CI ✅.
- [x] **AC11:** Hugo valida AC5-AC9 con email de prueba en Xiaomi. AC1-AC4 ya no son scope.
- [x] **AC12:** `docs/runbooks/google-signin-supabase.md` se actualiza con la nota: "Reset password usa deep links `io.supabase.flutter://` — ver `specs/HDU-007-email-callback-flow.md`". (Cleanup: se quitó la mención de verify-email del addendum.)
- [x] **AC13:** NO se commitea `assets/.env` (sigue en `.gitignore`).

---

## Asunciones (a verificar antes de implementar)

- El legacy `seiki_legacy_temp` está clonado en `C:\Users\Pc\Documents\Seiki\seiki_legacy_temp` y accesible. Si no, el implementer debe clonarlo con `gh repo clone navaworkingspaces-collab/seiki_app /tmp/seiki_legacy`.
- Hugo **NO** desactivó la confirmación de email en Supabase (si la desactivó por error durante la prueba del BUG-002 abortado, hay que **reactivarla**: Authentication → Sign In/Up → Email → "Enable email confirmations" = ON). El implementer debe verificar con Hugo antes de empezar.
- `io.supabase.flutter://` es el scheme que usaba el legacy. NO inventamos uno nuevo.
- `AuthChangeEvent.passwordRecovery` existe en `supabase_flutter` actual. Si la API cambió, el implementer debe adaptarse.
- El `onAuthStateChange` de Supabase emite `passwordRecovery` cuando el user llega por deep link (igual que el legacy, líneas 91-97 de `seiki_legacy_temp/lib/main.dart`).

---

## Out of scope

- **Pantalla de "verify email exitoso"** (estuvo en scope original, removida en cleanup del 2026-08-04 — Supabase no emite el evento dedicado).
- App Links con dominio real (sale cuando Zeiki tenga dominio).
- Personalización de templates de email con branding (default de Supabase por ahora).
- Cambio de email estando logueado (signUp cubre solo el flujo de creación).
- 2FA (sale en HDU futura).

---

## Plan de QA (Hugo en Xiaomi 2203129G)

### Antes de empezar
- Verificar con Hugo si la confirmación de email está activada o no en Supabase. Si está desactivada, **reactivarla** antes de probar.

### ~~Para AC1-AC4 (confirmación de email)~~
~~**Removido del scope en cleanup del 2026-08-04.** El flujo sigue funcionando a nivel Supabase (el user confirma), pero NO hay pantalla intermedia de éxito. El user hace click en el link → Supabase confirma → la app abre en /login (o /home si ya tenía sesión) → el user entra.~~

### Para AC5-AC9 (reset password)
1. Sign out si hay sesión.
2. En LoginScreen, tap "¿Olvidaste tu contraseña?".
3. Llenar email (uno que ya exista registrado).
4. Tap "Enviar link".
5. **Verificar:** aparece mensaje "Revisa tu correo".
6. Abrir el email en Gmail.
7. Tap al link de reset.
8. **Verificar:** la app Zeiki abre directamente.
9. La app navega a `/auth/reset-password` con campos de nueva password.
10. Llenar nueva password + confirmación.
11. Tap "Cambiar contraseña".
12. **Verificar:** la app navega a `/home` con la nueva sesión.

### Si falla algo
- Pegar el log y revisar.
- Si el link NO abre la app, verificar el manifest + intent-filter.
- Si Supabase rechaza, verificar la config en dashboard.

---

## Resumen post-fix (lo que se espera al cerrar)

- **Feature de reset password implementada** con knowledge reuse del legacy.
- **Feature de verify-email removida en cleanup** (2026-08-04): el flujo de Supabase sigue funcionando (el link llega a la app y la sesión se crea), pero NO hay pantalla intermedia. El patrón legacy se descarta por innecesario.
- **Workaround BUG-002 revertido** (si se aplicó): "Enable email confirmations" queda ON en Supabase.
- **Sin dominio requerido** — funciona con deep links custom.
- **Flujo de reset password** end-to-end en Xiaomi.
- **Tests automatizados** que cubren el flujo (al menos el `AuthService.resetPasswordForEmail` y la navegación de deep links). 214/214 verde.
- **Cero código defensivo obsoleto** — el comment de `emailNotConfirmed` en `auth_exception.dart` se actualiza para reflejar que AHORA sí se usa.

---

## Cleanup verify-email (2026-08-04)

**Motivación:** Supabase no emite un evento dedicado de "verify email exitoso". Cuando el user hace click en el link del email de confirmación, Supabase confirma la cuenta, crea una sesión temporal (en algunos flujos), y NO hay un hook que diga "el user acaba de confirmar". La pantalla `VerifyEmailScreen` que se diseñó en esta HDU nunca se mostraba en la práctica.

**Decisión de producto (Hugo):** eliminar la pantalla intermedia. El flujo real es: user hace click → Supabase confirma → app abre en /login → user hace sign in normal.

**Cambios del cleanup** (rama `chore/cleanup-verify-email-screen`):
- ❌ Borrado: `lib/features/identidad/screens/verify_email_screen.dart` (74 líneas).
- ❌ `lib/core/router/app_router.dart`: removido `AppRoute.verifyEmail` (enum pasa de 8 a 7), removida la `GoRoute` correspondiente, removida la rama en `computeAuthRedirect`.
- ❌ `lib/core/router/app_links_handler.dart`: removido `verify-email` de `_allowedDeepLinkHosts` y del mapa `_supabaseHostToPath`.
- ❌ `lib/core/auth/auth_service.dart`: removido `emailRedirectTo: io.supabase.flutter://verify-email/` de `signUpWithEmail`. Removido el parámetro `String? emailRedirectTo` del typedef `SignUpWithEmailFn` y del `_defaultSignUpWithEmail`.
- ❌ `android/app/src/main/AndroidManifest.xml`: removido `<data android:scheme="io.supabase.flutter" android:host="verify-email" />` del intent-filter de Supabase.
- ❌ `specs/HDU-007-email-callback-flow.md`: removidas todas las menciones de `VerifyEmailScreen`, `/auth/verify-email` y `verify-email` (este mismo doc).
- ❌ `docs/runbooks/google-signin-supabase.md`: removida la mención de verify-email del addendum de HDU-007.
- ❌ Tests: removidos 6 tests que referenciaban el flujo de verify-email (2 en `redirect_test.dart`, 1 en `app_router_test.dart`, 2 en `app_links_handler_test.dart`, 1 en `auth_service_test.dart`).

**Lo que NO se removió** (sigue útil):
- ✅ `AuthService.resetPasswordForEmail` y `AuthService.updateUserPassword`.
- ✅ `PasswordRecoveryListener` (escucha `passwordRecovery` y navega a `/auth/reset-password`).
- ✅ `ResetPasswordScreen` + su ruta `/auth/reset-password`.
- ✅ `<data android:host="reset-password" />` y `<data android:host="login-callback" />` en el manifest.
- ✅ `emailRedirectTo` en `resetPasswordForEmail` (no en `signUpWithEmail`).

**Verificación:** `flutter analyze` 0 issues, `flutter test` 214/214 verde (era 220, -6 tests del cleanup), `flutter build apk --debug` OK.

---

## Referencias

- Legacy: `C:\Users\Pc\Documents\Seiki\seiki_legacy_temp\`
  - `lib/features/auth/data/datasources/auth_remote_datasource.dart:195` (signUp con emailRedirectTo)
  - `lib/features/auth/data/datasources/auth_remote_datasource.dart:221-226` (resetPasswordForEmail)
  - `lib/main.dart:79-138` (onAuthStateChange con passwordRecovery)
  - `android/app/src/main/AndroidManifest.xml:27-37` (intent-filter con 3 deep links)
- Zeiki: `lib/core/auth/auth_service.dart`, `lib/core/router/app_links_handler.dart`, `lib/core/router/app_router.dart`, `lib/features/identidad/screens/login_screen.dart`, `android/app/src/main/AndroidManifest.xml`.
- Conocimiento: `docs/adr/ADR-009-rewrite-with-knowledge-reuse.md` (la decisión de reescritura con reuse).
- Workaround previo (abortado): `specs/BUG-002-email-confirmation.md` (borrado por Hugo, no se commiteó nada del workaround).
- Cleanup posterior: `docs/current-state.md` (snapshot post-cleanup, 2026-08-04).
