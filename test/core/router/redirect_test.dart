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

  group('AppRoute enum (HDU-005 + HDU-005b + HDU-007)', () {
    test('declara 8 rutas: splash, onboarding, login, register, unlock, '
        'home, auth/verify-email, auth/reset-password', () {
      // HDU-004: 4 rutas. HDU-005 agregó /register (AC4). HDU-005b
      // agregó /unlock (AC15) para el cold start con biometría.
      // HDU-007 agregó /auth/verify-email y /auth/reset-password
      // (AC3, AC8) para los deep links de Supabase.
      expect(AppRoute.values, hasLength(8));
      expect(
        AppRoute.values.map((r) => r.path).toSet(),
        {
          '/splash',
          '/onboarding',
          '/login',
          '/register',
          '/unlock',
          '/home',
          '/auth/verify-email',
          '/auth/reset-password',
        },
      );
    });
  });

  group('rutas de deep link auth (HDU-007, AC3, AC8)', () {
    // Las rutas /auth/verify-email y /auth/reset-password son
    // **terminales** (como /unlock). El redirect NO las redirige,
    // independientemente de si hay sesión o no.
    //
    // **Por qué terminales y no "como /login" (redirigen a /home
    // con sesión):** el flujo de Supabase para reset password crea
    // una sesión temporal al procesar el deep link (necesaria para
    // que `updateUser` funcione). Si el redirect la tratara como
    // /login, sacaría al user a /home antes de que pueda cambiar la
    // password. Lo mismo aplica a verify-email: el user debe ver
    // el mensaje de éxito ANTES de cualquier redirección.

    test('/auth/verify-email sin sesión → no redirige (terminal)', () {
      expect(
        computeAuthRedirect(
          goingTo: '/auth/verify-email',
          isLoggedIn: false,
        ),
        isNull,
      );
    });

    test('/auth/verify-email con sesión → no redirige (terminal)', () {
      expect(
        computeAuthRedirect(
          goingTo: '/auth/verify-email',
          isLoggedIn: true,
        ),
        isNull,
      );
    });

    test('/auth/reset-password sin sesión → no redirige (terminal)', () {
      expect(
        computeAuthRedirect(
          goingTo: '/auth/reset-password',
          isLoggedIn: false,
        ),
        isNull,
      );
    });

    test('/auth/reset-password con sesión → no redirige (terminal)', () {
      expect(
        computeAuthRedirect(
          goingTo: '/auth/reset-password',
          isLoggedIn: true,
        ),
        isNull,
      );
    });
  });

  group('HDU-006 — splash detrás de feature flag (AC16, AC19)', () {
    // El redirect del router NO consulta el feature flag (decisión
    // arquitectónica del spec de HDU-006: el redirect decide a dónde
    // ir, el splash decide si se muestra). El feature flag se
    // consulta en el `SplashScreen` (no en el redirect). Por eso
    // estos tests verifican que:
    //
    //   1. El redirect sigue funcionando para /splash independientemente
    //      del flag (el redirect trata /splash como ruta pública
    //      siempre).
    //   2. La responsabilidad del flag es del widget, no del redirect.

    test('el redirect NO depende del feature flag splash', () {
      // Misma ruta (/splash), distintas decisiones de feature flag. El
      // redirect siempre devuelve `null` (público). El flag no entra
      // en la decisión.
      expect(
        computeAuthRedirect(goingTo: '/splash', isLoggedIn: false),
        isNull,
      );
      expect(
        computeAuthRedirect(goingTo: '/splash', isLoggedIn: true),
        isNull,
      );
    });

    test('la ruta /splash sigue siendo pública aunque el splash se '
        'auto-navegue (flag OFF)', () {
      // Cuando el feature flag `AppFeature.splash` está OFF, el
      // `SplashScreen` consulta el flag y llama `context.go('/home')`
      // directamente. El redirect corre para `/home` y decide el
      // destino final (login/unlock/home según sesión + biometría).
      // Esto es una verificación de que el redirect NO introduce
      // una dependencia del feature flag.
      expect(
        computeAuthRedirect(goingTo: '/home', isLoggedIn: false),
        '/login',
        reason:
            'el redirect sigue mandando a /login cuando no hay sesión, '
            'independientemente del splash',
      );
      expect(
        computeAuthRedirect(goingTo: '/home', isLoggedIn: true),
        isNull,
        reason:
            'con sesión activa, /home es terminal aunque el splash haya '
            'llamado context.go("/home") desde el flag OFF',
      );
    });
  });

  // Housekeeping bundle #3, fix #15: el `errorBuilder` ahora muestra
  // la URI sanitizada para evitar filtrar query params largos o
  // basura visual. Verificamos el helper directamente.
  group('sanitizeUriForDisplay', () {
    test('URI corta → se devuelve tal cual', () {
      expect(
        sanitizeUriForDisplay(Uri.parse('zeiki://login')),
        'zeiki://login',
      );
    });

    test('URI larga (>= maxLength) → se trunca con ...', () {
      // Forzamos maxLength pequeño para verificar el truncado.
      final longUri = Uri.parse(
        'zeiki://login?token=eyJhbGciOiJIUzI1NiJ9.payload.signature',
      );
      final result = sanitizeUriForDisplay(longUri, maxLength: 20);
      expect(result.length, lessThanOrEqualTo(23)); // 20 + '...'
      expect(result, endsWith('...'));
    });

    test('maxLength por default (50) cubre paths razonables', () {
      final result = sanitizeUriForDisplay(Uri.parse('zeiki://home'));
      // Sin truncar, devuelve el toString completo.
      expect(result, 'zeiki://home');
    });
  });
}
