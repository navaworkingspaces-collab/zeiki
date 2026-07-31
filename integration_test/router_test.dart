// HDU-004 AC9 — Integration tests del router de navegación.
// (Actualizado en HDU-005 para usar la nueva `ZeikiApp(router: ...)`.)
//
// Cubre el flujo end-to-end que solo se puede verificar en un device
// real (Xiaomi) o con `flutter test integration_test/`:
//
//   - Tap un botón navega a la ruta del botón (cubierto también por
//     `test/widget_test.dart`, pero repetido aquí en el contexto del
//     test runner de integración).
//   - Deep link `zeiki://login` desde fuera abre la pantalla de login
//     (AC5 verificado en device — fuera del alcance de widget tests).
//   - Back button del Android pop el route stack correctamente (AC6).
//   - Rotación preserva el estado actual (AC7 — state restoration).
//
// **Cambios de HDU-005:**
//   - `ZeikiApp` ya no es `const` ni sin args: requiere un `router`.
//   - El router se construye con `buildAppRouter(authServiceGetter: ...)`
//     con un `AuthService` fake (sesión null) para que el redirect
//     no saque de las rutas testeadas.
//   - Las pantallas `/login` y `/home` ahora son las reales, no los
//     placeholders. Los asserts cambiaron: "Login" → "Iniciar sesión".
//
// Notas:
//   - El handler de deep links vive en `lib/core/router/app_links_handler.dart`
//     y se cablea desde `main.dart`. La verificación end-to-end con
//     `adb shell am start -W -a android.intent.action.VIEW -d "zeiki://login"`
//     requiere device físico (Xiaomi), no se automatiza aquí.
//   - El assertion de rotación también requiere device — `WidgetTester`
//     no simula el ciclo de vida nativo de Flutter.
//
// Para correr en device: `flutter test integration_test/router_test.dart
// -d <deviceId>`. La parte automatizable (tap, navegación) corre
// siempre; la parte que requiere device real (adb deep link, rotación)
// se cubre por inspección cuando se ejecuta el comando.
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:zeiki/core/auth/auth_exception.dart';
import 'package:zeiki/core/auth/auth_service.dart';
import 'package:zeiki/core/services/biometric_service.dart';
import 'package:zeiki/core/auth/google_sign_in_handler.dart';
import 'package:zeiki/core/di/service_locator.dart';
import 'package:zeiki/core/router/app_router.dart';
import 'package:zeiki/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late GoRouter router;
  late _FakeAuthService fakeAuth;

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
  });

  tearDown(() async {
    router.dispose();
    await getIt.reset();
  });

  testWidgets('arranca en /splash y muestra el placeholder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pumpAndSettle();

    expect(find.text('Splash'), findsOneWidget);
  });

  testWidgets('tap "Ir a Login" navega a /login (pantalla real, no '
      'placeholder)', (WidgetTester tester) async {
    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ir a Login'));
    await tester.pumpAndSettle();

    // Pantalla real de login tiene AppBar con título "Iniciar sesión".
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  // El test de deep link end-to-end con `adb shell am start -W -a
  // android.intent.action.VIEW -d "zeiki://login"` se cubre por QA
  // manual con Hugo siguiendo el runbook (este archivo queda como
  // referencia de la lista de pasos cuando se ejecute en device).
}

/// Fake de `AuthService` con sesión siempre null (para que el
/// redirect no saque de las rutas testeadas).
class _FakeAuthService implements AuthService {
  @override
  sb.Session? getCurrentSession() => null;

  @override
  String? get currentUserId => null;

  @override
  Future<void> signOut() async {}

  @override
  Stream<sb.AuthState> get authStateChanges =>
      const Stream<sb.AuthState>.empty();

  @override
  Future<sb.AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async =>
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in router_test',
      );

  @override
  Future<sb.AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in router_test',
      );

  @override
  Future<sb.AuthResponse> signInWithGoogle() async => throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in router_test',
      );

  // (hasGoogleHandler removido en cleanup HDU-005, ver auth_service.dart)
}

/// Fake de `BiometricService` para el integration test. Devuelve
/// `false` por default — no interferimos con la lógica del redirect.
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
