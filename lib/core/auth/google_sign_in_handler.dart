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
  /// Crea un handler. Si no se pasa `signInFn`, usa el plugin real
  /// `google_sign_in` (solo funciona en runtime con device).
  const GoogleSignInHandler({GoogleSignInFn? signInFn})
      : _signInFn = signInFn;

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

  /// Implementación por default usando el plugin real. Separada del
  /// constructor para que `const GoogleSignInHandler()` siga siendo
  /// const cuando se use con `signInFn` inyectada.
  static Future<String?> _defaultSignIn() async {
    final googleSignIn = GoogleSignIn();
    final account = await googleSignIn.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.idToken;
  }
}
