// Smoke tests del flujo de navegación de Zeiki (HDU-004 base + HDU-005).
//
// Cubre los ACs que requieren montar la app en un widget tree:
//
//   - AC1 + AC2: arranca en /splash y muestra el placeholder.
//   - AC3 + AC4: tap en un botón navega a la ruta del botón; el
//     `MaterialApp.router` dirige la navegación.
//   - AC7: state restoration está habilitado (`restorationScopeId`).
//   - AC12: el `_PlaceholderPage` de HDU-001 ya no existe.
//   - **HDU-005**: el smoke test se adaptó a las pantallas reales de
//     login (no más placeholder `Login`) — se verifica el AppBar
//     "Iniciar sesión" en vez del texto "Login" del placeholder.
//
// **Lo que cambió de HDU-004 a HDU-005:**
//   - `appRouter` ya no es variable global. Se construye con
//     `buildAppRouter(authServiceGetter: ...)` después de registrar
//     un `AuthService` fake en GetIt.
//   - `/login` ahora es `LoginScreen` (form), no el placeholder
//     con 2 botones. El smoke test de "tap en un botón y navega"
//     ya no aplica al login; la navegación a /home ahora requiere
//     haber pasado por signIn (testeado en register/login/home
//     screens específicos).
//   - `/home` ahora es `HomeScreen` (email + "Salir"), no el
//     placeholder con 2 botones. Igual: navegar a /home ahora
//     requiere sesión (cubierto por el redirect + tests de pantallas).
//
// Por la naturaleza de los cambios, este archivo se enfoca en:
//   - Arrancar en /splash.
//   - State restoration.
//   - _PlaceholderPage de HDU-001 ya no existe.
//   - El redirect del router funciona (ir a /home sin sesión → /login).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:zeiki/core/auth/auth_exception.dart';
import 'package:zeiki/core/auth/auth_service.dart';
import 'package:zeiki/core/auth/biometric_service.dart';
import 'package:zeiki/core/auth/google_sign_in_handler.dart';
import 'package:zeiki/core/di/service_locator.dart';
import 'package:zeiki/core/router/app_router.dart';
import 'package:zeiki/main.dart';

void main() {
  late GoRouter router;
  late _FakeAuthService fakeAuth;

  setUp(() async {
    // Reset GetIt entre tests para que el singleton de GoRouter (de
    // la corrida anterior) no contamine.
    if (getIt.isRegistered<GoRouter>()) {
      await getIt.unregister<GoRouter>();
    }

    fakeAuth = _FakeAuthService();
    getIt.registerSingleton<AuthService>(fakeAuth);
    getIt.registerSingleton<BiometricService>(_FakeBiometricService());
    getIt.registerSingleton<GoogleSignInHandler>(
      const GoogleSignInHandler(),
    );
    router = buildAppRouter(
      authServiceGetter: () => getIt<AuthService>(),
      biometricServiceGetter: () => getIt<BiometricService>(),
    );
  });

  tearDown(() async {
    router.dispose();
    await getIt.reset();
  });

  testWidgets('arranca en /splash y muestra el placeholder Splash',
      (WidgetTester tester) async {
    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pumpAndSettle();

    // Texto grande del placeholder de splash.
    expect(find.text('Splash'), findsOneWidget);
    // Botones de navegación que el splash expone.
    expect(find.text('Ir a Onboarding'), findsOneWidget);
    expect(find.text('Ir a Login'), findsOneWidget);
  });

  testWidgets('botón "Ir a Login" en /splash navega a /login (placeholder → '
      'pantalla real)', (WidgetTester tester) async {
    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ir a Login'));
    await tester.pumpAndSettle();

    // El `LoginScreen` real tiene AppBar con título "Iniciar sesión"
    // (no el texto "Login" del placeholder viejo).
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('redirect manda a /login cuando se intenta ir a /home sin '
      'sesión (AC24)', (WidgetTester tester) async {
    // Forzamos navegación a /home con sesión nula.
    fakeAuth.session = null;
    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoute.home.path);
    await tester.pumpAndSettle();

    // El redirect debe mandarnos a /login (sesión nula + ruta privada).
    expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
  });

  testWidgets('state restoration está habilitado (AC7)',
      (WidgetTester tester) async {
    // `MaterialApp.restorationScopeId` no-nulo es lo que go_router 14.x
    // necesita para registrar el `Router` con el `RestorationMixin`.
    // Sin este id, rotar el celular regresa al usuario a `/splash`.
    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      materialApp.restorationScopeId,
      isNotNull,
      reason: 'MaterialApp must have restorationScopeId for AC7',
    );
  });

  testWidgets('NO existe el _PlaceholderPage de HDU-001 (AC4, AC12)',
      (WidgetTester tester) async {
    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pumpAndSettle();

    // El texto del placeholder viejo ya no debe aparecer.
    expect(find.text('Zeiki — base del proyecto'), findsNothing);
  });
}

/// Fake de `AuthService` mínimo para los smoke tests. Mismo patrón
/// que el resto de los tests del proyecto (conventions §3: fakes
/// > mocks, sin `mockito`).
class _FakeAuthService implements AuthService {
  sb.Session? session;
  int signOutCalls = 0;

  @override
  sb.Session? getCurrentSession() => session;

  @override
  String? get currentUserId => session?.user.id;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    session = null;
  }

  @override
  Stream<sb.AuthState> get authStateChanges =>
      const Stream<sb.AuthState>.empty();

  // Métodos no usados en estos smoke tests; devuelven estado vacío.
  @override
  Future<sb.AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async =>
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in widget_test',
      );

  @override
  Future<sb.AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in widget_test',
      );

  @override
  Future<sb.AuthResponse> signInWithGoogle() async => throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in widget_test',
      );

  // (hasGoogleHandler removido en cleanup HDU-005, ver auth_service.dart)
}

/// Fake de `BiometricService` para smoke tests del router. Devuelve
/// `false` por default para no interferir con la lógica del redirect
/// (los tests específicos de biometría están en
/// `biometric_service_test.dart`).
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
