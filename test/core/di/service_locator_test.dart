// Tests del `service_locator.dart` (ADR-005).
//
// Criticidad: media. El service locator es el "puente" entre el código
// de feature y los singletons lazy. Si alguien borra el registro de un
// servicio, la app crashea al primer `getIt<T>()` con `GetIt: ... is
// not registered`.
//
// Servicios registrados (HDU-001 → HDU-005):
//   - `TierService` (HDU-003).
//   - `AuthService` (HDU-005, AC2).
//   - `GoogleSignInHandler` (HDU-005).
//   - `GoRouter` (HDU-005, AC23 — Decisión A del review de HDU-004).
//
// Por qué este test existe:
//
//   1. **Regresión contra "olvidé registrar X".** Si alguien borra un
//      `registerLazySingleton` en `service_locator.dart`, este test
//      falla inmediatamente en CI.
//
//   2. **Idempotencia.** `setupServiceLocator()` debe poderse llamar
//      múltiples veces sin lanzar (lo usan los integration tests con
//      `getIt.reset()` + re-registro entre casos). Sin idempotencia,
//      el segundo `registerLazySingleton` lanza `Already registered`.
//
//   3. **`getIt.reset()` limpia el registro.** Verificar que después
//      de `reset()`, los singletons YA NO están registrados.
//
// Patrón: fakes solo donde tiene sentido. Aquí no se necesita fake
// de los servicios — verificamos que `setupServiceLocator` REGISTRA
// las clases, no que funcionen (eso lo cubren los tests específicos).
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:zeiki/core/auth/auth_service.dart';
import 'package:zeiki/core/auth/google_sign_in_handler.dart';
import 'package:zeiki/core/di/service_locator.dart';
import 'package:zeiki/core/tiers/tier_service.dart';

void main() {
  // Reset entre tests. `service_locator` usa la instancia global de
  // `getIt`; sin reset, los registros de un test contaminan al siguiente.
  tearDown(() async {
    await getIt.reset();
  });

  group('setupServiceLocator()', () {
    test('registra TierService en GetIt (regression HDU-003)', () {
      // Antes de llamar setupServiceLocator, NO debe estar registrado
      // (el tearDown del test anterior hizo reset).
      expect(getIt.isRegistered<TierService>(), isFalse,
          reason: 'asumimos estado limpio (tearDown del test anterior)');

      setupServiceLocator();

      // Después de llamar, SÍ está registrado.
      expect(getIt.isRegistered<TierService>(), isTrue,
          reason: 'TierService debe estar registrado en GetIt después '
              'de setupServiceLocator() — sin esto, TierService.getInstance() '
              'lanza "is not registered"');
    });

    test('registra AuthService en GetIt (regression HDU-005, AC2)', () {
      // Pre-condición: GoRouter y AuthService NO registrados.
      expect(getIt.isRegistered<AuthService>(), isFalse);
      expect(getIt.isRegistered<GoogleSignInHandler>(), isFalse);

      setupServiceLocator();

      expect(getIt.isRegistered<AuthService>(), isTrue,
          reason: 'AuthService debe estar registrado en GetIt (HDU-005 AC2)');
      expect(getIt.isRegistered<GoogleSignInHandler>(), isTrue,
          reason: 'GoogleSignInHandler debe estar registrado (lo usa '
              'AuthService internamente)');
    });

    test('registra GoRouter en GetIt (regression HDU-005, AC23)', () {
      expect(getIt.isRegistered<GoRouter>(), isFalse,
          reason: 'antes de setupServiceLocator, GoRouter NO debe estar '
              'registrado (asumimos estado limpio)');

      setupServiceLocator();

      expect(getIt.isRegistered<GoRouter>(), isTrue,
          reason: 'GoRouter debe estar registrado en GetIt (HDU-005 AC23 — '
              'Decisión A del review de HDU-004). Sin esto, main.dart no '
              'puede obtener el router con getIt<GoRouter>()');
    });

    test('es idempotente: llamarlo 2 veces NO lanza (lo usan los '
        'integration tests entre casos)', () {
      setupServiceLocator();
      // El segundo call NO debe lanzar "already registered".
      expect(setupServiceLocator, returnsNormally,
          reason: 'setupServiceLocator debe ser idempotente: chequea '
              'isRegistered antes de registrar. Los integration tests '
              'confían en esto para hacer reset + re-registro entre tests');
    });

    test('después de getIt.reset(), ningún servicio queda registrado',
        () async {
      setupServiceLocator();
      expect(getIt.isRegistered<TierService>(), isTrue);
      expect(getIt.isRegistered<AuthService>(), isTrue);
      expect(getIt.isRegistered<GoRouter>(), isTrue);

      // `getIt.reset()` es async. Sin `await`, el assert de abajo
      // corre antes de que el reset termine y falla con un falso
      // positivo.
      await getIt.reset();

      expect(getIt.isRegistered<TierService>(), isFalse,
          reason: 'reset() debe limpiar TODOS los registros');
      expect(getIt.isRegistered<AuthService>(), isFalse,
          reason: 'reset() debe limpiar AuthService también');
      expect(getIt.isRegistered<GoRouter>(), isFalse,
          reason: 'reset() debe limpiar GoRouter también');
    });

    test('TierService.getInstance() devuelve el singleton registrado', () {
      // Esto es el path que usan los integration tests y main.dart.
      // Si falla, la causa #1 es que setupServiceLocator() no se llamó.
      setupServiceLocator();

      final service = TierService.getInstance();

      expect(service, isA<TierService>(),
          reason: 'getInstance() debe devolver una instancia de TierService');
    });
  });
}
