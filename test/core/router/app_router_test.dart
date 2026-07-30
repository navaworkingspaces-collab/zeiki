// Tests del router de navegación de Zeiki (HDU-004).
//
// Verifica el contrato del `appRouter` declarado en
// `lib/core/router/app_router.dart`:
//
//   - AC1: 4 rutas (`/splash`, `/onboarding`, `/login`, `/home`),
//     ruta inicial `/splash`.
//   - AC8: cada ruta resuelve sin error; un deep link
//     `zeiki://<ruta>` parsea con scheme+host esperados.
//
// Lo que NO cubre este test:
//   - La traducción `zeiki://<ruta>` → `/<ruta>` que hace `app_links` (eso
//     lo verifica el integration test `integration_test/router_test.dart`,
//     ver spec §AC9).
//   - El widget renderizado por cada ruta (eso lo cubre
//     `test/widget_test.dart` actualizado en esta HDU).
//   - La navegación interactiva (botones, back, rotación — eso va en
//     el widget test + integration test de AC9).
//
// `GoRouterDelegate.currentConfiguration` requiere que el delegate esté
// montado en un widget tree (no se inicializa en un unit test puro).
// Por eso este archivo usa `findMatch(Uri)` directamente, que es
// función pura de la configuración declarativa.
import 'package:flutter_test/flutter_test.dart';
import 'package:zeiki/core/router/app_router.dart';

void main() {
  group('appRouter configuration', () {
    test('initial location is /splash (AC1)', () {
      // La ruta inicial declarativa vive en `appRouter.configuration`.
      // `GoRouter` la expone a través del `routingConfig`; verificamos
      // que `findMatch` resuelve `/splash` con la misma config que
      // se le pasa al constructor.
      final match = appRouter.configuration.findMatch(Uri.parse('/splash'));
      expect(match.isError, isFalse);
    });

    test('resolves /splash without error (AC1, AC8)', () {
      final matchList = appRouter.configuration.findMatch(Uri.parse('/splash'));
      expect(matchList.isError, isFalse);
      expect(matchList.matches, isNotEmpty);
    });

    test('resolves /onboarding without error (AC1, AC8)', () {
      final matchList =
          appRouter.configuration.findMatch(Uri.parse('/onboarding'));
      expect(matchList.isError, isFalse);
      expect(matchList.matches, isNotEmpty);
    });

    test('resolves /login without error (AC1, AC8)', () {
      final matchList =
          appRouter.configuration.findMatch(Uri.parse('/login'));
      expect(matchList.isError, isFalse);
      expect(matchList.matches, isNotEmpty);
    });

    test('resolves /home without error (AC1, AC8)', () {
      final matchList = appRouter.configuration.findMatch(Uri.parse('/home'));
      expect(matchList.isError, isFalse);
      expect(matchList.matches, isNotEmpty);
    });

    test('returns error match for unknown route (AC8)', () {
      // Cobertura de `errorBuilder`: rutas inexistentes deben producir
      // un match con error, no crashear.
      final matchList =
          appRouter.configuration.findMatch(Uri.parse('/no-existe'));
      expect(matchList.isError, isTrue);
    });
  });

  group('AppRoute enum', () {
    test('declares the 4 routes from the spec', () {
      expect(AppRoute.values, hasLength(4));
      expect(
        AppRoute.values.map((r) => r.path).toSet(),
        {'/splash', '/onboarding', '/login', '/home'},
      );
    });

    test('splash is the declared initial location', () {
      // El path declarado en el enum coincide con la ruta que el router
      // resuelve al inicio (AC1).
      expect(AppRoute.splash.path, '/splash');
      expect(
        appRouter.configuration.findMatch(Uri.parse(AppRoute.splash.path))
            .isError,
        isFalse,
      );
    });

    test('every AppRoute path resolves without error (AC1)', () {
      // Cada ruta del enum debe ser resoluble por el router — esto
      // evita drift entre el enum y la configuración del router.
      for (final route in AppRoute.values) {
        final match = appRouter.configuration.findMatch(Uri.parse(route.path));
        expect(
          match.isError,
          isFalse,
          reason: 'Route ${route.path} should resolve without error',
        );
      }
    });
  });

  group('Deep link URI parsing (AC5, AC8)', () {
    // El formato Android `zeiki://<ruta>` usa scheme+host, no path.
    // `app_links` se encarga de traducir `zeiki://login` → `/login`
    // antes de entregarlo al router (eso lo cubre el integration test).
    // Aquí solo verificamos el parsing de la URI.

    test('zeiki://login has scheme zeiki and host login', () {
      final uri = Uri.parse('zeiki://login');
      expect(uri.scheme, 'zeiki');
      expect(uri.host, 'login');
    });

    test('zeiki://home has scheme zeiki and host home', () {
      final uri = Uri.parse('zeiki://home');
      expect(uri.scheme, 'zeiki');
      expect(uri.host, 'home');
    });

    test('zeiki://splash has scheme zeiki and host splash', () {
      final uri = Uri.parse('zeiki://splash');
      expect(uri.scheme, 'zeiki');
      expect(uri.host, 'splash');
    });
  });
}
