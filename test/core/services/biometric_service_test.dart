// Tests de `BiometricService` (HDU-005b, AC1-AC4, AC25).
//
// `BiometricService` envuelve `local_auth` (huella/cara del SO) y
// `flutter_secure_storage` (flag `biometric_enabled` por usuario) y
// expone la API del AC1:
//
//   - `isBiometricAvailable()` → ¿el dispositivo tiene biometría
//     configurada en el SO? (no es lo mismo que "¿hay hardware?").
//   - `authenticate(reason)` → dispara el popup del SO y devuelve
//     `true` si el usuario pasó.
//   - `setBiometricEnabled(bool, userId: ...)` → persiste el flag.
//   - `isBiometricEnabled(userId: ...)` → lee el flag (con cache).
//
// **Patrón: fakes (no `mockito`, conventions §3).** Las funciones de
// `local_auth` se inyectan vía typedefs; el `FlutterSecureStorage`
// se inyecta por instancia y se sustituye por un `MemoryStorage`
// (fake in-memory) en los tests. Cero `build_runner`.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart' as la;

import 'package:zeiki/core/services/biometric_service.dart';

// ====================================================================
// Fakes (top-level para que Dart 3.x parsee bien)
// ====================================================================

/// Fake de `FlutterSecureStorage` in-memory. Replica el contrato
/// mínimo: `read` / `write` / `delete` / `containsKey` / `deleteAll`.
///
/// **Por qué no `MockPlatform`:** los tests que cubren múltiples
/// reads/writes/keys se vuelven más legibles con un `Map<String,String>`
/// explícito que con `when().thenAnswer()`.
class _MemoryStorage implements FlutterSecureStorage {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store.containsKey(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.clear();
  }

  // Métodos no usados en estos tests — lanzan para detectar uso
  // accidental.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_MemoryStorage no implementa ${invocation.memberName}. '
      'Agrégalo si el código bajo test lo necesita.',
    );
  }
}

/// Estado de los fakes de `local_auth`. Configurable por test.
class _LocalAuthStubs {
  bool canCheckBiometricsResult = true;
  List<la.BiometricType> availableBiometricsResult = const <la.BiometricType>[
    la.BiometricType.fingerprint,
  ];
  bool authenticateResult = true;
  Object? authenticateError;
  int authenticateCalls = 0;
  String? authenticateLastReason;

  Future<bool> canCheckBiometrics() async => canCheckBiometricsResult;

  Future<List<la.BiometricType>> getAvailableBiometrics() async =>
      availableBiometricsResult;

  Future<bool> authenticate(String localizedReason) async {
    authenticateCalls++;
    authenticateLastReason = localizedReason;
    if (authenticateError != null) throw authenticateError!;
    return authenticateResult;
  }
}

void main() {
  late _MemoryStorage storage;
  late _LocalAuthStubs localAuth;
  late BiometricService service;

  setUp(() {
    storage = _MemoryStorage();
    localAuth = _LocalAuthStubs();
    service = BiometricService(
      canCheckBiometricsFn: localAuth.canCheckBiometrics,
      getAvailableBiometricsFn: localAuth.getAvailableBiometrics,
      authenticateFn: localAuth.authenticate,
      storage: storage,
    );
  });

  // ====================================================================
  // isBiometricAvailable (AC4)
  // ====================================================================

  group('isBiometricAvailable (AC4)', () {
    test('hardware OK + huella registrada → true', () async {
      localAuth.canCheckBiometricsResult = true;
      localAuth.availableBiometricsResult = const <la.BiometricType>[
        la.BiometricType.fingerprint,
      ];

      expect(await service.isBiometricAvailable(), isTrue,
          reason: 'con hardware + huella registrada, está disponible');
    });

    test('hardware OK pero sin biometría registrada en el SO → false', () async {
      // AC4: "Si el dispositivo no tiene biometría configurada
      // (huella/cara deshabilitadas en el SO), isBiometricAvailable()
      // devuelve false y la app NO ofrece el popup de activación."
      localAuth.canCheckBiometricsResult = true;
      localAuth.availableBiometricsResult = const <la.BiometricType>[];

      expect(await service.isBiometricAvailable(), isFalse,
          reason: 'el usuario desactivó la huella después de activar en '
              'Zeiki — el popup NO debe aparecer');
    });

    test('hardware NO soporta biometría → false', () async {
      localAuth.canCheckBiometricsResult = false;
      localAuth.availableBiometricsResult = const <la.BiometricType>[
        la.BiometricType.fingerprint,
      ];

      expect(await service.isBiometricAvailable(), isFalse,
          reason: 'sin hardware, no tiene caso ofrecer el popup');
    });
  });

  // ====================================================================
  // authenticate (AC1)
  // ====================================================================

  group('authenticate (AC1)', () {
    test('huella válida → true', () async {
      localAuth.authenticateResult = true;
      localAuth.authenticateError = null;

      final result = await service.authenticate('Desbloquear Zeiki');

      expect(result, isTrue);
      expect(localAuth.authenticateCalls, 1);
      expect(localAuth.authenticateLastReason, 'Desbloquear Zeiki');
    });

    test('huella cancelada o no reconocida → false', () async {
      localAuth.authenticateResult = false;
      localAuth.authenticateError = null;

      final result = await service.authenticate('Desbloquear Zeiki');

      expect(result, isFalse,
          reason: 'el plugin devuelve false cuando el usuario cancela '
              'o no reconoce la huella');
    });

    test('PlatformException del plugin → false (defensa, no propagación)',
        () async {
      // El plugin lanza PlatformException en algunos casos edge (ej.
      // lockout, no_fragment_activity). El service NO debe propagar
      // la excepción cruda — la UI trata `false` como "no se pudo".
      localAuth.authenticateError = Exception('PlatformException(no_fragment_activity)');

      final result = await service.authenticate('Desbloquear Zeiki');

      expect(result, isFalse,
          reason: 'cualquier excepción del plugin se traduce a false '
              'para que la UI muestre fallback sin crashear');
    });
  });

  // ====================================================================
  // setBiometricEnabled + isBiometricEnabled (AC1, AC3)
  // ====================================================================

  group('setBiometricEnabled + isBiometricEnabled (AC1, AC3)', () {
    test('setBiometricEnabled(true) + isBiometricEnabled round-trip → true',
        () async {
      await service.setBiometricEnabled(true, userId: 'user-A');
      expect(await service.isBiometricEnabled(userId: 'user-A'), isTrue,
          reason: 'el flag se persiste con la KEY por usuario');
    });

    test('setBiometricEnabled(false) + isBiometricEnabled → false', () async {
      // Primero activamos, luego desactivamos.
      await service.setBiometricEnabled(true, userId: 'user-A');
      await service.setBiometricEnabled(false, userId: 'user-A');
      expect(await service.isBiometricEnabled(userId: 'user-A'), isFalse);
    });

    test('isBiometricEnabled sin haber activado antes → false', () async {
      // Sin setBiometricEnabled previo → flag NO existe en storage →
      // devuelve false (default seguro).
      expect(await service.isBiometricEnabled(userId: 'user-fresh'), isFalse);
    });

    test('KEY por usuario: A y B con flags independientes (AC3)', () async {
      await service.setBiometricEnabled(true, userId: 'user-A');
      // user-B no ha activado.

      expect(await service.isBiometricEnabled(userId: 'user-A'), isTrue);
      expect(await service.isBiometricEnabled(userId: 'user-B'), isFalse,
          reason: 'cada usuario tiene su KEY propia '
              '(`biometric_enabled_<userId>`) — HDU-005b AC3');
    });

    test('isBiometricEnabled usa cache en memoria (no lee storage cada vez)',
        () async {
      // Después de un setBiometricEnabled, el cache se llena. Un segundo
      // isBiometricEnabled NO debe volver a leer storage (medimos que
      // la operación es síncrona con el cache).
      await service.setBiometricEnabled(true, userId: 'user-A');
      // Limpiamos el storage manualmente — el cache sigue "sabiendo".
      await storage.delete(key: 'biometric_enabled_user-A');

      expect(await service.isBiometricEnabled(userId: 'user-A'), isTrue,
          reason: 'el cache en memoria evita lecturas redundantes a '
              'secure storage (que es costoso en Android)');
    });

    test('setBiometricEnabled con userId vacío → lanza ArgumentError',
        () async {
      await expectLater(
        () => service.setBiometricEnabled(true, userId: ''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
