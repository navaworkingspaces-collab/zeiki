// Tests del redirect del router (HDU-005, AC24, AC25, AC30).
//
// El redirect decide a dónde va el usuario antes de cada navegación:
//
//   - /splash, /onboarding → siempre accesibles (públicas).
//   - /login, /register   → accesibles solo si NO hay sesión; si la
//                            hay, redirige a /home (no tiene sentido
//                            ver login si ya estás dentro).
//   - /home (y cualquier futura privada) → accesible solo si HAY
//                                            sesión; si no, a /login.
//
// La lógica se aísla en `computeAuthRedirect({goingTo, isLoggedIn})`
// para poder testearla sin montar un widget tree (conventions §3:
// unit test > widget test cuando el comportamiento es puro).
import 'package:flutter_test/flutter_test.dart';

import 'package:zeiki/core/router/app_router.dart';

void main() {
  group('computeAuthRedirect', () {
    group('rutas públicas (splash, onboarding)', () {
      test('splash sin sesión → no redirige', () {
        expect(
          computeAuthRedirect(goingTo: '/splash', isLoggedIn: false),
          isNull,
        );
      });

      test('splash con sesión → no redirige (es público siempre)', () {
        // Aunque haya sesión, el splash debe poder mostrarse
        // (cold start → decidir a dónde ir). Por eso nunca redirige.
        expect(
          computeAuthRedirect(goingTo: '/splash', isLoggedIn: true),
          isNull,
        );
      });

      test('onboarding sin sesión → no redirige', () {
        expect(
          computeAuthRedirect(goingTo: '/onboarding', isLoggedIn: false),
          isNull,
        );
      });

      test('onboarding con sesión → no redirige', () {
        expect(
          computeAuthRedirect(goingTo: '/onboarding', isLoggedIn: true),
          isNull,
        );
      });
    });

    group('rutas de auth (login, register)', () {
      test('login sin sesión → no redirige (se queda en /login)', () {
        expect(
          computeAuthRedirect(goingTo: '/login', isLoggedIn: false),
          isNull,
        );
      });

      test('login con sesión → redirige a /home', () {
        // Ya estás dentro, no tiene sentido ver el login.
        expect(
          computeAuthRedirect(goingTo: '/login', isLoggedIn: true),
          '/home',
        );
      });

      test('register sin sesión → no redirige (puede registrarse)', () {
        expect(
          computeAuthRedirect(goingTo: '/register', isLoggedIn: false),
          isNull,
        );
      });

      test('register con sesión → redirige a /home', () {
        expect(
          computeAuthRedirect(goingTo: '/register', isLoggedIn: true),
          '/home',
        );
      });
    });

    group('rutas privadas (home y futuras)', () {
      test('home sin sesión → redirige a /login', () {
        expect(
          computeAuthRedirect(goingTo: '/home', isLoggedIn: false),
          '/login',
        );
      });

      test('home con sesión → no redirige (se queda en /home)', () {
        expect(
          computeAuthRedirect(goingTo: '/home', isLoggedIn: true),
          isNull,
        );
      });

      test('cualquier ruta privada futura (ej. /fiscal) sin sesión → '
          'redirige a /login', () {
        // El redirect aplica a CUALQUIER ruta que no sea pública ni de
        // auth. Esto cubre la regla "home o cualquier ruta privada
        // futura" del AC24 sin tener que listar todas las rutas.
        expect(
          computeAuthRedirect(goingTo: '/fiscal', isLoggedIn: false),
          '/login',
        );
      });

      test('cualquier ruta privada futura con sesión → no redirige', () {
        expect(
          computeAuthRedirect(goingTo: '/fiscal', isLoggedIn: true),
          isNull,
        );
      });
    });

    group('no hay loops infinitos (regression)', () {
      // El riesgo #4 del spec: si la lógica siempre redirige a /login
      // y /login redirige a /home, se genera un loop. El diseño
      // actual lo evita porque /login sin sesión NO redirige.

      test('login sin sesión es terminal (no redirige)', () {
        // 1ra pasada: /login, sin sesión → null. El router se queda.
        // 2da pasada: nunca se llama (porque no redirigió).
        expect(
          computeAuthRedirect(goingTo: '/login', isLoggedIn: false),
          isNull,
        );
      });

      test('home con sesión es terminal (no redirige)', () {
        expect(
          computeAuthRedirect(goingTo: '/home', isLoggedIn: true),
          isNull,
        );
      });
    });
  });

  group('AppRoute enum (HDU-005 agregó /register)', () {
    test('declara 5 rutas: splash, onboarding, login, register, home', () {
      // Antes eran 4 (HDU-004). Se agregó /register en HDU-005 (AC4).
      expect(AppRoute.values, hasLength(5));
      expect(
        AppRoute.values.map((r) => r.path).toSet(),
        {
          '/splash',
          '/onboarding',
          '/login',
          '/register',
          '/home',
        },
      );
    });
  });
}
