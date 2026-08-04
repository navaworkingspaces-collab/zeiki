// Tests de `ResetPasswordScreen` (HDU-007, AC8, AC9).
//
// Cubre:
//   - AC8: renderiza campos de nueva password + confirmación + botón
//     "Cambiar contraseña".
//   - AC9: tap en "Cambiar contraseña" con datos válidos → llama a
//     `AuthService.updateUserPassword` y navega a /home.
//   - Validación de cliente: passwords no coinciden, password < 8 chars.
//
// Setup: registramos un `AuthService` fake en `getIt` y un
// `GoRouter` real. El router empieza en /auth/reset-password (que
// es la ruta a la que llega el deep link de Supabase).
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
    // El deep link de reset-password nos trae aquí. El router empieza
    // en /splash; lo movemos a /auth/reset-password.
    router.go(AppRoute.resetPassword.path);
  });

  tearDown(() async {
    router.dispose();
    await getIt.reset();
  });

  Future<void> pumpResetPasswordScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  group('render (AC8)', () {
    testWidgets('muestra campos de nueva password + confirmación + botón '
        '"Cambiar contraseña"', (tester) async {
      await pumpResetPasswordScreen(tester);

      // Dos campos de password: nuevo y confirmación.
      expect(find.byKey(const Key('reset_password_new')), findsOneWidget);
      expect(
        find.byKey(const Key('reset_password_confirm')),
        findsOneWidget,
      );
      // Botón de submit.
      expect(find.byKey(const Key('reset_password_submit')), findsOneWidget);
    });
  });

  group('éxito (AC9)', () {
    testWidgets('datos válidos → llama updateUserPassword y navega a /home',
        (tester) async {
      await pumpResetPasswordScreen(tester);

      await tester.enterText(
        find.byKey(const Key('reset_password_new')),
        'new-secret-pass-9',
      );
      await tester.enterText(
        find.byKey(const Key('reset_password_confirm')),
        'new-secret-pass-9',
      );
      await tester.tap(find.byKey(const Key('reset_password_submit')));
      await tester.pumpAndSettle();

      expect(fakeAuth.updateUserPasswordCalls, 1);
      expect(
        fakeAuth.updateUserPasswordLastPassword,
        'new-secret-pass-9',
      );
      // Después del éxito, el router debe estar en /home.
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/home',
      );
    });
  });

  group('validación de cliente', () {
    testWidgets('passwords no coinciden → muestra error, no llama al '
        'servicio', (tester) async {
      await pumpResetPasswordScreen(tester);

      await tester.enterText(
        find.byKey(const Key('reset_password_new')),
        'new-secret-pass-9',
      );
      await tester.enterText(
        find.byKey(const Key('reset_password_confirm')),
        'other-pass-1234',
      );
      await tester.tap(find.byKey(const Key('reset_password_submit')));
      await tester.pump();

      expect(fakeAuth.updateUserPasswordCalls, 0,
          reason: 'updateUserPassword NO debe llamarse si los passwords '
              'no coinciden');
      expect(find.textContaining('coincid', findRichText: true), findsWidgets,
          reason: 'debe haber un mensaje de error sobre que no coinciden');
    });

    testWidgets('password muy corto → muestra error, no llama al servicio',
        (tester) async {
      await pumpResetPasswordScreen(tester);

      await tester.enterText(
        find.byKey(const Key('reset_password_new')),
        'short',
      );
      await tester.enterText(
        find.byKey(const Key('reset_password_confirm')),
        'short',
      );
      await tester.tap(find.byKey(const Key('reset_password_submit')));
      await tester.pump();

      expect(fakeAuth.updateUserPasswordCalls, 0);
      expect(find.textContaining('8', findRichText: true), findsWidgets);
    });
  });

  group('errores del servicio (AC9)', () {
    testWidgets('error del servicio → muestra mensaje accionable',
        (tester) async {
      fakeAuth.updateUserPasswordError =
          Exception('session expired');
      await pumpResetPasswordScreen(tester);

      await tester.enterText(
        find.byKey(const Key('reset_password_new')),
        'new-secret-pass-9',
      );
      await tester.enterText(
        find.byKey(const Key('reset_password_confirm')),
        'new-secret-pass-9',
      );
      await tester.tap(find.byKey(const Key('reset_password_submit')));
      // SnackBars de Material 3 tardan varios frames en entrar.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeAuth.updateUserPasswordCalls, 1);
      expect(find.textContaining('Intenta de nuevo'), findsOneWidget,
          reason: 'el mapper convierte excepciones desconocidas al mensaje '
              'genérico "Algo salió mal. Intenta de nuevo."');
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

  // HDU-007 — campos/contadores expuestos para los tests.
  int updateUserPasswordCalls = 0;
  String? updateUserPasswordLastPassword;
  Object? updateUserPasswordError;
  int resetPasswordCalls = 0;
  String? resetPasswordLastEmail;

  @override
  Future<sb.AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? emailRedirectTo,
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
  Future<void> resetPasswordForEmail({required String email}) async {
    resetPasswordCalls++;
    resetPasswordLastEmail = email;
  }

  @override
  Future<sb.UserResponse> updateUserPassword({
    required String newPassword,
  }) async {
    updateUserPasswordCalls++;
    updateUserPasswordLastPassword = newPassword;
    if (updateUserPasswordError != null) {
      throw mapSupabaseAuthError(updateUserPasswordError!);
    }
    // Reflejamos la sesión activa: en el flujo real, Supabase crea
    // una sesión temporal al procesar el deep link de reset password.
    // El `updateUser` la reutiliza. Si no hay sesión, el redirect del
    // router saca al user a /login (ver el comentario de HDU-007 en
    // `app_router.dart`).
    session ??= _makeAuthResponse().session;
    return sb.UserResponse.fromJson(<String, dynamic>{
      'id': 'user-1',
      'aud': 'authenticated',
      'app_metadata': const <String, dynamic>{},
      'user_metadata': const <String, dynamic>{},
      'created_at': DateTime.now().toIso8601String(),
      'email': 'hugo@zeiki.app',
    });
  }

  @override
  sb.Session? getCurrentSession() => session;

  @override
  String? get currentUserId => session?.user.id;

  @override
  Stream<sb.AuthState> get authStateChanges =>
      const Stream<sb.AuthState>.empty();
}

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
