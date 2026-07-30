// Unit tests del `TierService` (spec HDU-003 AC2-AC6).
//
// Criticidad: alta (matriz §11 de Target Architecture). Afecta TODA la
// UI (cualquier feature puede preguntar `has()`). Por eso cubrimos:
//
//   - Comportamiento fail-safe del cache frío.
//   - Refresh exitoso actualiza el cache.
//   - Refresh fallido conserva el cache anterior.
//   - Override de debug tiene prioridad (cuando está habilitado).
//   - El stream `changes` emite solo en cambios reales.
//   - `dispose()` no crashea.
//
// Patrón de tests: fakes (no `mockito`, conventions §3). El
// `FeatureFlagsFetcher` se inyecta por constructor y devuelve un mapa
// controlado por test. No necesitamos `build_runner` ni code gen.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:zeiki/core/di/service_locator.dart';
import 'package:zeiki/core/tiers/app_feature.dart';
import 'package:zeiki/core/tiers/tier_change.dart';
import 'package:zeiki/core/tiers/tier_service.dart';
import 'package:zeiki/core/tiers/tier_service_config.dart';

void main() {
  // Reset GetIt entre tests. Sin esto, el singleton lazy conserva el
  // estado entre tests y los fakes se pisan.
  tearDown(() {
    if (getIt.isRegistered<TierService>()) {
      getIt<TierService>().dispose();
    }
    getIt.reset();
  });

  /// Construye un `TierService` con un fetcher y config inyectados.
  /// **NO** llama `initialize()` — eso lo decide cada test. Razón:
  /// para los tests del stream `changes` necesitamos suscribirnos
  /// ANTES del primer refresh, así que el helper no debe hacer el
  /// refresh por su cuenta.
  ///
  /// Los tests que necesitan config deben llamar `await
  /// service.initialize(config: ...)` explícitamente (igual que en
  /// `main.dart`).
  TierService makeService({
    required Future<Map<String, dynamic>> Function() fetcher,
  }) {
    getIt.registerLazySingleton<TierService>(
      () => TierService(fetcher: fetcher),
    );
    return getIt<TierService>();
  }

  /// Fetcher fake: **devuelve una función** (no un Future) para que el
  /// test pueda decidir cuándo se llama. Si pasara el Future, se
  /// ejecutaría una sola vez al construir el test y no se podría
  /// cambiar entre refreshes.
  Future<Map<String, dynamic>> Function() fakeFetcher({
    Map<String, dynamic>? returns,
    Exception? throws,
  }) {
    return () async {
      if (throws != null) throw throws;
      return returns ?? const <String, dynamic>{};
    };
  }

  group('has() — comportamiento del cache', () {
    test('con cache frío devuelve `false` (fail-safe AC4)', () {
      final service = makeService(fetcher: fakeFetcher());

      // El cache está vacío. Un feature desconocido devuelve `false`
      // en vez de tirar. Esto evita que la UI asuma `true` por default
      // antes de que el primer refresh llegue.
      expect(service.has(AppFeature.splash), isFalse);
    });

    test('después de un refresh exitoso, devuelve el valor de la edge function',
        () async {
      final service = makeService(
        fetcher: fakeFetcher(returns: {'flags': {'splash': true}}),
      );
      await service.refresh();

      expect(service.has(AppFeature.splash), isTrue);
    });

    test('después de un refresh que devuelve `false`, has() devuelve `false`',
        () async {
      final service = makeService(
        fetcher: fakeFetcher(returns: {'flags': {'splash': false}}),
      );
      await service.refresh();

      expect(service.has(AppFeature.splash), isFalse);
    });

    test('después de un refresh fallido, conserva el valor anterior (AC5)',
        () async {
      var shouldThrow = false;
      final service = makeService(
        fetcher: () async {
          if (shouldThrow) throw const FormatException('network down');
          return {'flags': {'splash': true}};
        },
      );

      // Primer refresh: éxito → cache tiene `splash=true`.
      await service.refresh();
      expect(service.has(AppFeature.splash), isTrue);

      // Segundo refresh: la red se cae → el cache debe conservarse.
      shouldThrow = true;
      await service.refresh();
      expect(service.has(AppFeature.splash), isTrue,
          reason: 'el cache debe sobrevivir a un refresh fallido');
    });
  });

  group('has() — override de debug (AC6)', () {
    test('override tiene prioridad sobre el cache cuando debugEnabled=true',
        () async {
      final service = makeService(
        fetcher: fakeFetcher(returns: {'flags': {'splash': true}}),
      );
      await service.initialize(
        config: const TierServiceConfig(
          debugEnabled: true,
          debugOverrides: {AppFeature.splash: false},
        ),
      );
      await service.refresh();

      // Aunque la edge function dice `true`, el override de debug
      // fuerza `false`. Sirve para QA: probar "qué pasa si splash
      // estuviera deshabilitado".
      expect(service.has(AppFeature.splash), isFalse);
    });

    test('override NO se aplica cuando debugEnabled=false', () async {
      final service = makeService(
        fetcher: fakeFetcher(returns: {'flags': {'splash': true}}),
      );
      await service.initialize(
        config: const TierServiceConfig(
          debugEnabled: false,
          debugOverrides: {AppFeature.splash: false},
        ),
      );
      await service.refresh();

      // debugEnabled=false → el override se ignora → cache manda.
      expect(service.has(AppFeature.splash), isTrue);
    });

    test('override se aplica incluso cuando el feature no está en el cache',
        () async {
      // Cache frío + override activo → el override manda.
      final service = makeService(fetcher: fakeFetcher());
      await service.initialize(
        config: const TierServiceConfig(
          debugEnabled: true,
          debugOverrides: {AppFeature.splash: true},
        ),
      );

      expect(service.has(AppFeature.splash), isTrue);
    });
  });

  group('refresh() — resilencia', () {
    test('si el fetcher lanza, refresh() completa sin propagar la excepción',
        () async {
      final service = makeService(
        fetcher: fakeFetcher(throws: const FormatException('network down')),
      );

      // AC5: NO romper la UI. refresh() no debe lanzar.
      await expectLater(service.refresh(), completes);
    });

    test('ignora features desconocidas en la respuesta (no rompe)', () async {
      final service = makeService(
        fetcher: fakeFetcher(returns: {
          'flags': {
            'splash': true,
            'feature_que_no_existe_en_el_enum': true,
          },
        }),
      );
      await service.refresh();

      // La feature desconocida se ignora silenciosamente. Solo las
      // features del enum se cachean.
      expect(service.has(AppFeature.splash), isTrue);
    });

    test('si la respuesta no tiene la clave "flags", conserva el cache anterior',
        () async {
      var firstCall = true;
      final service = makeService(
        fetcher: () async {
          if (firstCall) {
            firstCall = false;
            return {'flags': {'splash': true}};
          }
          // Segundo call: respuesta malformada.
          return {'sin_flags_key': true};
        },
      );

      await service.refresh();
      expect(service.has(AppFeature.splash), isTrue);

      await service.refresh();
      // El segundo refresh falla el parseo → cache se conserva.
      expect(service.has(AppFeature.splash), isTrue);
    });
  });

  group('stream `changes`', () {
    // Helper: subscribirse al stream ANTES de cualquier refresh para
    // capturar el primer cambio. Cada test arma su propio `changes`
    // y verifica con un `await service.refresh()` o `await
    // service.initialize()` que dispare la emisión.
    Future<List<TierChange>> collectChangesOn(
      Stream<TierChange> stream, {
      required Future<void> Function() trigger,
      Duration settleDelay = const Duration(milliseconds: 10),
    }) async {
      final changes = <TierChange>[];
      final sub = stream.listen(changes.add);
      await trigger();
      await Future<void>.delayed(settleDelay);
      await sub.cancel();
      return changes;
    }

    test('emite cuando un feature cambia de `false` → `true`', () async {
      final service = makeService(
        fetcher: fakeFetcher(returns: {'flags': {'splash': true}}),
      );

      final changes = await collectChangesOn(
        service.changes,
        trigger: () => service.initialize(),
      );

      expect(changes, hasLength(1));
      expect(changes.first.feature, AppFeature.splash);
      expect(changes.first.newValue, isTrue);
      expect(changes.first.source, ChangeSource.remote);
    });

    test('NO emite cuando el valor no cambia', () async {
      final service = makeService(
        fetcher: fakeFetcher(returns: {'flags': {'splash': true}}),
      );

      // Primer initialize: cache vacío → splash=true → emite 1 vez.
      // Segundo refresh: cache splash=true → splash=true → NO emite.
      final changes = await collectChangesOn(
        service.changes,
        trigger: () async {
          await service.initialize();
          await service.refresh();
        },
      );

      expect(changes, hasLength(1),
          reason: 'el segundo refresh no debe emitir porque el valor es el mismo');
    });

    test('emite cuando el valor cambia de `true` → `false`', () async {
      var firstCall = true;
      final service = makeService(
        fetcher: () async {
          if (firstCall) {
            firstCall = false;
            return {'flags': {'splash': true}};
          }
          return {'flags': {'splash': false}};
        },
      );

      final changes = await collectChangesOn(
        service.changes,
        trigger: () async {
          await service.initialize(); // false → true
          await service.refresh();    // true → false
        },
      );

      expect(changes, hasLength(2));
      expect(changes.first.newValue, isTrue);
      expect(changes.last.newValue, isFalse);
    });
  });

  group('dispose()', () {
    test('cierra el stream sin crashear', () {
      final service = makeService(fetcher: fakeFetcher());
      expect(service.dispose, returnsNormally);
    });

    test('es idempotente: llamar dispose() dos veces no lanza', () {
      final service = makeService(fetcher: fakeFetcher());
      service.dispose();
      // Segunda llamada no debe lanzar `StateError: Cannot close a
      // closed StreamController`. Es un guard defensivo: cuesta 1
      // línea y protege contra doble dispose en tearDown encadenados.
      expect(service.dispose, returnsNormally);
    });

    test('después de dispose, el stream está cerrado', () async {
      final service = makeService(fetcher: fakeFetcher());

      // El stream se cierra vía dispose(). El listener recibe `onDone`
      // cuando eso pasa.
      final completer = Completer<void>();
      final sub = service.changes.listen(
        (_) {},
        onDone: completer.complete,
      );

      service.dispose();
      await completer.future.timeout(const Duration(seconds: 1));
      expect(completer.isCompleted, isTrue,
          reason: 'el stream debe cerrar cuando se llama dispose()');
      await sub.cancel();
    });

    test(
        'race condition: dispose() durante refresh() NO lanza '
        '"Cannot add new events after calling close"', () async {
      // Fetcher lento: el test decide cuándo responde. Mientras el
      // fetcher espera, podemos llamar `dispose()` para cerrar el
      // controller. Cuando el fetcher responda, el `refresh()` debe
      // completar sin lanzar.
      final fetcherCompleter = Completer<Map<String, dynamic>>();
      final service = makeService(fetcher: () => fetcherCompleter.future);

      // Disparar el refresh en background (no `await`).
      final refreshFuture = service.refresh();

      // Pequeño yield para que el `refresh()` llegue al `await _fetcher()`
      // y se quede ahí bloqueado. Sin esto, el `fetcher` podría resolverse
      // antes de que llamemos `dispose()` y el test no estaría probando
      // la race condition.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Ahora sí: cerrar el stream mientras el refresh está esperando.
      service.dispose();

      // Completar el fetcher. El refresh va a intentar emitir al
      // controller cerrado — sin el guard, lanza
      // `Bad state: Cannot add new events after calling close`. Con
      // el guard, completa sin lanzar.
      fetcherCompleter.complete({'flags': {'splash': true}});

      // El refresh debe completar sin throw.
      await expectLater(refreshFuture, completes,
          reason: 'refresh() no debe lanzar aunque el controller esté '
              'cerrado (cubierto por el guard `isClosed`)');
    });

    test(
        'race condition: dispose() durante refresh() fallido NO lanza '
        'en el addError', () async {
      // Variante del test anterior: el fetcher lanza (red caída) en vez
      // de devolver éxito. El `refresh()` debe catch + addError. Con el
      // guard, el addError se salta si el controller está cerrado.
      final fetcherCompleter = Completer<Map<String, dynamic>>();
      final service = makeService(fetcher: () => fetcherCompleter.future);

      final refreshFuture = service.refresh();

      await Future<void>.delayed(const Duration(milliseconds: 10));
      service.dispose();

      fetcherCompleter.completeError(
        const FormatException('network down'),
      );

      // Igual: el refresh debe completar sin throw.
      await expectLater(refreshFuture, completes,
          reason: 'refresh() no debe lanzar aunque el addError vaya a '
              'un controller cerrado (cubierto por el guard `isClosed`)');
    });
  });
}
