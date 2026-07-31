# BUG-001 — Google Sign-In no completa el flujo (selector de cuenta aparece, selección → nada)

**Tipo:** bug
**Prioridad:** alta
**Estado:** pendiente (síntoma confirmado en QA, causa raíz por investigar)
**Fecha de apertura:** 2026-07-31
**Reporter:** Hugo (QA post-HDU-006, Xiaomi 2203129G)
**HDU relacionada que introdujo el bug (o NO si es pre-existente):** HDU-005 (auth básico). El bug existía en HDU-005 pero no fue detectado por los 113/113 tests ni por las 3 rondas de review porque los tests no cubren el flujo real de Google OAuth (mockean el `GoogleSignInHandler`).
**Sistemas externos afectados:** Google Cloud Console (OAuth clients), Supabase Auth (provider), `google_sign_in` 6.x plugin (cliente).

---

## Contexto

Hugo hizo QA en device real (Xiaomi 2203129G) post-HDU-006. La pantalla de login muestra correctamente el botón "Continuar con Google". Al tocarlo, el selector de cuentas de Google (popup del SO) **sí aparece** — eso descarta problemas de SHA-1, `applicationId`, o falta de `google-services.json`. Al seleccionar una cuenta de Google, **no pasa nada**: la app se queda en `/login` sin navegar, sin mostrar error, sin emitir log.

El bug es una regresión latente de HDU-005 que sobrevivió 3 rondas de review porque los tests mockean el `GoogleSignInHandler` (inyectan un `signInFn` que devuelve un idToken hardcodeado) y no ejercen el plugin real.

## Síntoma

- **Trigger:** pantalla `/login`, tap en botón "Continuar con Google".
- **Observado:** popup de Google Play Services aparece con las cuentas disponibles. Al seleccionar una cuenta, el popup se cierra, la app vuelve a `/login`, y **no pasa nada más** (sin navegación, sin snackbar de error, sin mensaje).
- **No observado:** no hay log en consola (`flutter run` no emite nada durante la selección), no hay log en Supabase (no llega request al endpoint de auth), no hay crash.

## Comportamiento esperado

Per HDU-005 AC9: después de seleccionar la cuenta de Google y aceptar, el `AuthService.signInWithGoogle()` completa → `authStateChanges` emite sesión nueva → el `redirect` del router manda a `/home` (con sesión activa, `/home` es terminal — ver `computeAuthRedirect`). La pantalla debería mostrar un indicador de carga durante el flujo (mientras se llama a `signInWithIdToken` de Supabase) y luego desaparecer con la navegación a `/home`.

## Pasos para reproducir

1. Con la app en `main` post-HDU-006 (commit `fe6c669` o posterior) y Xiaomi 2203129G conectado.
2. `flutter run -d 2203129G` (o usar el APK recién instalado).
3. Esperar a que el splash termine → /login aparece.
4. Tocar "Continuar con Google".
5. En el popup del SO, seleccionar una cuenta de Google (cualquiera con sesión iniciada en el device).
6. **Observar:** el popup se cierra, la pantalla de login se queda estática, no hay navegación ni error.

## Ambiente

- **Device:** Xiaomi 2203129G (Android 14 API 34, debug USB activado).
- **OS:** Android 14.
- **App version:** `fe6c669` (post-HDU-006) o posterior.
- **Network:** WiFi (la red del usuario).
- **Estado de sesión:** logged out (es la primera vez que Hugo prueba el flujo de Google Sign-In en este device).
- **Config de Google OAuth (per `docs/runbooks/google-signin-supabase.md`):**
  - OAuth client Android creado en Google Cloud Console con `applicationId = com.zeiki.zeiki` y SHA-1 del cert de debug.
  - OAuth client Web creado y secret copiado.
  - Supabase dashboard: Google provider habilitado con `Client IDs` (Android + Web, comma-separated) y `Client Secret` (Web).
- **App config:** `GoogleSignIn()` instanciado con defaults en `lib/core/auth/google_sign_in_handler.dart:69`. Sin `scopes`, sin `serverClientId`, sin `forceCodeForRefreshToken`.

## Causa probable

Rankeadas por probabilidad. Cada una se valida o descarta en el plan de investigación.

### Hipótesis 1 (más probable): `serverClientId` no está configurado en `GoogleSignIn()`

**Evidencia actual:** `lib/core/auth/google_sign_in_handler.dart:69` instancia `GoogleSignIn()` con todos los defaults. **No setea `serverClientId`.**

**Por qué causa el síntoma:** en Android, el `google_sign_in` plugin necesita el `serverClientId` (que es el **Web OAuth Client ID**, NO el Android) para pedir el `idToken` a Google. Sin él, el popup de selección de cuenta funciona (porque el cliente Android tiene sus propias credenciales), pero `account.authentication.idToken` vuelve `null`. El handler devuelve `null`, el `AuthService` lanza `UserCancelledAuthFlow` (es un "soft cancel" en este caso, no un cancel real del usuario), y la UI lo captura silenciosamente en `lib/features/identidad/screens/login_screen.dart:98-100` (no muestra nada, no navega).

**Cómo verificar:** leer el código del plugin `google_sign_in` 6.x en `~/.pub-cache/hosted/pub.dev/google_sign_in-6.x.x/lib/google_sign_in.dart` o agregar un `debugPrint` del `idToken` y de `account.authentication` antes del return.

### Hipótesis 2: `account.authentication.idToken` es `null` por otra razón (scope, signIn silencioso, etc.)

**Evidencia actual:** sin scopes configurados, el plugin usa defaults (`email` + `profile`) que sí devuelven idToken. Pero si la cuenta no tiene email verificado o el flujo falla por otro motivo, el idToken puede ser `null` aunque el `account` no lo sea.

**Cómo verificar:** agregar `debugPrint('idToken: $idToken, account.email: ${account.email}, account.auth.idToken: ${auth.idToken}, auth.accessToken: ${auth.accessToken}')` antes del return en `google_sign_in_handler.dart:73`.

### Hipótesis 3: `signInWithIdToken` de Supabase falla con error 4xx/5xx y la excepción se mapea a un `UserCancelledAuthFlow` por error

**Evidencia actual:** en `lib/core/auth/auth_service.dart:150-165`, si `idToken == null` se lanza `UserCancelledAuthFlow`. Pero si el idToken NO es null y `signInWithIdToken` falla, se lanza `AuthException` que la UI SÍ muestra con snackbar (`login_screen.dart:101-103`). Como Hugo no ve snackbar, esta hipótesis es **menos probable**.

**Cómo verificar:** reproducir el bug con un `idToken` hardcodeado válido y ver si Supabase responde OK. O agregar `debugPrint` de la excepción en `_signInWithIdTokenFn`.

### Hipótesis 4 (menos probable): redirect URI / SHA-1 mismatch

**Evidencia actual:** si el SHA-1 estuviera mal, el popup de Google no aparecería (Google rechaza la app antes de mostrar el selector). Como Hugo SÍ ve el popup, el SHA-1 está bien. Descartada.

## Plan de investigación

Pasos ordenados. **No empezar a programar fix hasta confirmar la causa raíz.**

1. **Verificar qué devuelve `google_sign_in` realmente.** Agregar `debugPrint` en `lib/core/auth/google_sign_in_handler.dart` antes del return:
   ```dart
   debugPrint('[BUG-001 debug] account.email=${account.email}');
   debugPrint('[BUG-001 debug] auth.idToken=${auth.idToken}');
   debugPrint('[BUG-001 debug] auth.accessToken=${auth.accessToken}');
   debugPrint('[BUG-001 debug] auth.serverAuthCode=${auth.serverAuthCode}');
   ```
   Reproducir el bug con `flutter run -d 2203129G`. Capturar `adb logcat | grep -i 'BUG-001\|flutter\|google'` durante la selección de cuenta.
   - Si `auth.idToken` es `null` pero `account` no → **hipótesis 1 confirmada** (serverClientId falta).
   - Si `auth.idToken` es `null` y `account` también es `null` → flujo del plugin está roto por otra razón.
   - Si `auth.idToken` NO es null → bug en otra capa (verificar logs de Supabase).

2. **Verificar logs de Supabase.** En el dashboard de Supabase → Logs → Auth Logs, filtrar por la hora de la prueba. Ver si llegó un request a `/auth/v1/token?grant_type=id_token` o a `/auth/v1/callback`.
   - Si NO llegó request → bug en el cliente (el idToken nunca se mandó). **Hipótesis 1 o 2.**
   - Si SÍ llegó request con error 4xx → bug en la config de Supabase o en el idToken (formato, audience, etc.).

3. **Verificar config de Google Cloud Console.** Ir a https://console.cloud.google.com/apis/credentials. Ver el OAuth client Android:
   - Package name: ¿`com.zeiki.zeiki`? (el runbook dice `app.zeiki.mobile` — **el runbook está desactualizado**, verificar cuál es el real).
   - SHA-1: ¿coincide con el del cert de debug actual? Regenerar con `keytool -list -v -keystore ~/.android/debug.keystore -storepass android -keypass android | grep SHA1` o `gradlew signingReport` (con el workaround de `-J-Duser.language=en` si Java 25 + Gradle se queja).

4. **Verificar config de Supabase.** Ir a Supabase dashboard → Authentication → Providers → Google:
   - Toggle ON: ¿sí?
   - Client IDs: ¿el del Android OAuth client, o el del Web, o ambos? (per docs de Supabase, debe ser el **Web** client ID para `signInWithIdToken`).
   - Client Secret: ¿es el del Web OAuth client?

5. **Si hipótesis 1 confirmada:** aplicar el fix (ver Plan de fix abajo).

## Plan de fix

Cuando la causa raíz esté confirmada, el fix más probable (basado en hipótesis 1) es agregar `serverClientId` y `scopes` al `GoogleSignIn()` en `lib/core/auth/google_sign_in_handler.dart:69`:

```dart
// lib/core/auth/google_sign_in_handler.dart:69 (propuesto)
final googleSignIn = GoogleSignIn(
  scopes: <String>['email', 'profile'],
  serverClientId: '<WEB_OAUTH_CLIENT_ID>',  // del Google Cloud Console
);
```

Donde `<WEB_OAUTH_CLIENT_ID>` viene de la config (Supabase dashboard → Providers → Google → "Client IDs" → primer valor si es comma-separated, o el Web OAuth client de Google Cloud Console).

**Si la causa raíz es otra** (hipótesis 2, 3, etc.), el fix se ajusta en consecuencia. Se documenta en el spec cuando se confirme.

**Archivos a modificar (estimado):**
- `lib/core/auth/google_sign_in_handler.dart:69` — agregar `scopes` y `serverClientId`.
- `lib/core/di/service_locator.dart:54-58` — el `GoogleSignInHandler` es `const` con un `signInFn` inyectable; si necesitamos que el Web Client ID sea un valor runtime, hay que cambiar el patrón (pasar el ID como parámetro del factory, leerlo de `EnvConfig`).
- `lib/core/constants/env_config.dart` — agregar `googleWebClientId` (viene del `.env` o de Supabase al boot).
- `assets/.env.example` — agregar `GOOGLE_WEB_CLIENT_ID=<placeholder>`.

**Hardcode vs config:** NO hardcodear el Web Client ID en código. Va en `.env` (gitignored) o se consulta al boot de Supabase. Convención: `EnvConfig` ya tiene el patrón.

## Acceptance Criteria (criterio de "listo")

- [ ] **AC1:** reproducir el bug con los pasos de arriba ANTES del fix → debe fallar (síntoma presente). Evidencia: log de `flutter run` + `adb logcat`.
- [ ] **AC2:** causa raíz confirmada y documentada en este spec (sección "Causa probable" actualizada con la hipótesis confirmada).
- [ ] **AC3:** aplicar el fix.
- [ ] **AC4:** reproducir el bug con los mismos pasos DESPUÉS del fix → debe pasar (síntoma ausente, navegación a `/home` ocurre).
- [ ] **AC5:** regression test automatizado. Opciones:
  - (a) Test que verifique que `GoogleSignInHandler.signInAndGetIdToken()` configura `GoogleSignIn` con `serverClientId` y `scopes` correctos (mockear el plugin, inspeccionar el constructor).
  - (b) Test que verifique que cuando el idToken es null, NO se lanza `UserCancelledAuthFlow` (porque eso es un caso de error, no de cancel). Se lanza una `AuthException` accionable.
  - (c) Ambas.
  - El implementer elige la opción que tenga sentido después de confirmar la causa raíz.
- [ ] **AC6:** QA en device real (Xiaomi 2203129G). Hugo confirma: "selecciono cuenta de Google → llego a /home". Sin errores en logcat.
- [ ] **AC7:** suite completa de tests sigue verde (179/179 + nuevos). `flutter analyze` 0 issues.
- [ ] **AC8:** `docs/runbooks/google-signin-supabase.md` actualizado para reflejar:
  - El `applicationId` real (no `app.zeiki.mobile` que está mal).
  - El paso de "agregar `serverClientId` al `GoogleSignIn()` en el código" (con la referencia al archivo).
  - El paso de "agregar `GOOGLE_WEB_CLIENT_ID` al `.env`".
- [ ] **AC9:** `docs/conventions.md` actualizado si surge alguna convención nueva (ej. "los OAuth client IDs NO se hardcodean, van en `.env`").

## Out of scope

- **No refactor del `GoogleSignInHandler` a un patrón más complejo** (ej. `ChangeNotifier` para escuchar cambios de sesión). Eso sale en HDU aparte.
- **No arreglar el bug de "no hay loading indicator durante el flujo de Google"** (UX). El `_isLoading` se setea en `true` al inicio pero el flujo del popup bloquea la UI thread; sale en HDU de UX.
- **No migrar el `signInWithIdToken` a `signInWithOAuth` (PKCE flow).** El `signInWithIdToken` es la integración correcta con `google_sign_in` 6.x; el PKCE flow es para otros casos.
- **No agregar tests E2E del flujo de Google con un browser real** (ej. `integration_test` con OAuth automatizado). Eso es out of scope hasta que haya CI con device farm.
- **No configurar CI para este flujo** (HDU de CI/CD futura).

## QA esperado

Hugo va a verificar en el Xiaomi antes de aprobar el merge:

1. `flutter clean && flutter pub get && flutter run -d 2203129G` desde `main` con la rama `bug/BUG-001-google-signin`.
2. Esperar a que el splash termine → /login aparece.
3. Tocar "Continuar con Google" → popup de Google aparece.
4. Seleccionar cuenta de Google (la que tenga sesión en el device).
5. **Verificar:** snackbar o loading → navegación a `/home` (no se queda colgado en /login).
6. Hacer sign out desde /home.
7. Repetir el flujo de Google Sign-In 2 veces más para confirmar que no es suerte.
8. (Opcional) Probar el flujo de email/password para confirmar que NO se rompió.
9. (Opcional) Capturar `adb logcat | grep -i 'google\|supabase\|flutter'` durante el flujo y confirmar que no hay errores silenciosos.

## Referencias

- `lib/core/auth/google_sign_in_handler.dart` — wrapper del plugin.
- `lib/core/auth/auth_service.dart:138-165` — `signInWithGoogle()`.
- `lib/features/identidad/screens/login_screen.dart:86-104` — `_onGoogle()` (UI que captura el flow).
- `lib/core/di/service_locator.dart:53-58` — registro del `GoogleSignInHandler` en GetIt.
- `docs/runbooks/google-signin-supabase.md` — runbook de config (con typos: dice `app.zeiki.mobile` cuando el real es `com.zeiki.zeiki`).
- HDU-005 spec (`specs/HDU-005-auth-basico.md`) — origen del feature.
- HDU-006 (recién cerrada) — la QA que descubrió este bug.
- Regla memoria #8 (agente) — "Tests verde NO es app funcionando. QA en device real es OBLIGATORIO antes de merge". El bug de Google Sign-In es la evidencia directa de esta regla.
- [google_sign_in plugin 6.x docs](https://pub.dev/packages/google_sign_in) — referencia del plugin. Sección "Android integration" confirma que `serverClientId` es requerido para el `idToken`.
- [Supabase docs: Sign in with Google on Flutter](https://supabase.com/docs/guides/auth/social-login/auth-google?queryGroups=platform&platform=flutter) — flujo de integración.
