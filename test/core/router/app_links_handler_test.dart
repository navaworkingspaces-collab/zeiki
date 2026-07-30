// Tests del handler de deep links de Zeiki (HDU-004).
//
// Verifica AC5: cuando llega una URI `zeiki://<ruta>` desde Android
// (intent filter), la app navega a `<ruta>`.
//
// La integración real con `app_links` (clase concreta) se hace en
// `main.dart`. Aquí testeamos la LÓGICA de traducción
// `zeiki://<host>` → `/<host>` con un `Stream<Uri>` inyectado, lo que
// nos da cobertura sin depender del plugin nativo (conventions §3:
// fakes > mocks).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zeiki/core/router/app_links_handler.dart';

void main() {
  group('zeikiUriToPath', () {
    test('zeiki://login → /login', () {
      expect(zeikiUriToPath(Uri.parse('zeiki://login')), '/login');
    });

    test('zeiki://home → /home', () {
      expect(zeikiUriToPath(Uri.parse('zeiki://home')), '/home');
    });

    test('zeiki://splash → /splash', () {
      expect(zeikiUriToPath(Uri.parse('zeiki://splash')), '/splash');
    });

    test('zeiki://onboarding → /onboarding', () {
      expect(zeikiUriToPath(Uri.parse('zeiki://onboarding')), '/onboarding');
    });

    test('zeiki:// con host vacío → null (ignorar)', () {
      // Si llega un deep link malformado (sin host), se ignora para
      // que la app no navegue a una ruta falsa.
      expect(zeikiUriToPath(Uri.parse('zeiki://')), isNull);
    });

    test('https://... → null (ignorar, no es esquema zeiki)', () {
      expect(zeikiUriToPath(Uri.parse('https://example.com/home')), isNull);
    });
  });

  group('wireDeepLinks', () {
    late GoRouter router;

    setUp(() {
      // Router mínimo solo para el test. No necesitamos las 4 rutas
      // reales — basta con una que verifique que se llamó a `go(...)`.
      router = GoRouter(
        initialLocation: '/start',
        routes: <RouteBase>[
          GoRoute(
            path: '/start',
            builder: (_, __) => const _StubScreen('start'),
          ),
          GoRoute(
            path: '/login',
            builder: (_, __) => const _StubScreen('login'),
          ),
          GoRoute(
            path: '/home',
            builder: (_, __) => const _StubScreen('home'),
          ),
        ],
      );
    });

    tearDown(() {
      router.dispose();
    });

    testWidgets('navigates when zeiki://<host> arrives', (tester) async {
      final controller = StreamController<Uri>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );

      wireDeepLinks(router, controller.stream);
      // Permite que el `listen` se asiente.
      await tester.pump();

      controller.add(Uri.parse('zeiki://login'));
      await tester.pumpAndSettle();

      // El router ahora debe estar en /login.
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    });

    testWidgets('ignores URIs that are not zeiki://', (tester) async {
      final controller = StreamController<Uri>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );

      wireDeepLinks(router, controller.stream);
      await tester.pump();

      // Una URI de otro scheme (ej. https) no debe navegar.
      controller.add(Uri.parse('https://example.com/home'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/start');
    });
  });
}

class _StubScreen extends StatelessWidget {
  const _StubScreen(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text('stub-$label');
  }
}
