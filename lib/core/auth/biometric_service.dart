// Servicio de biometría de Zeiki (HDU-005b, AC1-AC4).
//
// `BiometricService` es la **única** puerta de entrada al sistema de
// biometría para los features. Envuelve `local_auth` (huella/cara del
// SO) y `flutter_secure_storage` (flag `biometric_enabled` por
// usuario), y expone la API del AC1:
//
//   - `isBiometricAvailable()` → ¿el dispositivo tiene biometría
//     configurada en el SO?
//   - `authenticate(reason)` → dispara el popup del SO.
//   - `setBiometricEnabled(bool, userId: ...)` → persiste el flag.
//   - `isBiometricEnabled(userId: ...)` → lee el flag (con cache).
//
// **Regla arquitectónica (Target §6):** los features consumen este
// servicio desde GetIt, NUNCA `local_auth` o `flutter_secure_storage`
// directamente. Esto permite:
//   - Cambiar el plugin de biometría sin tocar features.
//   - Inyectar fakes en tests sin mockito (conventions §3).
//   - Centralizar el manejo de errores en un solo lugar.
//
// **KEY por usuario (AC3):** el flag se guarda como
// `biometric_enabled_<userId>`. Si dos personas comparten el
// dispositivo, cada una tiene su flag independiente. El userId
// SIEMPRE es obligatorio — sin él, no se puede leer/escribir nada
// (defensa: si un caller olvida el userId, falla con `ArgumentError`
// en vez de guardar bajo una key global silenciosa).
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart' as la;

// ====================================================================
// Funciones inyectables (mismo patrón que el resto del proyecto)
// ====================================================================

/// Función que envuelve `LocalAuthentication.canCheckBiometrics`.
typedef LocalAuthCanCheckFn = Future<bool> Function();

/// Función que envuelve `LocalAuthentication.getAvailableBiometrics`.
typedef LocalAuthGetAvailableFn = Future<List<la.BiometricType>> Function();

/// Función que envuelve `LocalAuthentication.authenticate`. Recibe
/// el `localizedReason` (mensaje que se muestra al usuario en el
/// popup del SO).
typedef LocalAuthAuthenticateFn = Future<bool> Function(String localizedReason);

class BiometricService {
  BiometricService({
    LocalAuthCanCheckFn? canCheckBiometricsFn,
    LocalAuthGetAvailableFn? getAvailableBiometricsFn,
    LocalAuthAuthenticateFn? authenticateFn,
    FlutterSecureStorage? storage,
  })  : _canCheckBiometricsFn =
            canCheckBiometricsFn ?? _defaultCanCheckBiometrics,
        _getAvailableBiometricsFn =
            getAvailableBiometricsFn ?? _defaultGetAvailableBiometrics,
        _authenticateFn = authenticateFn ?? _defaultAuthenticate,
        _storage = storage ?? const FlutterSecureStorage();

  final LocalAuthCanCheckFn _canCheckBiometricsFn;
  final LocalAuthGetAvailableFn _getAvailableBiometricsFn;
  final LocalAuthAuthenticateFn _authenticateFn;
  final FlutterSecureStorage _storage;

  /// Cache en memoria del flag por userId. Se llena en el primer
  /// `isBiometricEnabled` y se actualiza en cada `setBiometricEnabled`.
  ///
  /// **Por qué existe:** `flutter_secure_storage` es costoso en Android
  /// (Keychain/EncryptedSharedPreferences pasan por JNI). El router
  /// consulta `isBiometricEnabled` en CADA navegación para decidir si
  /// manda a `/unlock` o a `/login`. Sin cache, sería un round-trip a
  /// storage por cada transición. Con cache, solo el primero.
  final Map<String, bool> _cache = <String, bool>{};

  // ====================================================================
  // API pública (AC1)
  // ====================================================================

  /// ¿El dispositivo puede autenticarse con biometría **Y** el usuario
  /// tiene huella/cara registrada en el SO?
  ///
  /// Distingue dos casos que `local_auth` separa:
  ///   - `canCheckBiometrics` → ¿hay hardware? (true en casi todos
  ///     los devices modernos, no significa que el usuario la haya
  ///     configurado).
  ///   - `getAvailableBiometrics()` → ¿el usuario tiene biometría
  ///     REGISTRADA? (lista vacía si la desactivó en el SO).
  ///
  /// Para el popup "¿Activar huella?" necesitamos la segunda: no
  /// tiene caso ofrecer algo que el usuario desactivó.
  Future<bool> isBiometricAvailable() async {
    if (!await _canCheckBiometricsFn()) return false;
    final enrolled = await _getAvailableBiometricsFn();
    return enrolled.isNotEmpty;
  }

  /// Dispara el popup del SO. Devuelve `true` si el usuario pasó
  /// la autenticación, `false` en cualquier otro caso (canceló, no
  /// reconocida, lockout, etc.).
  ///
  /// **Defensa contra excepciones del plugin:** si el plugin lanza
  /// `PlatformException` (ej. `no_fragment_activity` si
  /// `MainActivity` no es `FlutterFragmentActivity`, o
  /// `lockout` por demasiados intentos), lo tratamos como `false`.
  /// La UI siempre puede mostrar fallback a login normal.
  Future<bool> authenticate(String reason) async {
    try {
      return await _authenticateFn(reason);
    } catch (_) {
      return false;
    }
  }

  /// Persiste el flag `biometricEnabled` para un usuario.
  ///
  /// `userId` es **obligatorio**. Si es null o vacío, lanza
  /// `ArgumentError` — defensa contra callers que olvidan el
  /// parámetro y guardarían bajo una key global silenciosa.
  Future<void> setBiometricEnabled(
    bool enabled, {
    required String userId,
  }) async {
    if (userId.isEmpty) {
      throw ArgumentError(
        'userId es obligatorio para setBiometricEnabled. '
        'Si se omite, el flag se guardaría con KEY vacía y se '
        'compartiría entre todos los usuarios del dispositivo.',
      );
    }
    final key = _storageKey(userId);
    if (enabled) {
      await _storage.write(key: key, value: 'true');
    } else {
      // Borrar la key es más limpio que guardar 'false' — el getter
      // devuelve false por default cuando la key no existe.
      await _storage.delete(key: key);
    }
    _cache[userId] = enabled;
  }

  /// Lee el flag `biometricEnabled` para un usuario. Usa cache en
  /// memoria después de la primera lectura.
  ///
  /// `userId` es **obligatorio** (mismo argumento que `set`).
  Future<bool> isBiometricEnabled({required String userId}) async {
    if (userId.isEmpty) {
      throw ArgumentError(
        'userId es obligatorio para isBiometricEnabled.',
      );
    }
    // Cache hit: respuesta inmediata, sin round-trip a storage.
    if (_cache.containsKey(userId)) {
      return _cache[userId]!;
    }
    // Cache miss: leer de storage, cachear, devolver.
    final raw = await _storage.read(key: _storageKey(userId));
    final enabled = raw == 'true';
    _cache[userId] = enabled;
    return enabled;
  }

  // ====================================================================
  // Internals
  // ====================================================================

  String _storageKey(String userId) => 'biometric_enabled_$userId';
}

// ====================================================================
// Defaults: pegan a `local_auth` real.
// ====================================================================

Future<bool> _defaultCanCheckBiometrics() async {
  return la.LocalAuthentication().canCheckBiometrics;
}

Future<List<la.BiometricType>> _defaultGetAvailableBiometrics() async {
  return la.LocalAuthentication().getAvailableBiometrics();
}

Future<bool> _defaultAuthenticate(String localizedReason) async {
  return la.LocalAuthentication().authenticate(localizedReason: localizedReason);
}
