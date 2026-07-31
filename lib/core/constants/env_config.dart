// Configuración de entorno de Zeiki (conventions §10: "una sola fuente
// de verdad por configuración"). El `EnvConfig` se construye leyendo
// del `.env` y se inyecta a los servicios que lo necesiten.
//
// Política: si una variable requerida falta, FALLA RÁPIDO. No se
// defaultean valores — defaults silenciosos = "funciona con valores
// incorrectos", y eso siempre termina en incidente (spec HDU-002 §Plan
// técnico, paso 9).
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Representa la configuración del entorno activo de la app.
///
/// Se construye una vez en `main()` con [EnvConfig.fromDotEnv] y se
/// pasa explícitamente a quien la necesite (testeable, sin globales).
class EnvConfig {
  const EnvConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.appEnv,
    required this.debugLogs,
    required this.googleWebClientId,
  });

  /// URL del proyecto Supabase. **No es un secreto** — va en el APK
  /// desempaquetado. Por convención de Supabase es pública.
  final String supabaseUrl;

  /// Clave anónima de Supabase. **No es un secreto** — el cliente la
  /// usa para autenticar operaciones permitidas por RLS. La
  /// `service_role_key` NUNCA debe llegar al cliente (conventions §6).
  final String supabaseAnonKey;

  /// Entorno lógico: `development` | `staging` | `production`. Usado
  /// para que ciertas features cambien de comportamiento según el
  /// ambiente (ej. logs de debug, endpoints).
  final String appEnv;

  /// Si está activo, los servicios de logging emiten a `debugPrint` y
  /// a la consola. En producción esto debería ser `false`.
  final bool debugLogs;

  /// Web OAuth Client ID de Google (formato: `xxxxx.apps.googleusercontent.com`).
  /// Requerido por el `google_sign_in` plugin para pedir el `idToken` al
  /// servidor de Google (BUG-001, HDU-005). Es el **Web** client (no el
  /// Android), porque el `idToken` lo emite el backend de Google, no el
  /// cliente Android. **No es un secreto** — es un identificador público.
  /// Ver `docs/runbooks/google-signin-supabase.md` para cómo obtenerlo.
  final String googleWebClientId;

  /// Construye el [EnvConfig] leyendo de un [DotEnv] ya cargado. Falla
  /// rápido con `ArgumentError` si una variable requerida está vacía o
  /// no existe. Las variables opcionales (con default) se defaultean
  /// explícitamente — no son secretas.
  factory EnvConfig.fromDotEnv(DotEnv dotenv) {
    final supabaseUrl = _readRequired(dotenv, 'SUPABASE_URL');
    final supabaseAnonKey = _readRequired(dotenv, 'SUPABASE_ANON_KEY');
    final googleWebClientId = _readRequired(dotenv, 'GOOGLE_WEB_CLIENT_ID');
    final appEnv = dotenv.maybeGet('APP_ENV') ?? 'development';
    final debugLogsRaw = dotenv.maybeGet('DEBUG_LOGS') ?? 'false';

    return EnvConfig(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      appEnv: appEnv,
      debugLogs: debugLogsRaw.toLowerCase() == 'true',
      googleWebClientId: googleWebClientId,
    );
  }

  static String _readRequired(DotEnv dotenv, String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw ArgumentError(
        'Missing required env var "$key". '
        'Check that assets/.env exists and has the value. '
        'See docs/runbooks/secrets.md.',
      );
    }
    return value;
  }
}
