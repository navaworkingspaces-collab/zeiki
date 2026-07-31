// Tests de `InactivityMonitor` y `InactivityTimer` (HDU-005b, AC17-AC21, AC26).
//
// Hay 2 unidades testeables:
//   1. `InactivityTimer` — clase pura con `start() / reset() / dispose()`
//      que arma un `Timer` con el `Duration` configurado y llama al
//      callback al expirar. Se testea con `fake_async` (control total
//      del tiempo) — sin esperar 5 minutos reales.
//   2. `InactivityMonitor` — el widget que envuelve la app, detecta
//      pointer events / scrolls y llama a `InactivityTimer.reset()`
//      en cada uno. Se testea con `testWidgets` + un `TimerFactory`
//      inyectable (no necesitamos controlar el tiempo, solo verificar
//      que se invoca el factory = un reset ocurrió).
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zeiki/core/auth/auth_service_config.dart';
import 'package:zeiki/core/auth/inactivity_monitor.dart';

/// Timer factory fake que NO se ejecuta (5 horas) y cuenta cuántas
/// veces se invocó = cuántos resets se pidieron.
class _CountingTimerFactory {
  int calls = 0;
  final List<Timer> created = <Timer>[];

  Timer build(Duration d, void Function() cb) {
    calls++;
    final t = Timer(const Duration(hours: 5), () {});
    created.add(t);
    return t;
  }

  void disposeAll() {
    for (final t in created) {
      t.cancel();
    }
  }
}

/// Timer factory que solo devuelve un `Timer` que nunca se va a
/// ejecutar (sin contar). Usado cuando no nos importa la cantidad.
Timer _noOpTimerFactory(Duration d, void Function() _) {
  return Timer(const Duration(hours: 5), () {});
}

void main() {
  // ====================================================================
  // Tests de InactivityTimer (clase pura, fakeAsync)
  // ====================================================================

  group('InactivityTimer (clase pura, AC17-AC21, AC26)', () {
    test('start() arma el timer; sin reset, el callback se llama al '
        'cumplirse el timeout', () {
      fakeAsync((async) {
        var signOutCalls = 0;
        final timer = InactivityTimer(
          config: const AuthServiceConfig(
            inactivityTimeout: Duration(milliseconds: 100),
          ),
          onTimeout: () => signOutCalls++,
        );
        addTearDown(timer.dispose);

        timer.start();

        // Antes del timeout: callback NO se ha llamado.
        async.elapse(const Duration(milliseconds: 50));
        expect(signOutCalls, 0, reason: 'todavía no llega al timeout');

        // Después del timeout: callback se llamó.
        async.elapse(const Duration(milliseconds: 60));
        expect(signOutCalls, 1, reason: 'cumplido el timeout sin '
            'interacción → auto-logout');
      });
    });

    test('reset() antes del timeout cancela el timer original; sin más '
        'resets, el callback se llama al cumplirse el nuevo timeout',
        () {
      fakeAsync((async) {
        var signOutCalls = 0;
        final timer = InactivityTimer(
          config: const AuthServiceConfig(
            inactivityTimeout: Duration(milliseconds: 100),
          ),
          onTimeout: () => signOutCalls++,
        );
        addTearDown(timer.dispose);

        timer.start();

        // Reset a los 50ms (mitad del timeout original).
        async.elapse(const Duration(milliseconds: 50));
        timer.reset();

        // A los 100ms del inicio NO se debe haber llamado (el original
        // se canceló; el nuevo empieza desde 0).
        async.elapse(const Duration(milliseconds: 50));
        expect(signOutCalls, 0,
            reason: 'reset a la mitad canceló el timer original');

        // A los 150ms del inicio (= 100ms del reset) SÍ se llama.
        async.elapse(const Duration(milliseconds: 60));
        expect(signOutCalls, 1,
            reason: 'el nuevo timer vence 100ms después del reset');
      });
    });

    test('reset() repetido mantiene el timer "vivo" indefinidamente '
        '(AC17: cualquier interacción resetea)', () {
      fakeAsync((async) {
        var signOutCalls = 0;
        final timer = InactivityTimer(
          config: const AuthServiceConfig(
            inactivityTimeout: Duration(milliseconds: 100),
          ),
          onTimeout: () => signOutCalls++,
        );
        addTearDown(timer.dispose);

        timer.start();

        // 5 resets consecutivos, cada uno a < 100ms del anterior.
        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(milliseconds: 80));
          timer.reset();
        }
        // Total elapsed: 5 * 80 = 400ms. Pero cada reset cancela el
        // timer anterior, así que el callback NUNCA se debió llamar.
        async.elapse(const Duration(milliseconds: 50));
        expect(signOutCalls, 0,
            reason: '5 resets consecutivos = el timer nunca vence');

        // Si dejo de hacer reset, SÍ se llama.
        async.elapse(const Duration(milliseconds: 60));
        expect(signOutCalls, 1);
      });
    });

    test('dispose() cancela el timer; el callback NO se llama aunque '
        'se cumpla el timeout', () {
      fakeAsync((async) {
        var signOutCalls = 0;
        final timer = InactivityTimer(
          config: const AuthServiceConfig(
            inactivityTimeout: Duration(milliseconds: 100),
          ),
          onTimeout: () => signOutCalls++,
        );

        timer.start();
        timer.dispose();

        async.elapse(const Duration(milliseconds: 200));
        expect(signOutCalls, 0,
            reason: 'dispose() cancela el timer — el callback NO se '
                'dispara aunque haya pasado el timeout');
      });
    });

    test('dispose() es idempotente: llamarlo 2 veces no lanza', () {
      fakeAsync((async) {
        final timer = InactivityTimer(
          config: const AuthServiceConfig(
            inactivityTimeout: Duration(milliseconds: 100),
          ),
          onTimeout: () {},
        );
        timer.start();
        timer.dispose();
        // Segundo dispose: no debe lanzar.
        expect(timer.dispose, returnsNormally,
            reason: 'dispose idempotente — el widget se puede '
                'desmontar/remontar sin errores (AC20)');
      });
    });

    test('reset() después de dispose() no hace nada (defensa)', () {
      // Patrón de HDU-003/004: los guards "isClosed" antes de cada
      // operación son obligatorios, no opcionales.
      fakeAsync((async) {
        var signOutCalls = 0;
        final timer = InactivityTimer(
          config: const AuthServiceConfig(
            inactivityTimeout: Duration(milliseconds: 100),
          ),
          onTimeout: () => signOutCalls++,
        );
        timer.start();
        timer.dispose();
        timer.reset(); // defensa: no debe armar un nuevo timer

        async.elapse(const Duration(milliseconds: 200));
        expect(signOutCalls, 0,
            reason: 'reset() post-dispose es no-op (no arma un '
                'nuevo timer)');
      });
    });
  });

  // ====================================================================
  // Tests de InactivityMonitor (widget)
  // ====================================================================

  group('InactivityMonitor (widget, AC17-AC20)', () {
    testWidgets('tap en el child → arma un nuevo timer (reset efectivo) '
        '(AC17: cualquier interacción resetea)', (tester) async {
      final factory = _CountingTimerFactory();
      addTearDown(factory.disposeAll);

      var signOutCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: InactivityMonitor(
            config: const AuthServiceConfig(
              inactivityTimeout: Duration(seconds: 1),
            ),
            signOutFn: () async => signOutCalls++,
            timerFactory: factory.build,
            child: const _TapTarget(),
          ),
        ),
      );

      // start() arma el primer timer.
      expect(factory.calls, 1, reason: 'initState() llama a start() = 1 timer');

      await tester.tap(find.byType(_TapTarget));
      await tester.pump();
      expect(factory.calls, 2,
          reason: 'un tap en el child llama a reset() = 1 timer más');

      await tester.tap(find.byType(_TapTarget));
      await tester.pump();
      expect(factory.calls, 3, reason: 'otro tap = otro reset()');

      // signOutFn NO se debió llamar (los taps resetean antes del
      // timeout de 5 horas del factory fake).
      expect(signOutCalls, 0);
    });

    testWidgets('renderiza el child sin tocarlo → no se rompe', (tester) async {
      // El widget existe, no requiere interacción, y el child se ve.
      await tester.pumpWidget(
        MaterialApp(
          home: InactivityMonitor(
            config: const AuthServiceConfig(
              inactivityTimeout: Duration(seconds: 1),
            ),
            signOutFn: () async {},
            timerFactory: _noOpTimerFactory,
            child: const Text('Zeiki'),
          ),
        ),
      );

      expect(find.text('Zeiki'), findsOneWidget,
          reason: 'el child del monitor se renderiza sin alterarse');
    });

    testWidgets('dispose del monitor cancela el timer (AC20)', (tester) async {
      // Reemplazamos el widget con un Container vacío (sin monitor).
      // El InactivityMonitor anterior debe haber ejecutado su dispose().
      await tester.pumpWidget(
        MaterialApp(
          home: InactivityMonitor(
            config: const AuthServiceConfig(
              inactivityTimeout: Duration(seconds: 1),
            ),
            signOutFn: () async {},
            timerFactory: _noOpTimerFactory,
            child: const Text('con monitor'),
          ),
        ),
      );

      // Reemplazamos con algo SIN monitor.
      await tester.pumpWidget(
        const MaterialApp(home: Text('sin monitor')),
      );
      // Si el dispose no se llamó, el timer queda colgado (no es
      // verificable directamente en este test, pero el pump no debe
      // lanzar excepciones).
      expect(find.text('sin monitor'), findsOneWidget);
    });
  });
}

/// Widget simple con un `onTap` que sirve como target para los tests.
class _TapTarget extends StatelessWidget {
  const _TapTarget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () {},
        child: const SizedBox(
          width: 200,
          height: 200,
          child: ColoredBox(color: Color(0xFF000000)),
        ),
      ),
    );
  }
}
