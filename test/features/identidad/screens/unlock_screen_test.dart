// Tests de `UnlockScreen` (HDU-005b, AC10-AC16, AC27).
//
// Pantalla full-screen que se muestra cuando el cold start tiene
// sesión persistida + `biometricEnabled` activo. Pide huella, y:
//
//   - Si la huella es válida → /home (sin pasar por login).
//   - Si falla 1-2 veces → muestra "Reintentar" y "Usar contraseña".
//   - Si falla 3 veces → `signOut()` + /login (fallback a login normal).
//   - Si el user toca "Usar contraseña" → /login sin signOut.
//
// **Diferencia con el flujo de auth normal:** el `AuthService` ya
// tiene sesión (por eso llegamos aquí, no a /login). El "fallback a
// login normal" significa limpiar la sesión y mandar a /login. El
// "Usar contraseña" significa solo mandar a /login (sin signOut)
// — es la opción "ya terminé por hoy, voy a meter mi password
// normal en vez de huella".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:zeiki/core/auth/auth_exception.dart';
import 'package:zeiki/core/auth/auth_service.dart';
import 'package:zeiki/core/services/biometric_service.dart';
import 'package:zeiki/core/auth/google_sign_in_handler.dart';
import 'package:zeiki/core/di/service_locator.dart';
import 'package:zeiki/core/router/app_router.dart';

// ====================================================================
// Fakes
// ====================================================================

/// Fake de `BiometricService`. Controla los returns de `authenticate`
/// y cuenta las llamadas.
class _FakeBiometricService implements BiometricService {
  _FakeBiometricService();

  bool authenticateResult = true;
  bool enabledResult = false;
  int authenticateCalls = 0;

  @override
  Future<bool> authenticate(String reason) async {
    authenticateCalls++;
    return authenticateResult;
  }

  // Métodos no usados en estos tests — devolvemos valores fijos
  // que NO disparan loops con el redirect. `isBiometricEnabled`
  // devuelve `false` por default para que el redirect no re-mande
  // a /unlock cuando el test navega a /login.
  @override
  Future<bool> isBiometricAvailable() async => true;

  @override
  Future<bool> isBiometricEnabled({required String userId}) async =>
      enabledResult;

  @override
  Future<void> setBiometricEnabled(bool enabled, {required String userId}) async {}
}

/// Fake de `AuthService` mínimo. Solo lo que el `UnlockScreen` usa.
class _FakeAuthService implements AuthService {
  int signOutCalls = 0;
  sb.Session? session = _makeSession();

  @override
  Future<void> signOut() async {
    signOutCalls++;
    session = null;
  }

  @override
  sb.Session? getCurrentSession() => session;

  @override
  String? get currentUserId => session?.user.id;

  @override
  Stream<sb.AuthState> get authStateChanges =>
      const Stream<sb.AuthState>.empty();

  // No usados.
  @override
  Future<sb.AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async =>
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in unlock_screen_test',
      );

  @override
  Future<sb.AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in unlock_screen_test',
      );

  @override
  Future<sb.AuthResponse> signInWithGoogle() async => throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in unlock_screen_test',
      );
}

sb.Session _makeSession() {
  return sb.Session(
    accessToken: 'access',
    tokenType: 'bearer',
    user: sb.User(
      id: 'user-1',
      appMetadata: const <String, dynamic>{},
      userMetadata: const <String, dynamic>{},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: 'hugo@zeiki.app',
    ),
  );
}

void main() {
  late _FakeBiometricService biometric;
  late _FakeAuthService auth;
  late GoRouter router;

  setUp(() {
    biometric = _FakeBiometricService();
    auth = _FakeAuthService();
    getIt.registerSingleton<AuthService>(auth);
    getIt.registerSingleton<BiometricService>(biometric);
    getIt.registerSingleton<GoogleSignInHandler>(
      const GoogleSignInHandler(),
    );

    router = buildAppRouter(
      authServiceGetter: () => getIt<AuthService>(),
    );
    // Forzamos ir a /unlock. El redirect acepta /unlock como
    // terminal (ver `computeAuthRedirect`), así que no se redirige.
    router.go(AppRoute.unlock.path);
  });

  tearDown(() async {
    router.dispose();
    await getIt.reset();
  });

  Future<void> pumpUnlock(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  // ====================================================================
  // Tests
  // ====================================================================

  group('UnlockScreen render (AC15)', () {
    testWidgets('muestra icono de huella, texto y botón "Usar contraseña"',
        (tester) async {
      // authenticateResult = true por default → navega a /home.
      // Para probar el render sin que navegue, configuramos false.
      biometric.authenticateResult = false;
      await pumpUnlock(tester);

      // Después del primer intento fallido, debe aparecer el mensaje
      // y los botones.
      expect(find.byIcon(Icons.fingerprint), findsOneWidget,
          reason: 'AC15: icono de huella visible');
      expect(find.text('Usar contraseña'), findsOneWidget,
          reason: 'AC14: el botón "Usar contraseña" siempre visible');
      expect(find.text('Reintentar'), findsOneWidget,
          reason: 'tras un fallo, debe haber "Reintentar"');
    });
  });

  group('UnlockScreen flujo (AC10, AC11, AC12, AC13, AC14, AC27)', () {
    testWidgets('al mount, llama automáticamente a authenticate (AC10)',
        (tester) async {
      biometric.authenticateResult = true;
      await pumpUnlock(tester);

      expect(biometric.authenticateCalls, 1,
          reason: 'AC10: el cold start dispara authenticate al entrar');
    });

    testWidgets('huella válida → navega a /home (AC11)', (tester) async {
      biometric.authenticateResult = true;
      await pumpUnlock(tester);
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/home',
          reason: 'AC11: huella válida → /home sin pasar por /login');
    });

    testWidgets('huella inválida (1er intento) → muestra mensaje y '
        '"Reintentar" (AC13)', (tester) async {
      biometric.authenticateResult = false;
      await pumpUnlock(tester);
      await tester.pumpAndSettle();

      // El mensaje de "no reconocida" y el botón "Reintentar" están
      // visibles; todavía no se hace signOut ni se va a /login.
      expect(find.text('Reintentar'), findsOneWidget,
          reason: 'AC13: tras 1 fallo, "Reintentar" visible');
      expect(auth.signOutCalls, 0,
          reason: '1 fallo NO debe hacer signOut');
      expect(router.routerDelegate.currentConfiguration.uri.path, '/unlock',
          reason: 'sigue en /unlock (no se fue a /login todavía)');
    });

    testWidgets('3 intentos fallidos → signOut + navega a /login (AC12)',
        (tester) async {
      biometric.authenticateResult = false;
      await pumpUnlock(tester);
      // El primer intento ya se hizo en mount (addPostFrameCallback).
      expect(biometric.authenticateCalls, 1);

      // Tap "Reintentar" (2do intento).
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(biometric.authenticateCalls, 2);

      // Tap "Reintentar" (3er intento).
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(biometric.authenticateCalls, 3);

      // Después del 3er fallo: signOut + /login.
      expect(auth.signOutCalls, 1,
          reason: 'AC12: 3 fallos → signOut (limpia la sesión)');
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login',
          reason: 'AC12: 3 fallos → fallback a /login');
    });

    testWidgets('tap "Usar contraseña" → signOut + navega a /login (AC14)',
        (tester) async {
      biometric.authenticateResult = false;
      await pumpUnlock(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Usar contraseña'));
      await tester.pumpAndSettle();

      // "Usar contraseña" hace signOut para evitar el loop /login
      // → /home (la sesión está activa, el redirect manda a /home).
      // Esto matchea la semántica de "ya cerré, voy a meter
      // password" que el user espera al tocar este botón.
      expect(auth.signOutCalls, 1,
          reason: 'desviación del spec: "Usar contraseña" hace '
              'signOut para evitar loop con el redirect');
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    });

    testWidgets('tap "Reintentar" → llama authenticate de nuevo',
        (tester) async {
      biometric.authenticateResult = false;
      await pumpUnlock(tester);
      // 1er intento (mount).
      expect(biometric.authenticateCalls, 1);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(biometric.authenticateCalls, 2,
          reason: 'un tap en "Reintentar" dispara otro authenticate');
    });
  });
}
