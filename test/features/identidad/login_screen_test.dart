// Tests de `LoginScreen` (HDU-005, AC13-AC17, AC29).
//
// Cubre:
//   - AC13/14/15: la pantalla muestra ambos métodos (correo y Google)
//     (scope simplificado, spec §Plan técnico paso 9 — auto-detección
//     sale en HDU futura).
//   - AC14: tap en "Entrar" con datos válidos → llama a
//     `AuthService.signInWithEmail` y navega a /home.
//   - AC15: tap en "Entrar con Google" → dispara `signInWithGoogle` y
//     navega a /home al éxito.
//   - AC16: NO hay checkbox de "recordarme".
//   - AC17: credenciales inválidas → muestra mensaje accionable.
//   - AC10: cancelación del popup de Google → no error, no navega.
//
// Patrón: mismo setup que `register_screen_test.dart`. `_FakeAuthService`
// compartido (re-extraído a un helper si crece).
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

void main() {
  late _FakeAuthService fakeAuth;
  late GoRouter router;

  setUp(() {
    fakeAuth = _FakeAuthService();
    getIt.registerSingleton<AuthService>(fakeAuth);
    getIt.registerSingleton<BiometricService>(_FakeBiometricService());
    getIt.registerSingleton<GoogleSignInHandler>(
      const GoogleSignInHandler(),
    );

    router = buildAppRouter(
      authServiceGetter: () => getIt<AuthService>(),
    );
    router.go(AppRoute.login.path);
  });

  tearDown(() async {
    router.dispose();
    await getIt.reset();
  });

  Future<void> pumpLoginScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  group('render (AC13, AC14, AC15)', () {
    testWidgets('muestra ambos métodos (correo y Google) y el link a '
        'register', (tester) async {
      await pumpLoginScreen(tester);

      expect(find.widgetWithText(TextFormField, 'Correo'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Contraseña'),
          findsOneWidget);
      expect(find.byKey(const Key('login_submit')), findsOneWidget);
      expect(find.byKey(const Key('login_google')), findsOneWidget);
      // AC16: NO hay checkbox de "recordarme".
      expect(find.byType(Checkbox), findsNothing);
    });
  });

  group('login con email (AC14, AC17)', () {
    testWidgets('datos válidos → llama signInWithEmail y navega a /home',
        (tester) async {
      fakeAuth.signInResult = _makeAuthResponse();
      await pumpLoginScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'hugo@zeiki.app',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'secret-pass-1',
      );
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();

      expect(fakeAuth.signInCalls, 1);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
    });

    testWidgets('credenciales inválidas → muestra mensaje accionable',
        (tester) async {
      fakeAuth.signInError = Exception('Invalid login credentials');
      await pumpLoginScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'hugo@zeiki.app',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'wrong',
      );
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeAuth.signInCalls, 1);
      expect(find.textContaining('incorrectos'), findsOneWidget,
          reason: 'AC17: mensaje accionable para credenciales inválidas');
    });

    testWidgets('campos vacíos → muestra error de validación, no llama al '
        'servicio', (tester) async {
      await pumpLoginScreen(tester);
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pump();

      expect(fakeAuth.signInCalls, 0);
    });
  });

  group('login con Google (AC15, AC10)', () {
    testWidgets('tap en "Entrar con Google" con éxito → navega a /home',
        (tester) async {
      final fakeHandler = GoogleSignInHandler(
        signInFn: () async => 'google-id-token-xyz',
      );
      getIt.unregister<GoogleSignInHandler>();
      getIt.registerSingleton<GoogleSignInHandler>(fakeHandler);
      getIt.unregister<AuthService>();
      getIt.registerSingleton<AuthService>(_FakeAuthService()
        ..signInWithIdTokenResult = _makeAuthResponse()
        ..googleHandler = fakeHandler);

      await pumpLoginScreen(tester);

      await tester.tap(find.byKey(const Key('login_google')));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
    });

    testWidgets('cancelación del popup → NO muestra error, NO navega',
        (tester) async {
      final fakeHandler = GoogleSignInHandler(
        signInFn: () async => null,
      );
      getIt.unregister<GoogleSignInHandler>();
      getIt.registerSingleton<GoogleSignInHandler>(fakeHandler);
      getIt.unregister<AuthService>();
      getIt.registerSingleton<AuthService>(_FakeAuthService()
        ..googleHandler = fakeHandler);

      await pumpLoginScreen(tester);

      await tester.tap(find.byKey(const Key('login_google')));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
      expect(find.textContaining('error', findRichText: true), findsNothing,
          reason: 'AC10: cancelar el popup NO debe mostrar error');
    });
  });

  group('link a register (AC13)', () {
    testWidgets('tap en "¿No tienes cuenta? Créala" → navega a /register',
        (tester) async {
      await pumpLoginScreen(tester);

      await tester.tap(find.text('¿No tienes cuenta? Créala'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/register');
    });
  });
}

class _FakeAuthService implements AuthService {
  int signUpCalls = 0;
  String? signUpLastEmail;
  String? signUpLastPassword;
  Object? signUpError;
  sb.AuthResponse? signUpResult;

  int signInCalls = 0;
  Object? signInError;
  sb.AuthResponse? signInResult;

  int signInWithIdTokenCalls = 0;
  Object? signInWithIdTokenError;
  sb.AuthResponse? signInWithIdTokenResult;

  int signOutCalls = 0;
  sb.Session? session;
  GoogleSignInHandler? googleHandler;

  @override
  Future<sb.AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    signUpLastEmail = email;
    signUpLastPassword = password;
    if (signUpError != null) throw mapSupabaseAuthError(signUpError!);
    final response = signUpResult ?? _makeAuthResponse();
    session = response.session;
    return response;
  }

  @override
  Future<sb.AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (signInError != null) throw mapSupabaseAuthError(signInError!);
    final response = signInResult ?? _makeAuthResponse();
    session = response.session;
    return response;
  }

  @override
  Future<sb.AuthResponse> signInWithGoogle() async {
    if (googleHandler == null) {
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'no handler',
      );
    }
    final idToken = await googleHandler!.signInAndGetIdToken();
    if (idToken == null) throw const UserCancelledAuthFlow();
    signInWithIdTokenCalls++;
    if (signInWithIdTokenError != null) {
      throw mapSupabaseAuthError(signInWithIdTokenError!);
    }
    final response = signInWithIdTokenResult ?? _makeAuthResponse();
    session = response.session;
    return response;
  }

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

  // (hasGoogleHandler removido en cleanup HDU-005, ver auth_service.dart)
}

sb.AuthResponse _makeAuthResponse() {
  return sb.AuthResponse(
    session: sb.Session(
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
    ),
    user: null,
  );
}

/// Fake de `BiometricService` para los tests de pantalla. Devuelve
/// `false` por default en todos los métodos para no interferir con
/// la lógica del redirect (los tests específicos de biometría
/// están en `biometric_service_test.dart`).
class _FakeBiometricService implements BiometricService {
  @override
  Future<bool> isBiometricAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;

  @override
  Future<bool> isBiometricEnabled({required String userId}) async => false;

  @override
  Future<void> setBiometricEnabled(bool enabled, {required String userId}) async {}
}
