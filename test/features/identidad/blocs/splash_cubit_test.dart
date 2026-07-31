// Tests del `SplashCubit` (HDU-006, AC12 + AC13).
//
// El Cubit es una máquina de estados pura que NO depende de Flutter
// (no monta widgets, no usa AnimationController). Por eso se testea
// con `test` puro (no `testWidgets`).
//
// **Estados cubiertos:**
//   - `SplashLoading`: estado inicial. La animación de entrada está
//     corriendo en el widget.
//   - `SplashReady`: la animación de entrada terminó. El widget está
//     a punto de iniciar el fade-out.
//   - `SplashHidden`: el fade-out terminó. El widget debe navegar a
//     la ruta real (`/home` o `/login`, lo que el redirect decida).
//
// **Stream de animaciones expuesto (AC12):** el Cubit expone un
// `Stream<double>` para que los tests (y posibles suscriptores) puedan
// observar el progreso de la animación de entrada sin tocar el widget
// tree. El widget escribe al stream con `setAnimationProgress(value)`
// en su `AnimationController.addListener`.
import 'package:flutter_test/flutter_test.dart';

import 'package:zeiki/features/identidad/blocs/splash_cubit.dart';

void main() {
  group('SplashCubit — estado inicial (AC12, AC13)', () {
    test('estado inicial es SplashLoading', () {
      final cubit = SplashCubit();
      addTearDown(cubit.close);
      expect(cubit.state, isA<SplashLoading>());
    });
  });

  group('SplashCubit — transiciones de estado', () {
    test('markReady() transiciona de SplashLoading a SplashReady', () {
      final cubit = SplashCubit();
      addTearDown(cubit.close);

      expect(cubit.state, isA<SplashLoading>());
      cubit.markReady();
      expect(cubit.state, isA<SplashReady>());
    });

    test('markHidden() transiciona de SplashLoading directo a SplashHidden',
        () {
      // Caso "feature flag OFF": el splash salta la animación de
      // entrada y va directo a fade-out + nav.
      final cubit = SplashCubit();
      addTearDown(cubit.close);

      cubit.markHidden();
      expect(cubit.state, isA<SplashHidden>());
    });

    test('markHidden() desde SplashReady también termina en SplashHidden',
        () {
      // Caso normal: el splash termina la entrada, está en ready, y
      // luego del fade-out emite hidden.
      final cubit = SplashCubit();
      addTearDown(cubit.close);

      cubit.markReady();
      expect(cubit.state, isA<SplashReady>());

      cubit.markHidden();
      expect(cubit.state, isA<SplashHidden>());
    });
  });

  group('SplashCubit — stream de animación (AC12)', () {
    test('expose un Stream<double> broadcast que recibe valores', () async {
      final cubit = SplashCubit();
      addTearDown(cubit.close);

      final received = <double>[];
      final sub = cubit.animationProgress.listen(received.add);

      cubit.setAnimationProgress(0.0);
      cubit.setAnimationProgress(0.5);
      cubit.setAnimationProgress(1.0);

      // El StreamController es broadcast + async: dejamos yield.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(received, <double>[0.0, 0.5, 1.0]);
    });

    test(
        'múltiples listeners pueden suscribirse al stream '
        '(broadcast, no single-subscription)', () {
      // El widget puede tener un listener y un test puede tener otro
      // al mismo tiempo. Si el stream fuera single-subscription, el
      // segundo `listen` lanzaría.
      final cubit = SplashCubit();
      addTearDown(cubit.close);

      final sub1 = cubit.animationProgress.listen((_) {});
      final sub2 = cubit.animationProgress.listen((_) {});
      addTearDown(sub1.cancel);
      addTearDown(sub2.cancel);

      // Sin throw.
    });
  });

  group('SplashCubit — close()', () {
    test('cierra el StreamController sin lanzar', () {
      final cubit = SplashCubit();
      expect(cubit.close, returnsNormally);
    });

    test('close() es idempotente (HDU-005b, lección: double dispose no '
        'rompe)', () {
      final cubit = SplashCubit();
      cubit.close();
      // Segunda llamada no debe lanzar `Bad state: Cannot close a
      // closed StreamController`.
      expect(cubit.close, returnsNormally);
    });

    test('después de close(), setAnimationProgress no lanza', () {
      // Patrón de guards de HDU-003 (race condition con dispose durante
      // async). Si el widget escribe al stream post-close, NO debe
      // romper la app.
      final cubit = SplashCubit();
      cubit.close();
      expect(() => cubit.setAnimationProgress(0.5), returnsNormally);
    });
  });

  group('SplashState — sealed', () {
    test('SplashLoading == SplashLoading (Equatable)', () {
      // Importante para que el BlocBuilder no reconstruya si el estado
      // no cambió. Las subclases extienden Equatable.
      expect(const SplashLoading(), equals(const SplashLoading()));
    });

    test('SplashReady == SplashReady', () {
      expect(const SplashReady(), equals(const SplashReady()));
    });

    test('SplashHidden == SplashHidden', () {
      expect(const SplashHidden(), equals(const SplashHidden()));
    });
  });
}
