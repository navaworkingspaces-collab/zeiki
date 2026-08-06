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
import 'package:zeiki/core/services/biometric_service.dart';
import 'package:zeiki/core/auth/google_sign_in_handler.dart';
import 'package:zeiki/core/di/service_locator.dart';
import 'package:zeiki/core/router/app_router.dart';
// Importamos el mapper (que viene del mismo archivo de auth_exception
// — el primer import cubre `AuthException`, `AuthErrorKind`,
// `UserCancelledAuthFlow` y `mapSupabaseAuthError`). No hace falta
// un import separado.

void main() {
  late _FakeAuthService fakeAuth;
  late _FakeBiometricService fakeBiometric;
  late GoRouter router;

  setUp(() {
    fakeAuth = _FakeAuthService();
    fakeBiometric = _FakeBiometricService();
    getIt.registerSingleton<AuthService>(fakeAuth);
    getIt.registerSingleton<BiometricService>(fakeBiometric);
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

  group('confirmación de email (Supabase "Enable email confirmations" = ON)', () {
    testWidgets('session null → muestra SnackBar "Revisa tu correo" y va '
        'a /login (no a /home)', (tester) async {
      // El fake devuelve session: null para simular que Supabase creó
      // el user pero no la sesión (caso típico cuando el proyecto
      // tiene confirmación de email activada).
      fakeAuth.signUpResult = _makeAuthResponseWithoutSession();
      await pumpRegisterScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'nuevo@zeiki.app',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'secret-pass-1',
      );
      await tester.tap(find.byKey(const Key('register_submit')));
      // El SnackBar de Material 3 entra en varios frames. Tres pumps
      // manuales cubren el camino: validación, await del signUp,
      // finally que restaura el botón. `pumpAndSettle` falla porque
      // el SnackBar tiene animación de salida y algunas animaciones
      // son infinitas.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeAuth.signUpCalls, 1);
      // El router debe estar en /login, NO en /home (sin sesión,
      // /home redirige a /login, y ese rebote dejaría al user en
      // limbo sin entender qué pasó).
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
      // El SnackBar con el mensaje claro debe estar visible.
      expect(
        find.text('Cuenta creada. Revisa tu correo para confirmar.'),
        findsOneWidget,
      );
      // El dialog de biometría NO debe aparecer (no hay sesión, no
      // hay userId, y el flujo de email confirmation sale antes de
      // llamar a _maybeShowBiometricActivationDialog).
      expect(
        find.byKey(const Key('biometric_activation_dialog')),
        findsNothing,
      );
      // El botón vuelve a estar habilitado (_isLoading = false).
      final submitButton = tester.widget<FilledButton>(
        find.byKey(const Key('register_submit')),
      );
      expect(submitButton.onPressed, isNotNull,
          reason: '_isLoading debe quedar en false al final del flujo');
    });

    testWidgets('session != null → flujo normal (regression): navega a /home, '
        'muestra dialog de biometría, NO muestra SnackBar', (tester) async {
      // Forzamos que el fake de biometría reporte disponible para que
      // el dialog SÍ se muestre (default = false, como en el resto de
      // los tests de pantalla).
      fakeBiometric.availableResult = true;
      fakeAuth.signUpResult = _makeAuthResponse(); // session != null
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
      // Tres pumps: validación, await del signUp, dialog abierto.
      // El `await showDialog(...)` BLOQUEA la navegación a /home
      // (que viene después en `_onSubmit`), por eso aún seguimos en
      // /register en este punto — eso es esperado, no es un bug.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeAuth.signUpCalls, 1);
      // El dialog de biometría SÍ se muestra (popup "¿Activar
      // huella?" one-shot por sesión). Eso valida que la rama
      // "sesión creada" del fix NO salta el flujo normal de
      // biometría.
      expect(
        find.byKey(const Key('biometric_activation_dialog')),
        findsOneWidget,
      );
      // NO se muestra el SnackBar del fix de email confirmation.
      expect(
        find.text('Cuenta creada. Revisa tu correo para confirmar.'),
        findsNothing,
      );
      // Todavía NO navegó a /home: el `await showDialog` mantiene
      // suspendido el resto de `_onSubmit`. Dismiss del dialog para
      // liberar la navegación.
      expect(router.routerDelegate.currentConfiguration.uri.path, '/register');
      await tester.tap(find.byKey(const Key('biometric_activation_dismiss')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Ahora sí: la navegación a /home ocurre, y el redirect la
      // deja pasar porque hay sesión.
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
    String? emailRedirectTo,
  }) async {
    signUpCalls++;
    signUpLastEmail = email;
    signUpLastPassword = password;
    if (signUpError != null) throw mapSupabaseAuthError(signUpError!);
    final response = signUpResult ?? _makeAuthResponse();
    // Actualizar la sesión para que el redirect del router deje ir a
    // /home tras el sign-up exitoso. Si `response.session` es null
    // (caso "Enable email confirmations" = ON), la sesión queda
    // null y el redirect manda a /login.
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

  // HDU-007: reset password + update user password. El `implements`
  // exige la firma. Los tests de register NO los usan pero el
  // compilador los necesita.
  @override
  Future<void> resetPasswordForEmail({required String email}) async {
    // No-op para no interferir con el resto del test.
  }

  @override
  Future<sb.UserResponse> updateUserPassword({
    required String newPassword,
  }) async {
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

  // (hasGoogleHandler removido en cleanup HDU-005, ver auth_service.dart)
}

/// Fake de `BiometricService` para los tests de pantalla. Devuelve
/// `false` por default en todos los métodos para no interferir con
/// la lógica del redirect (los tests específicos de biometría
/// están en `biometric_service_test.dart`).
///
/// El campo `availableResult` permite a un test individual forzar
/// `isBiometricAvailable() => true` para ejercitar la rama del
/// popup de activación. Default `false` para no afectar al resto de
/// los tests de la pantalla.
class _FakeBiometricService implements BiometricService {
  bool availableResult = false;

  @override
  Future<bool> isBiometricAvailable() async => availableResult;

  @override
  Future<bool> authenticate(String reason) async => false;

  @override
  Future<bool> isBiometricEnabled({required String userId}) async => false;

  @override
  Future<void> setBiometricEnabled(bool enabled, {required String userId}) async {}
}

/// Construye un `AuthResponse` con la sesión fake default (con
/// `user-1` y sesión creada). Es el helper usado por los tests
/// existentes que asumen sesión creada.
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

/// Construye un `AuthResponse` con `session: null`, simulando el caso
/// "Supabase creó el user pero NO la sesión" (caso típico cuando
/// `Enable email confirmations` = ON en el proyecto).
///
/// **Por qué un helper aparte y no un parámetro opcional:** con
/// `session: null` en un parámetro opcional, no se distingue "no
/// me importa" de "explícitamente null". Este helper hace explícito
/// el caso de prueba "sin sesión".
sb.AuthResponse _makeAuthResponseWithoutSession() {
  return sb.AuthResponse();
}
