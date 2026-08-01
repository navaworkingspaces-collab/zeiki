// Servicio de autenticación de Zeiki (HDU-005, AC1, AC3).
//
// `AuthService` es la **única** puerta de entrada al sistema de auth
// para las features. Envuelve `supabase.auth` y:
//   - Mapea errores de Supabase a `AuthException` con mensajes en
//     español, accionables (conventions §6, §8).
//   - Centraliza el flujo de Google Sign-In (popup del SO → idToken →
//     `signInWithIdToken`).
//   - Expone una API síncrona para el redirect del router
//     (`getCurrentSession()`).
//
// **Regla arquitectónica (Target §6):** los features consumen
// `AuthService` desde GetIt, NUNCA `Supabase.instance.client.auth`
// directamente. Esto permite:
//   - Cambiar de backend sin tocar features.
//   - Inyectar fakes en tests sin mockito (conventions §3).
//   - Centralizar el manejo de errores en un solo lugar.
//
// **Decisión de scope (HDU-005 §Notas):** el stream `authStateChanges`
// se expone pero NO se usa en esta HDU. El redirect del router usa
// `getCurrentSession()` en cada navegación, que es suficiente. El
// stream reactivo se conectará cuando alguna pantalla lo necesite
// (probablemente HDU-005b o HDU-006).
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'auth_exception.dart';
import 'google_sign_in_handler.dart';

/// Resultado de un sign-up o sign-in exitoso. Hoy es un alias de
/// `AuthResponse` (de go_true) para que el código de feature no importe
/// `supabase_flutter` directamente.
typedef AuthResult = sb.AuthResponse;

/// Excepción que se lanza cuando el usuario cancela el popup de Google
/// (AC10). NO es un error: la UI lo captura y no muestra nada.
///
/// Se separa de `AuthException` para que la UI pueda distinguir
/// "canceló" de "falló" sin parsear strings.
class UserCancelledAuthFlow implements Exception {
  const UserCancelledAuthFlow();
  @override
  String toString() => 'UserCancelledAuthFlow';
}

/// Firmas inyectables. Cada una envuelve una llamada a
/// `supabase.auth.<método>`. Se inyectan para que los tests no
/// necesiten un cliente de Supabase real (conventions §3: fakes > mocks).
typedef SignUpWithEmailFn = Future<sb.AuthResponse> Function({
  required String email,
  required String password,
});
typedef SignInWithEmailFn = Future<sb.AuthResponse> Function({
  required String email,
  required String password,
});
typedef SignInWithIdTokenFn = Future<sb.AuthResponse> Function({
  required sb.OAuthProvider provider,
  required String idToken,
  String? accessToken,
  String? nonce,
});
typedef SignOutFn = Future<void> Function();
typedef GetSessionFn = sb.Session? Function();
typedef AuthStateChangeFn = Stream<sb.AuthState> Function();

/// Servicio de autenticación. Se registra en GetIt como singleton lazy
/// (ADR-005). Las features lo consumen con `getIt<AuthService>()`.
///
/// **Constructores:**
///   - `AuthService()` (sin args): usa `Supabase.instance.client.auth`.
///     Es el path de runtime; el `service_locator` lo usa.
///   - `AuthService(...)` con fakes: para tests. Cada parámetro acepta
///     una función inyectable; los que no se pasan usan los defaults
///     de Supabase.
class AuthService {
  AuthService({
    SignUpWithEmailFn? signUpWithEmailFn,
    SignInWithEmailFn? signInWithEmailFn,
    SignInWithIdTokenFn? signInWithIdTokenFn,
    SignOutFn? signOutFn,
    GetSessionFn? getCurrentSessionFn,
    AuthStateChangeFn? authStateChangeFn,
    GoogleSignInHandler? googleSignInHandler,
  })  : _signUpWithEmailFn = signUpWithEmailFn ?? _defaultSignUpWithEmail,
        _signInWithEmailFn = signInWithEmailFn ?? _defaultSignInWithEmail,
        _signInWithIdTokenFn = signInWithIdTokenFn ?? _defaultSignInWithIdToken,
        _signOutFn = signOutFn ?? _defaultSignOut,
        _getCurrentSessionFn =
            getCurrentSessionFn ?? _defaultGetCurrentSession,
        _authStateChangeFn = authStateChangeFn ?? _defaultAuthStateChange,
        _googleSignInHandler = googleSignInHandler;

  final SignUpWithEmailFn _signUpWithEmailFn;
  final SignInWithEmailFn _signInWithEmailFn;
  final SignInWithIdTokenFn _signInWithIdTokenFn;
  final SignOutFn _signOutFn;
  final GetSessionFn _getCurrentSessionFn;
  final AuthStateChangeFn _authStateChangeFn;
  final GoogleSignInHandler? _googleSignInHandler;

  // ====================================================================
  // API pública
  // ====================================================================

  /// Crea una cuenta nueva con email + password. Lanza
  /// `AuthException(emailAlreadyInUse)` si el correo ya está
  /// registrado, `AuthException(weakPassword)` si Supabase rechaza la
  /// contraseña.
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _signUpWithEmailFn(email: email, password: password);
    } catch (e) {
      throw mapSupabaseAuthError(e);
    }
  }

  /// Inicia sesión con email + password. Lanza
  /// `AuthException(invalidCredentials)` si no coinciden.
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _signInWithEmailFn(email: email, password: password);
    } catch (e) {
      throw mapSupabaseAuthError(e);
    }
  }

  /// Dispara el popup de Google y, si el usuario confirma, inicia
  /// sesión con el `idToken` resultante.
  ///
  /// Lanza `UserCancelledAuthFlow` si el usuario canceló el popup
  /// (AC10). Lanza `AuthException` si Supabase rechaza el token.
  Future<AuthResult> signInWithGoogle() async {
    final handler = _googleSignInHandler;
    if (handler == null) {
      // Defensa: si se construyó sin handler (caso de test que no lo
      // necesita), devolver error claro. En runtime, el `service_locator`
      // SIEMPRE registra el handler.
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'Google Sign-In no está configurado.',
      );
    }

    final idToken = await handler.signInAndGetIdToken();
    if (idToken == null) {
      // AC10: cancelar el popup NO es error. La UI lo captura con
      // `on UserCancelledAuthFlow catch (_)` y no muestra nada.
      throw const UserCancelledAuthFlow();
    }

    try {
      return await _signInWithIdTokenFn(
        provider: sb.OAuthProvider.google,
        idToken: idToken,
      );
    } catch (e) {
      throw mapSupabaseAuthError(e);
    }
  }

  /// Cierra la sesión actual. Idempotente (Supabase maneja re-signOut
  /// sin error).
  ///
  /// **También desloguea de Google** (`googleSignIn.signOut()`) si el
  /// handler de Google está presente. Sin esto, el chooser de Google
  /// seguiría "recordando" la cuenta del user después del signOut, y
  /// el siguiente signIn con Google la usaría sin re-pedir credenciales.
  /// El user esperaría que signOut limpie TODO el estado de auth, no
  /// solo la sesión de Supabase.
  ///
  /// El `googleSignIn.signOut()` se ejecuta best-effort: si falla (ej.
  /// Play Services caído), NO bloquea el signOut de Supabase.
  Future<void> signOut() async {
    await _signOutFn();
    // Desloguear de Google también. El handler es opcional (puede ser
    // null en tests que no necesitan Google), por eso el `?.`.
    try {
      await _googleSignInHandler?.signOutAndDisconnect();
    } catch (_) {
      // Best-effort. Si falla, el signOut de Supabase ya cerró la
      // sesión. El user verá /login. La próxima vez que intente
      // Google, Play Services puede que aún recuerde la cuenta —
      // aceptable para un signOut parcial.
    }
  }

  /// Devuelve la sesión activa o `null`. Se llama desde el `redirect`
  /// del router para decidir a dónde mandar al usuario.
  sb.Session? getCurrentSession() => _getCurrentSessionFn();

  /// Devuelve el `id` del usuario actual o `null` si no hay sesión.
  ///
  /// Se usa como KEY por usuario en `flutter_secure_storage` para
  /// que el flag de biometría esté aislado por cuenta (HDU-005b,
  /// AC3). Si dos personas comparten el dispositivo, cada una tiene
  /// su propio flag.
  String? get currentUserId => _getCurrentSessionFn()?.user.id;

  /// Stream de cambios de auth. Se conecta al `GoRouter.refreshListenable`
  /// en `service_locator.dart` (HDU-005b AC22). Cuando el usuario hace
  /// signOut, el stream emite y el router re-evalúa el `redirect`.
  Stream<sb.AuthState> get authStateChanges => _authStateChangeFn();
}

// ====================================================================
// Defaults: pegan a `Supabase.instance.client.auth`.
// ====================================================================

Future<sb.AuthResponse> _defaultSignUpWithEmail({
  required String email,
  required String password,
}) {
  return sb.Supabase.instance.client.auth.signUp(
    email: email,
    password: password,
  );
}

Future<sb.AuthResponse> _defaultSignInWithEmail({
  required String email,
  required String password,
}) {
  return sb.Supabase.instance.client.auth.signInWithPassword(
    email: email,
    password: password,
  );
}

Future<sb.AuthResponse> _defaultSignInWithIdToken({
  required sb.OAuthProvider provider,
  required String idToken,
  String? accessToken,
  String? nonce,
}) {
  return sb.Supabase.instance.client.auth.signInWithIdToken(
    provider: provider,
    idToken: idToken,
    accessToken: accessToken,
    nonce: nonce,
  );
}

Future<void> _defaultSignOut() async {
  await sb.Supabase.instance.client.auth.signOut();
}

sb.Session? _defaultGetCurrentSession() {
  return sb.Supabase.instance.client.auth.currentSession;
}

Stream<sb.AuthState> _defaultAuthStateChange() {
  return sb.Supabase.instance.client.auth.onAuthStateChange;
}
