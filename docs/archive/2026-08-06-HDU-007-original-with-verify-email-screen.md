# HDU-007 — Flujo de confirmación de email + reset password con deep links

> **Tipo:** feature
> **Prioridad:** alta
> **Estado:** spec en revisión (Hugo aprobó el plan el 2026-08-03)
> **Rama:** `feat/HDU-007-email-callback-flow` (a crear por el implementer)
> **PR objetivo:** #19 o siguiente disponible

---

## Contexto

Hoy en Zeiki, cuando un user se registra con email + password, Supabase manda un email de confirmación. El link del email apunta a `http://localhost:3000` (configuración rota de Supabase) → falla en el celular del user. Resultado: el user queda en un limbo, no puede confirmar ni entrar a la app.

**La app legacy `seiki_app` SÍ tenía esto resuelto** (verificado el 2026-08-03 leyendo el legacy en `C:\Users\Pc\Documents\Seiki\seiki_legacy_temp`). Lo hacía con **deep links custom** (scheme `io.supabase.flutter://`) + intent-filter en el manifest. Sin dominio, sin App Links, sin assetlinks.json.

**Esta HDU replica ese patrón en Zeiki** (knowledge reuse, NO desde cero, según HDU-009).

---

## Cambios

### 1. `lib/core/auth/auth_service.dart`

Agregar `emailRedirectTo` a `signUpWithEmail`:

```dart
Future<AuthResult> signUpWithEmail({
  required String email,
  required String password,
}) async {
  try {
    return await _signUpWithEmailFn(
      email: email,
      password: password,
      emailRedirectTo: 'io.supabase.flutter://verify-email/',
    );
  } catch (e) {
    throw mapSupabaseAuthError(e);
  }
}
```

Y agregar el `emailRedirectTo` al typedef `SignUpWithEmailFn` (línea 48-51) y al `_defaultSignUpWithEmail` (línea 215-222).

### 2. `lib/core/auth/auth_service.dart` — método nuevo

Agregar `resetPasswordForEmail`:

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

### 3. `android/app/src/main/AndroidManifest.xml`

Agregar dentro del `<activity>` (justo después del intent-filter existente), un nuevo intent-filter con 3 `<data>`:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="io.supabase.flutter" android:host="login-callback" />
    <data android:scheme="io.supabase.flutter" android:host="reset-password" />
    <data android:scheme="io.supabase.flutter" android:host="verify-email" />
</intent-filter>
```

### 4. `lib/core/router/app_links_handler.dart`

Agregar `verify-email` y `reset-password` al set `_allowedDeepLinkHosts`. Esto los hace válidos para `zeikiUriToPath` y permite que la navegación funcione.

### 5. `lib/core/router/app_router.dart`

Agregar 2 rutas al enum `AppRoute` y al builder:

- `AppRoute.verifyEmail` → `/auth/verify-email`
- `AppRoute.resetPassword` → `/auth/reset-password`

Ambas rutas son **terminales** (como `/unlock`), no públicas. Razón: cuando llega el deep link de reset password, Supabase crea una sesión temporal al procesar el token (necesaria para que `updateUser` funcione en `ResetPasswordScreen`). Si el redirect las tratara como `/login` y las mandara a `/home` con esa sesión temporal, el user nunca vería la pantalla de reset. Lo mismo aplica a verify-email: el user debe ver el mensaje de éxito ANTES de cualquier redirección (la sesión puede no existir aún, o existir como temporal). Decisión técnica: `lib/core/router/app_router.dart:38-53` (bloque de cambios de HDU-007 en la cabecera del archivo).

### 6. `lib/features/identidad/screens/reset_password_screen.dart` (NUEVO)

Widget con:
- Campo de nueva password (con ojito opcional, ver con Hugo).
- Campo de confirmación de password.
- Botón "Cambiar contraseña".
- Al confirmar, llama a `authService.updateUserPassword(...)` y navega a `/home`.

También agregar la ruta en `_LoginScreenState._onSubmit` (botón "¿Olvidaste tu contraseña?" que llama a `authService.resetPasswordForEmail(...)` y muestra mensaje "Revisa tu correo").

---

## Acceptance Criteria (ACs)

- [ ] **AC1:** Al registrar con email, Supabase manda email con link `io.supabase.flutter://verify-email/?token=...`.
- [ ] **AC2:** Al hacer click en el link del email en el celular, la app Zeiki abre directamente (no el navegador).
- [ ] **AC3:** La app navega a `/auth/verify-email` y muestra mensaje "Cuenta confirmada, ya puedes iniciar sesión".
- [ ] **AC4:** Después de confirmar, el user puede hacer sign in normal y entra a `/home`.
- [ ] **AC5:** En LoginScreen, hay un botón "¿Olvidaste tu contraseña?".
- [ ] **AC6:** Al tocar ese botón, se pide el email y se llama a `authService.resetPasswordForEmail(...)`.
- [ ] **AC7:** Supabase manda email con link `io.supabase.flutter://reset-password/?token=...`.
- [ ] **AC8:** Al hacer click en el link, la app abre en `/auth/reset-password` con la pantalla de nueva password.
- [ ] **AC9:** Al confirmar la nueva password, el user queda logueado y va a `/home`.
- [ ] **AC10:** `flutter analyze` 0 issues, `flutter test` ≥194/194 verde, Code Magic CI ✅.
- [ ] **AC11:** Hugo valida AC1-AC4 con email de prueba en Xiaomi. Valida AC5-AC9 también.
- [ ] **AC12:** `docs/runbooks/google-signin-supabase.md` se actualiza con la nota: "Email confirmation y reset password usan deep links `io.supabase.flutter://` — ver `specs/HDU-007-email-callback-flow.md`".
- [ ] **AC13:** NO se commitea `assets/.env` (sigue en `.gitignore`).

---

## Asunciones (a verificar antes de implementar)

- El legacy `seiki_legacy_temp` está clonado en `C:\Users\Pc\Documents\Seiki\seiki_legacy_temp` y accesible. Si no, el implementer debe clonarlo con `gh repo clone navaworkingspaces-collab/seiki_app /tmp/seiki_legacy`.
- Hugo **NO** desactivó la confirmación de email en Supabase (si la desactivó por error durante la prueba del BUG-002 abortado, hay que **reactivarla**: Authentication → Sign In/Up → Email → "Enable email confirmations" = ON). El implementer debe verificar con Hugo antes de empezar.
- `io.supabase.flutter://` es el scheme que usaba el legacy. NO inventamos uno nuevo.
- `AuthChangeEvent.passwordRecovery` existe en `supabase_flutter` actual. Si la API cambió, el implementer debe adaptarse.
- El `onAuthStateChange` de Supabase emite `passwordRecovery` cuando el user llega por deep link (igual que el legacy, líneas 91-97 de `seiki_legacy_temp/lib/main.dart`).

---

## Out of scope

- App Links con dominio real (sale cuando Zeiki tenga dominio).
- Personalización de templates de email con branding (default de Supabase por ahora).
- Cambio de email estando logueado (signUp cubre solo el flujo de creación).
- 2FA (sale en HDU futura).

---

## Plan de QA (Hugo en Xiaomi 2203129G)

### Antes de empezar
- Verificar con Hugo si la confirmación de email está activada o no en Supabase. Si está desactivada, **reactivarla** antes de probar.

### Para AC1-AC4 (confirmación de email)
1. Desinstalar la app del Xiaomi.
2. Reinstalar el APK más reciente.
3. Tap "No tienes cuenta? Créala".
4. Llenar email NUEVO (ej. `qa-hdu007-confirm-2026-08-03@ejemplo.com`) + password.
5. Tap "Crear cuenta".
6. **Verificar:** la app navega a `/login` (no a /home todavía, porque Supabase requiere confirmación).
7. Abrir el email en Gmail en el Xiaomi.
8. Tap al link de confirmación.
9. **Verificar:** la app Zeiki abre directamente (no Chrome).
10. La app navega a `/auth/verify-email` con mensaje de éxito.
11. Tap "Iniciar sesión".
12. Llenar email + password.
13. **Verificar:** entra a `/home`.

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

- **Feature implementada** con knowledge reuse del legacy.
- **Workaround BUG-002 revertido** (si se aplicó): "Enable email confirmations" queda ON en Supabase.
- **Sin dominio requerido** — funciona con deep links custom.
- **Flujo completo de email** (registro con confirmación + reset de password) end-to-end en Xiaomi.
- **Tests automatizados** que cubren el flujo (al menos el `AuthService.resetPasswordForEmail` y la navegación de deep links).
- **Cero código defensivo obsoleto** — el comment de `emailNotConfirmed` en `auth_exception.dart` se actualiza para reflejar que AHORA sí se usa.

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
