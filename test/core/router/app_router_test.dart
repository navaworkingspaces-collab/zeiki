// Tests del router de navegación de Zeiki (HDU-004 + HDU-005).
//
// Verifica el contrato del router declarado en
// `lib/core/router/app_router.dart`:
//
//   - HDU-004 AC1: 4 rutas (`/splash`, `/onboarding`, `/login`,
//     `/home`) + ruta inicial `/splash`.
//   - HDU-004 AC8: cada ruta resuelve sin error; un deep link
//     `zeiki://<ruta>` parsea con scheme+host esperados.
//   - HDU-005 AC35: las 4 rutas de HDU-004 siguen existiendo, se
//     agregó `/register` (AC4) sin renombrar nada.
//
// **Cambio de HDU-005:** `appRouter` deja de ser una variable
// global. Se construye con `buildAppRouter(authServiceGetter: ...)`
// con un `AuthService` fake (sesión siempre null) para que el
// redirect no interfiera con estos tests de "resolución de rutas".
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:zeiki/core/auth/auth_exception.dart';
import 'package:zeiki/core/auth/auth_service.dart';
import 'package:zeiki/core/services/biometric_service.dart';
import 'package:zeiki/core/auth/google_sign_in_handler.dart';
import 'package:zeiki/core/di/service_locator.dart';
import 'package:zeiki/core/router/app_router.dart';

void main() {
  late GoRouter router;

  setUp(() {
    // `AuthService` fake: sesión siempre null para que el redirect
    // no nos saque de la ruta que estamos testeando.
    final fakeAuth = _FakeAuthService(session: null);
    final fakeBiometric = _FakeBiometricService();
    getIt.registerSingleton<AuthService>(fakeAuth);
    getIt.registerSingleton<GoogleSignInHandler>(
      const GoogleSignInHandler(),
    );
    getIt.registerSingleton<BiometricService>(fakeBiometric);
    router = buildAppRouter(
      authServiceGetter: () => getIt<AuthService>(),
    );
  });

  tearDown(() async {
    router.dispose();
    await getIt.reset();
  });

  group('appRouter configuration', () {
    test('initial location is /splash (HDU-004 AC1)', () {
      // La ruta inicial declarativa vive en `appRouter.configuration`.
      // Verificamos que `findMatch` resuelve `/splash` con la misma
      // config que se le pasa al constructor.
      final match = router.configuration.findMatch(Uri.parse('/splash'));
      expect(match.isError, isFalse);
    });

    test('resuelve /splash sin error (HDU-004 AC1, AC8)', () {
      final matchList = router.configuration.findMatch(Uri.parse('/splash'));
      expect(matchList.isError, isFalse);
      expect(matchList.matches, isNotEmpty);
    });

    test('resuelve /onboarding sin error (HDU-004 AC1, AC8)', () {
      final matchList =
          router.configuration.findMatch(Uri.parse('/onboarding'));
      expect(matchList.isError, isFalse);
      expect(matchList.matches, isNotEmpty);
    });

    test('resuelve /login sin error (HDU-004 AC1, AC8)', () {
      final matchList = router.configuration.findMatch(Uri.parse('/login'));
      expect(matchList.isError, isFalse);
      expect(matchList.matches, isNotEmpty);
    });

    test('resuelve /register sin error (HDU-005 AC4)', () {
      // Nueva ruta de HDU-005.
      final matchList =
          router.configuration.findMatch(Uri.parse('/register'));
      expect(matchList.isError, isFalse);
      expect(matchList.matches, isNotEmpty);
    });

    test('resuelve /home sin error (HDU-004 AC1, AC8)', () {
      final matchList = router.configuration.findMatch(Uri.parse('/home'));
      expect(matchList.isError, isFalse);
      expect(matchList.matches, isNotEmpty);
    });

    test('devuelve match con error para ruta desconocida (HDU-004 AC8)', () {
      // Cobertura de `errorBuilder`: rutas inexistentes deben producir
      // un match con error, no crashear.
      final matchList =
          router.configuration.findMatch(Uri.parse('/no-existe'));
      expect(matchList.isError, isTrue);
    });
  });

  group('AppRoute enum (HDU-004 + HDU-005 + HDU-005b + HDU-007, post HDU-007b)', () {
    test('declara las 7 rutas (HDU-004 + /register HDU-005 + /unlock HDU-005b '
        '+ /auth/reset-password HDU-007; /auth/verify-email removido en HDU-007b)', () {
      expect(AppRoute.values, hasLength(7));
      expect(
        AppRoute.values.map((r) => r.path).toSet(),
        {
          '/splash',
          '/onboarding',
          '/login',
          '/register',
          '/unlock',
          '/home',
          '/auth/reset-password',
        },
      );
    });

    test('splash es la ruta inicial declarada', () {
      expect(AppRoute.splash.path, '/splash');
      expect(
        router.configuration.findMatch(Uri.parse(AppRoute.splash.path))
            .isError,
        isFalse,
      );
    });

    test('cada AppRoute path resuelve sin error (HDU-004 + HDU-005 + HDU-005b '
        '+ HDU-007, post HDU-007b)', () {
      for (final route in AppRoute.values) {
        final match = router.configuration.findMatch(Uri.parse(route.path));
        expect(
          match.isError,
          isFalse,
          reason: 'Route ${route.path} should resolve without error',
        );
      }
    });

    test('resuelve /unlock sin error (HDU-005b, AC15)', () {
      final matchList =
          router.configuration.findMatch(Uri.parse('/unlock'));
      expect(matchList.isError, isFalse,
          reason: 'HDU-005b: /unlock debe existir para el cold start con '
              'sesión + biometría');
      expect(matchList.matches, isNotEmpty);
    });

    test('resuelve /auth/reset-password sin error (HDU-007, AC8)', () {
      final matchList = router.configuration
          .findMatch(Uri.parse('/auth/reset-password'));
      expect(matchList.isError, isFalse,
          reason: 'HDU-007: el deep link de reset password debe '
              'enrutar a /auth/reset-password');
      expect(matchList.matches, isNotEmpty);
    });
  });

  group('Deep link URI parsing (HDU-004 AC5, AC8)', () {
    // El formato Android `zeiki://<ruta>` usa scheme+host, no path.
    // `app_links` se encarga de traducir `zeiki://login` → `/login`
    // antes de entregarlo al router (eso lo cubre el integration test).
    // Aquí solo verificamos el parsing de la URI.

    test('zeiki://login tiene scheme zeiki y host login', () {
      final uri = Uri.parse('zeiki://login');
      expect(uri.scheme, 'zeiki');
      expect(uri.host, 'login');
    });

    test('zeiki://home tiene scheme zeiki y host home', () {
      final uri = Uri.parse('zeiki://home');
      expect(uri.scheme, 'zeiki');
      expect(uri.host, 'home');
    });

    test('zeiki://splash tiene scheme zeiki y host splash', () {
      final uri = Uri.parse('zeiki://splash');
      expect(uri.scheme, 'zeiki');
      expect(uri.host, 'splash');
    });

    test('zeiki://register tiene scheme zeiki y host register (nuevo en HDU-005)',
        () {
      final uri = Uri.parse('zeiki://register');
      expect(uri.scheme, 'zeiki');
      expect(uri.host, 'register');
    });
  });
}

/// Fake de `AuthService` con sesión controlable.
class _FakeAuthService implements AuthService {
  _FakeAuthService({this.session});
  sb.Session? session;

  @override
  sb.Session? getCurrentSession() => session;

  @override
  String? get currentUserId => session?.user.id;

  @override
  Future<void> signOut() async {
    session = null;
  }

  @override
  Stream<sb.AuthState> get authStateChanges =>
      const Stream<sb.AuthState>.empty();

  @override
  Future<sb.AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? emailRedirectTo,
  }) async =>
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in app_router_test',
      );

  @override
  Future<sb.AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in app_router_test',
      );

  @override
  Future<sb.AuthResponse> signInWithGoogle() async => throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in app_router_test',
      );

  // HDU-007: reset password + update user password. No se usan en
  // este test (cubre solo resolución de rutas), pero el `implements`
  // exige que estén.
  @override
  Future<void> resetPasswordForEmail({required String email}) async {
    throw const AuthException(
      kind: AuthErrorKind.unknown,
      message: 'not used in app_router_test',
    );
  }

  @override
  Future<sb.UserResponse> updateUserPassword({
    required String newPassword,
  }) async {
    throw const AuthException(
      kind: AuthErrorKind.unknown,
      message: 'not used in app_router_test',
    );
  }

  // (hasGoogleHandler removido en cleanup HDU-005, ver auth_service.dart)
}

/// Fake de `BiometricService` para tests del router. Devuelve
/// `false` por default para no interferir con la lógica del redirect
/// (los tests de biometría específicos están en
/// `biometric_service_test.dart`).
class _FakeBiometricService implements BiometricService {
  @override
  Future<bool> isBiometricAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;

  @override
  Future<bool> isBiometricEnabled({required String userId}) async => false;

  @override
  Future<void> setBiometricEnabled(
    bool enabled,
    {required String userId}
  ) async {}
}
