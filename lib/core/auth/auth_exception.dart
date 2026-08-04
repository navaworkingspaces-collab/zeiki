// Excepciones de autenticación (HDU-005, AC7).
//
// Capa: transversal a todos los dominios. Vive en `lib/core/auth/`
// porque auth es cross-cutting (Target §6).
//
// Política (conventions §6, §8):
//   - Mensaje en español, accionable, sin detalles internos.
//   - `kind` permite a la UI tomar decisiones programáticas (ej.
//     mostrar CTA "Recuperar contraseña" si es `emailNotConfirmed`).
//   - `cause` preserva el error original para logging interno; NUNCA
//     se filtra al usuario ni al `toString()`.
//   - NO se loguea información sensible (passwords, tokens) — la capa
//     de logging debe sanitizar el `cause` antes de persistirlo.
library;

/// Categorías de error que `AuthService` puede reportar a la UI.
/// La UI usa `kind` para decidir mensaje, CTA y acción.
/// NO incluye `userCancelled` porque en ese caso NO se lanza excepción
/// (el handler de Google devuelve `null` y la UI no muestra nada).
enum AuthErrorKind {
  /// El correo ya tiene cuenta. La UI sugiere iniciar sesión.
  emailAlreadyInUse,

  /// La contraseña es muy débil. La UI pide reintentar con más chars.
  weakPassword,

  /// Email/password no coinciden. La UI sugiere reintentar.
  invalidCredentials,

  /// El correo existe pero no se ha confirmado. La UI sugiere reenviar
  /// el correo de confirmación.
  ///
  /// **HDU-007 (cambio de scope):** antes era código defensivo sin
  /// uso real (BUG-002 lo había abortado). Con HDU-007, el flujo de
  /// confirmación de email + deep link custom está implementado, así
  /// que este `kind` **sí se usa**: cuando un user intenta hacer
  /// signIn sin haber confirmado el email, Supabase rechaza con
  /// "Email not confirmed", el mapper lo clasifica como
  /// `emailNotConfirmed`, y la UI muestra el mensaje
  /// "Necesitas confirmar tu correo antes de iniciar sesión."
  emailNotConfirmed,

  /// Red caída o timeout. La UI sugiere "revisa tu conexión".
  networkError,

  /// No se pudo categorizar. La UI muestra mensaje genérico.
  /// El `cause` siempre se preserva para diagnóstico.
  unknown,
}

/// Excepción de dominio para errores de autenticación.
///
/// Mensaje: español, accionable, sin detalles internos (conventions §6).
/// `kind`: tipo programático para que la UI reaccione.
/// `cause`: error original (para logging), NUNCA se muestra al usuario.
class AuthException implements Exception {
  const AuthException({
    required this.kind,
    required this.message,
    this.cause,
  });

  final AuthErrorKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => 'AuthException($kind): $message';
}

/// Mapea un error crudo de Supabase Auth a un `AuthException` con
/// mensaje en español. La heurística es por string-matching sobre
/// los mensajes en inglés que Supabase emite.
///
/// Esta función existe porque `supabase_flutter` lanza `AuthException`
/// propia con mensajes en inglés. Centralizar el mapeo aquí evita que
/// cada feature tenga su propia tabla de strings mágicos.
///
/// Casos cubiertos:
///   - "User already registered" → `emailAlreadyInUse`
///   - "Password should be at least..." → `weakPassword`
///   - "Invalid login credentials" → `invalidCredentials`
///   - "Email not confirmed" → `emailNotConfirmed`
///   - "SocketException" / "Failed host lookup" / "ClientException" /
///     "TimeoutException" → `networkError`
///   - Resto → `unknown` con `cause` preservado.
///
/// Si en el futuro Supabase cambia los strings, se ajusta aquí y los
/// tests del archivo `auth_exception_test.dart` se actualizan.
AuthException mapSupabaseAuthError(Object error) {
  final raw = error.toString().toLowerCase();

  // Errores de red primero: dart:io lanza `SocketException`,
  // `http` lanza `ClientException`, `dart:async` lanza `TimeoutException`.
  // Detectamos por string para no importar `dart:io` aquí (mantiene el
  // archivo testeable sin binding nativo).
  if (raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('clientexception') ||
      raw.contains('timeoutexception') ||
      raw.contains('network is unreachable') ||
      raw.contains('no address associated with hostname')) {
    return AuthException(
      kind: AuthErrorKind.networkError,
      message: 'Revisa tu conexión a internet e intenta de nuevo.',
      cause: error,
    );
  }

  if (raw.contains('already registered') || raw.contains('user already')) {
    return AuthException(
      kind: AuthErrorKind.emailAlreadyInUse,
      message: 'Este correo ya está registrado. Intenta iniciar sesión.',
      cause: error,
    );
  }
  if (raw.contains('password') &&
      (raw.contains('weak') ||
          raw.contains('short') ||
          raw.contains('at least'))) {
    return AuthException(
      kind: AuthErrorKind.weakPassword,
      message: 'La contraseña es muy débil. Usa al menos 8 caracteres.',
      cause: error,
    );
  }
  if (raw.contains('invalid') &&
      (raw.contains('credentials') || raw.contains('login'))) {
    return AuthException(
      kind: AuthErrorKind.invalidCredentials,
      message: 'Correo o contraseña incorrectos.',
      cause: error,
    );
  }
  if (raw.contains('email not confirmed')) {
    return AuthException(
      kind: AuthErrorKind.emailNotConfirmed,
      message: 'Necesitas confirmar tu correo antes de iniciar sesión.',
      cause: error,
    );
  }

  return AuthException(
    kind: AuthErrorKind.unknown,
    message: 'Algo salió mal. Intenta de nuevo.',
    cause: error,
  );
}
