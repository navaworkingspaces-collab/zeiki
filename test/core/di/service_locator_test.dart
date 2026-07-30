// Tests del `service_locator.dart` (ADR-005).
//
// Criticidad: media. El service locator es el "puente" entre el código
// de feature y los singletons lazy (hoy solo `TierService`). Si alguien
// borra el registro de `TierService`, la app crashea al primer
// `TierService.getInstance()` con `GetIt: ... is not registered`.
//
// Por qué este test existe:
//
//   1. **Regresión contra "olvidé registrar TierService".** Si alguien
//      borra el `registerLazySingleton` en `service_locator.dart`, este
//      test falla inmediatamente en CI (sin necesidad de correr los
//      integration tests en el Xiaomi).
//
//   2. **Idempotencia.** `setupServiceLocator()` debe poderse llamar
//      múltiples veces sin lanzar (lo usan los integration tests con
//      `getIt.reset()` + re-registro entre casos). Sin idempotencia,
//      el segundo `registerLazySingleton` lanza `Already registered`.
//
//   3. **`getIt.reset()` limpia el registro.** Verificar que después
//      de `reset()`, el singleton YA NO está registrado (por eso el
//      setup del integration test hace `reset` + `setupServiceLocator`
//      entre tests).
//
// Patrón: fakes solo donde tiene sentido. Aquí no se necesita fake de
// `TierService` — verificamos que `setupServiceLocator` REGISTRA la
// clase, no que el `TierService` funcione (eso lo cubren los tests de
// `tier_service_test.dart`).
import 'package:flutter_test/flutter_test.dart';

import 'package:zeiki/core/di/service_locator.dart';
import 'package:zeiki/core/tiers/tier_service.dart';

void main() {
  // Reset entre tests. `service_locator` usa la instancia global de
  // `getIt`; sin reset, los registros de un test contaminan al siguiente.
  tearDown(() {
    getIt.reset();
  });

  group('setupServiceLocator()', () {
    test('registra TierService en GetIt (regression)', () {
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

    test('es idempotente: llamarlo 2 veces NO lanza (lo usan los '
        'integration tests entre casos)', () {
      setupServiceLocator();
      // El segundo call NO debe lanzar "already registered".
      expect(setupServiceLocator, returnsNormally,
          reason: 'setupServiceLocator debe ser idempotente: chequea '
              'isRegistered antes de registrar. Los integration tests '
              'confían en esto para hacer reset + re-registro entre tests');
    });

    test('después de getIt.reset(), TierService ya NO está registrado', () async {
      setupServiceLocator();
      expect(getIt.isRegistered<TierService>(), isTrue);

      // `getIt.reset()` es async (devuelve `Future<void>`). Si lo
      // llamamos sin `await`, el assert de abajo corre antes de que
      // el reset termine y falla con un falso positivo. Esto es un
      // bug clásico de los tests de GetIt.
      await getIt.reset();

      expect(getIt.isRegistered<TierService>(), isFalse,
          reason: 'reset() debe limpiar TODOS los registros para que el '
              'siguiente test arranque con GetIt vacío');
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
