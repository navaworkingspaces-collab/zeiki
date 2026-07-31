// Tests de `RegisterScreen` (HDU-005, AC4-AC11, AC28).
//
// Cubre:
//   - AC4: renderiza email + password + botón "Crear cuenta".
//   - AC5: tap en "Crear cuenta" con datos válidos → llama a
//     `AuthService.signUpWithEmail` y navega a `/home`.
//   - AC6: validación de cliente (email inválido, password < 8 chars)
//     → muestra error sin llamar al servicio.
//   - AC7: error del servicio → muestra mensaje accionable.
//   - AC8: hay un botón "Continuar con Google" debajo del formulario.
//   - AC9: tap en "Continuar con Google" → dispara `signInWithGoogle`
//     y navega a `/home` al éxito.
//   - AC10: si el usuario cancela el popup → no se muestra error y no
//     se navega.
//
// Setup: registramos un `AuthService` fake en `getIt` y un
// `GoRouter` real con redirect deshabilitado (los tests del redirect
// ya están en `redirect_test.dart`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:zeiki/core/auth/auth_exception.dart';
import 'package:zeiki/core/auth/auth_service.dart';
import 'package:zeiki/core/auth/google_sign_in_handler.dart';
import 'package:zeiki/core/di/service_locator.dart';
import 'package:zeiki/core/router/app_router.dart';
// Importamos el mapper (que viene del mismo archivo de auth_exception
// — el primer import cubre `AuthException`, `AuthErrorKind`,
// `UserCancelledAuthFlow` y `mapSupabaseAuthError`). No hace falta
// un import separado.

void main() {
  late _FakeAuthService fakeAuth;
  late GoRouter router;

  setUp(() {
    fakeAuth = _FakeAuthService();
    getIt.registerSingleton<AuthService>(fakeAuth);
    getIt.registerSingleton<GoogleSignInHandler>(
      const GoogleSignInHandler(),
    );

    // Router real con el redirect que consulta `getIt<AuthService>()`.
    // El getter se usa para que los tests que reemplazan el AuthService
    // (los de Google Sign-In) sigan funcionando sin reconstruir el
    // router.
    router = buildAppRouter(
      authServiceGetter: () => getIt<AuthService>(),
    );
    // El router empieza en /splash. Lo movemos a /register.
    router.go(AppRoute.register.path);
  });

  tearDown(() async {
    // `router.dispose` es async en go_router 14.x.
    router.dispose();
    await getIt.reset();
  });

  Future<void> pumpRegisterScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  group('render (AC4)', () {
    testWidgets('muestra campo email, password, botón "Crear cuenta" '
        'y botón "Continuar con Google"', (tester) async {
      await pumpRegisterScreen(tester);

      expect(find.widgetWithText(TextFormField, 'Correo'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Contraseña'),
          findsOneWidget);
      // Usamos `byKey` para no chocar con el título "Crear cuenta"
      // del AppBar.
      expect(find.byKey(const Key('register_submit')), findsOneWidget);
      expect(find.byKey(const Key('register_google')), findsOneWidget);
    });
  });

  group('validación de cliente (AC6)', () {
    testWidgets('email vacío → muestra error, no llama al servicio',
        (tester) async {
      await pumpRegisterScreen(tester);

      // Tap en "Crear cuenta" sin llenar nada.
      await tester.tap(find.byKey(const Key('register_submit')));
      await tester.pump();

      expect(fakeAuth.signUpCalls, 0,
          reason: 'signUp NO debe llamarse si el form no es válido');
      // El Form muestra error bajo el campo email.
      expect(find.textContaining('correo', findRichText: true),
          findsWidgets,
          reason: 'debe haber al menos un mensaje de error de email');
    });

    testWidgets('password < 8 chars → muestra error, no llama al servicio',
        (tester) async {
      await pumpRegisterScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'hugo@zeiki.app',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'short',
      );
      await tester.tap(find.byKey(const Key('register_submit')));
      await tester.pump();

      expect(fakeAuth.signUpCalls, 0);
      // El error de password < 8 chars.
      expect(find.textContaining('8', findRichText: true), findsWidgets);
    });
  });

  group('éxito con email (AC5)', () {
    testWidgets('datos válidos → llama signUpWithEmail y navega a /home',
        (tester) async {
      fakeAuth.signUpResult = _makeAuthResponse();
      await pumpRegisterScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'hugo@zeiki.app',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'secret-pass-1',
      );
      await tester.tap(find.byKey(const Key('register_submit')));
      await tester.pumpAndSettle();

      expect(fakeAuth.signUpCalls, 1);
      expect(fakeAuth.signUpLastEmail, 'hugo@zeiki.app');
      expect(fakeAuth.signUpLastPassword, 'secret-pass-1');
      // Después del éxito, el router debe estar en /home.
      expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
    });
  });

  group('errores del servicio (AC7)', () {
    testWidgets('email duplicado → muestra mensaje accionable',
        (tester) async {
      fakeAuth.signUpError = Exception('User already registered');
      await pumpRegisterScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'taken@zeiki.app',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'secret-pass-1',
      );
      await tester.tap(find.byKey(const Key('register_submit')));
      // SnackBars de Material 3 tardan varios frames en entrar. Tres
      // pumps manuales cubren el camino: validación del form, await
      // del signUp, finally que restaura el botón. `pumpAndSettle`
      // falla aquí porque algunas animaciones son infinitas.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeAuth.signUpCalls, 1);
      // El SnackBar debe mostrar el mensaje mapeado por el mapper.
      expect(find.textContaining('ya está registrado'), findsOneWidget);
    });
  });

  group('Google Sign-In (AC8, AC9, AC10)', () {
    testWidgets('tap en "Continuar con Google" con éxito → navega a /home',
        (tester) async {
      // Reemplazamos el handler por uno fake que devuelve idToken.
      final fakeHandler = GoogleSignInHandler(
        signInFn: () async => 'google-id-token-abc',
      );
      getIt.unregister<GoogleSignInHandler>();
      getIt.registerSingleton<GoogleSignInHandler>(fakeHandler);
      // Re-registramos el AuthService para que tome el nuevo handler.
      getIt.unregister<AuthService>();
      getIt.registerSingleton<AuthService>(_FakeAuthService()
        ..signInWithIdTokenResult = _makeAuthResponse()
        ..googleHandler = fakeHandler);

      await pumpRegisterScreen(tester);

      await tester.tap(find.byKey(const Key('register_google')));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
    });

    testWidgets('cancelación del popup → NO muestra error, NO navega',
        (tester) async {
      final fakeHandler = GoogleSignInHandler(
        signInFn: () async => null, // simula cancel
      );
      getIt.unregister<GoogleSignInHandler>();
      getIt.registerSingleton<GoogleSignInHandler>(fakeHandler);
      getIt.unregister<AuthService>();
      getIt.registerSingleton<AuthService>(_FakeAuthService()
        ..googleHandler = fakeHandler);

      await pumpRegisterScreen(tester);

      await tester.tap(find.byKey(const Key('register_google')));
      await tester.pumpAndSettle();

      // Seguimos en /register (no navegamos, no hay error visible).
      expect(router.routerDelegate.currentConfiguration.uri.path, '/register');
      expect(find.textContaining('error', findRichText: true), findsNothing,
          reason: 'AC10: cancelar el popup NO debe mostrar error');
    });
  });
}

/// Fake de `AuthService` que sustituye las llamadas a Supabase por
/// contadores y resultados configurables. Sigue el patrón del resto
/// del proyecto (conventions §3: fakes > mocks).
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
    // Actualizar la sesión para que el redirect del router deje ir a
    // /home tras el sign-up exitoso.
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
    // Actualizar la sesión para que el `redirect` del router
    // (que consulta `getCurrentSession()`) permita ir a /home.
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
  Stream<sb.AuthState> get authStateChanges =>
      const Stream<sb.AuthState>.empty();

  @override
  bool get hasGoogleHandler => googleHandler != null;
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
