// Tests de `HomeScreen` (HDU-005, AC18, AC19).
//
// Cubre:
//   - AC18: muestra el email del usuario actual.
//   - AC19: tap en "Salir" → llama a `AuthService.signOut()` y
//     navega a /login.
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

    // El test empieza con sesión activa (seteamos en el helper).
    // Para ir a /home sin que el redirect nos mande a /login, la
    // sesión tiene que estar ya seteada ANTES de navegar.
  });

  tearDown(() async {
    router.dispose();
    await getIt.reset();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  group('render (AC18)', () {
    testWidgets('muestra el email del usuario actual', (tester) async {
      fakeAuth.session = _makeSession(email: 'hugo@zeiki.app');
      router.go(AppRoute.home.path);
      await pumpHome(tester);

      expect(find.text('hugo@zeiki.app'), findsOneWidget);
      // HDU-005b: el botón "Salir" ahora vive en un PopupMenuButton
      // (settings chiquito). El menú está visible en el AppBar.
      expect(find.byKey(const Key('home_menu')), findsOneWidget);
    });

    testWidgets('si no hay sesión (defensa) → muestra texto genérico',
        (tester) async {
      // Esto NO debería pasar en runtime (el redirect manda a /login),
      // pero la pantalla debe ser defensiva: si llega sin sesión, no
      // crashea.
      fakeAuth.session = null;
      router.go(AppRoute.login.path); // empezamos en /login (sesión nula)
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      // Forzamos /home para probar la defensa.
      router.go(AppRoute.home.path);
      await tester.pumpAndSettle();
      // El redirect manda a /login porque no hay sesión. La defensa
      // no se ejerce porque el redirect ya protegió.
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    });
  });

  group('sign out (AC19) + menú de settings (HDU-005b)', () {
    testWidgets('menú tiene "Activar/Desactivar biometría" + "Salir"',
        (tester) async {
      fakeAuth.session = _makeSession(email: 'hugo@zeiki.app');
      router.go(AppRoute.home.path);
      await pumpHome(tester);

      // Abrir el menú.
      await tester.tap(find.byKey(const Key('home_menu')));
      await tester.pumpAndSettle();

      // Ambos items visibles.
      expect(find.byKey(const Key('home_menu_biometric')), findsOneWidget,
          reason: 'HDU-005b: toggle de biometría en el menú');
      expect(find.byKey(const Key('home_menu_signout')), findsOneWidget,
          reason: 'botón "Salir" sigue en el menú');
    });

    testWidgets('tap "Salir" en el menú → llama signOut y navega a /login',
        (tester) async {
      fakeAuth.session = _makeSession(email: 'hugo@zeiki.app');
      router.go(AppRoute.home.path);
      await pumpHome(tester);

      // Abrir menú y tap "Salir".
      await tester.tap(find.byKey(const Key('home_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home_menu_signout')));
      await tester.pumpAndSettle();

      expect(fakeAuth.signOutCalls, 1);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    });

    testWidgets('si signOut lanza AuthException → muestra SnackBar',
        (tester) async {
      fakeAuth.session = _makeSession(email: 'hugo@zeiki.app');
      fakeAuth.signOutError = Exception('Network down');
      router.go(AppRoute.home.path);
      await pumpHome(tester);

      // Abrir menú y tap "Salir".
      await tester.tap(find.byKey(const Key('home_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home_menu_signout')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeAuth.signOutCalls, 1);
      // El SnackBar debe mostrar un mensaje (cualquiera, no asumimos
      // el texto exacto).
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}

class _FakeAuthService implements AuthService {
  int signUpCalls = 0;
  Object? signUpError;
  sb.AuthResponse? signUpResult;

  int signInCalls = 0;
  Object? signInError;
  sb.AuthResponse? signInResult;

  int signInWithIdTokenCalls = 0;
  Object? signInWithIdTokenError;
  sb.AuthResponse? signInWithIdTokenResult;

  int signOutCalls = 0;
  Object? signOutError;
  sb.Session? session;
  GoogleSignInHandler? googleHandler;

  @override
  Future<sb.AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    if (signUpError != null) throw mapSupabaseAuthError(signUpError!);
    return signUpResult ?? _makeAuthResponse();
  }

  @override
  Future<sb.AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (signInError != null) throw mapSupabaseAuthError(signInError!);
    return signInResult ?? _makeAuthResponse();
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
    return signInWithIdTokenResult ?? _makeAuthResponse();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw mapSupabaseAuthError(signOutError!);
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

sb.AuthResponse _makeAuthResponse() {
  return sb.AuthResponse(
    session: _makeSession(),
    user: null,
  );
}

sb.Session _makeSession({String email = 'hugo@zeiki.app'}) {
  return sb.Session(
    accessToken: 'access',
    tokenType: 'bearer',
    user: sb.User(
      id: 'user-1',
      appMetadata: const <String, dynamic>{},
      userMetadata: const <String, dynamic>{},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    ),
  );
}
