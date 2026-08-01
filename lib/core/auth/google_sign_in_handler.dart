// Wrapper sobre `google_sign_in` (HDU-005, AC8, AC9, AC10).
//
// Por qué existe:
//   - Aísla el plugin `google_sign_in` del código de feature (conventions
//     §3: "si la dependencia tiene lógica pero no quieres la real, usa
//     un fake"). Los features solo ven una `Future<String?>` (idToken o
//     null si canceló).
//   - Permite tests sin device: la `signInFn` por default se reemplaza
//     con un fake en los tests.
//   - Centraliza el manejo de errores: cualquier excepción cruda del
//     plugin se traduce a `AuthException` con mensaje en español
//     (conventions §6, §8).
//
// Flujo:
//   1. La pantalla llama a `signInAndGetIdToken()`.
//   2. Se dispara el popup del SO (Google Play Services en Android).
//   3a. Si el usuario confirma → devuelve `idToken` (String).
//   3b. Si el usuario cancela → devuelve `null` (AC10: no se hace nada).
//   3c. Si falla → lanza `AuthException(kind: unknown, ...)` con `cause`.
//
// El `AuthService` toma el `idToken` y lo pasa a
// `Supabase.auth.signInWithIdToken(provider: google, idToken: ...)`.
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_exception.dart';

/// Firma de la función que dispara el popup de Google y devuelve el
/// `idToken` (o `null` si el usuario canceló). Se inyecta para tests.
typedef GoogleSignInFn = Future<String?> Function();

class GoogleSignInHandler {
  /// Crea un handler.
  ///
  /// En **tests**, se inyecta `signInFn` (fake) y se usa `const` con
  /// el constructor sin args. El `webClientId` se ignora porque
  /// `_defaultSignIn` no se llama.
  ///
  /// En **runtime**, NO se inyecta `signInFn` y se pasa `webClientId`
  /// (constructor NO-const) con el Web OAuth Client ID. Este ID es
  /// **requerido** por el plugin `google_sign_in` 6.x para pedir el
  /// `idToken` al servidor de Google. Sin él, el popup aparece pero el
  /// `idToken` viene `null` (BUG-001).
  const GoogleSignInHandler({
    this.webClientId,
    GoogleSignInFn? signInFn,
  }) : _signInFn = signInFn;

  /// Web OAuth Client ID de Google (formato
  /// `xxxxx-yyyyy.apps.googleusercontent.com`). Es el **Web** client
  /// (no el Android), porque el `idToken` lo emite el backend de
  /// Google. Se lee de `EnvConfig.googleWebClientId` en el
  /// `service_locator` y se pasa aquí.
  ///
  /// Público (no `_webClientId`) para que el regression test de
  /// BUG-001 pueda verificar que el valor fluye desde `EnvConfig` →
  /// `service_locator` → handler. Es OK exponerlo: NO es un secreto,
  /// es un identificador público de OAuth.
  final String? webClientId;

  final GoogleSignInFn? _signInFn;

  /// Dispara el popup de Google y devuelve el `idToken` del usuario.
  ///
  /// Retorna `null` si el usuario canceló (AC10). Lanza
  /// `AuthException(kind: unknown)` si el popup falló por un motivo
  /// técnico (Play Services caído, etc.).
  Future<String?> signInAndGetIdToken() async {
    try {
      // Si nos inyectaron un fake (tests), úsalo. Si no, crea el
      // plugin real. Crear `GoogleSignIn` es barato; el plugin cachea
      // internamente.
      final idToken = _signInFn != null
          ? await _signInFn()
          : await _defaultSignIn();
      return idToken;
    } on AuthException {
      // Ya viene mapeado. NO envolver otra vez.
      rethrow;
    } catch (e) {
      throw AuthException(
        kind: AuthErrorKind.unknown,
        message: 'No pudimos conectar con Google. Intenta de nuevo.',
        cause: e,
      );
    }
  }

  /// Desloguea de Google (limpia el cache local del plugin Y de Play
  /// Services). Llamado por `AuthService.signOut()` para que el chooser
  /// de Google no "recuerde" la cuenta del user después del signOut.
  ///
  /// El método se llama `signOutAndDisconnect` (no `signOut`) porque
  /// es semánticamente diferente al signOut de Supabase: este limpia
  /// el estado de Google, no el de Supabase. AuthService.signOut()
  /// llama a ambos.
  Future<void> signOutAndDisconnect() async {
    final googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile'],
      serverClientId: webClientId,
    );
    await googleSignIn.signOut();
  }
  /// Implementación por default usando el plugin real.
  ///
  /// BUG-001 fix: el plugin ahora se configura con `serverClientId`
  /// (= web OAuth Client ID) y `scopes: [email, profile]`. Sin
  /// `serverClientId`, el plugin no puede pedir el `idToken` al
  /// servidor de Google y devuelve `null` aunque la autenticación sea
  /// exitosa.
  Future<String?> _defaultSignIn() async {
    final googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile'],
      serverClientId: webClientId,
    );
    final account = await googleSignIn.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.idToken;
  }
}
