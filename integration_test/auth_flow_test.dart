// HDU-005 AC31 — Integration test del flujo de auth end-to-end.
//
// **Limitación de este test:** requiere un device físico (Xiaomi 2203129G)
// Y que Hugo haya configurado el provider de Google en el dashboard
// de Supabase. Sin esa config, el flow de Google fallará; el flujo
// con correo sí puede probarse si `assets/.env` tiene
// `SUPABASE_URL` y `SUPABASE_ANON_KEY` válidos.
//
// **Cubre (AC31):**
//   - El router redirige a /login al cold start sin sesión.
//   - El botón "Entrar con Google" existe en la pantalla de login
//     (la verificación end-to-end del popup del SO no se puede
//     automatizar — se hace por QA manual con el runbook).
//   - Las rutas existen y se puede navegar entre ellas.
//
// **Lo que NO cubre este test (manual en device):**
//   - El flujo completo: register con correo → home → logout →
//     login → home → cerrar app → reabrir → home. Eso requiere
//     credenciales reales de Supabase y se hace por QA manual.
//   - El popup de Google Sign-In (no automatizable en integration
//     test runner).
//   - La persistencia real de sesión (requiere swipe-kill de la app,
//     que el test runner no simula).
//
// **Para correr en device:**
//   1. `assets/.env` con Supabase real configurado.
//   2. (Opcional) Google provider en Supabase dashboard (runbook).
//   3. `flutter test integration_test/auth_flow_test.dart -d 2203129G`
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:zeiki/core/auth/auth_service.dart';
import 'package:zeiki/core/services/biometric_service.dart';
import 'package:zeiki/core/di/service_locator.dart';
import 'package:zeiki/core/router/app_router.dart';
import 'package:zeiki/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // El test runner NO llama a `main()` del proyecto. Aquí
    // registramos un AuthService fake en GetIt para que el redirect
    // del router pueda consultar la sesión sin crashear. El fake
    // siempre devuelve `null` en `getCurrentSession` (= sin sesión),
    // que es lo que queremos para estos smoke tests.
    if (!getIt.isRegistered<AuthService>()) {
      getIt.registerSingleton<AuthService>(_NullAuthServiceForTest());
    }
    if (!getIt.isRegistered<BiometricService>()) {
      getIt.registerSingleton<BiometricService>(_NullBiometricServiceForTest());
    }
  });

  tearDownAll(() {
    // Limpia el singleton para no contaminar otras suites.
    if (getIt.isRegistered<AuthService>()) {
      getIt.unregister<AuthService>();
    }
    if (getIt.isRegistered<BiometricService>()) {
      getIt.unregister<BiometricService>();
    }
  });

  testWidgets('AC25: cold start sin sesión termina en /splash o /login',
      (WidgetTester tester) async {
    final router = buildAppRouter(
      // El getter resuelve el AuthService desde GetIt (registrado en
      // setUpAll). El fake devuelve `null` → redirect a /login.
      authServiceGetter: () => getIt<AuthService>(),

    );
    addTearDown(router.dispose);

    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pumpAndSettle();

    final currentPath =
        router.routerDelegate.currentConfiguration.uri.path;
    // Sin sesión, el redirect manda a /login.
    expect(currentPath, isIn(<String>{'/splash', '/login'}),
        reason: 'cold start sin sesión debe terminar en /splash o /login');
  });

  testWidgets('AC14, AC15: pantalla /login tiene ambos métodos de auth',
      (WidgetTester tester) async {
    final router = buildAppRouter(
      authServiceGetter: () => getIt<AuthService>(),

    );
    addTearDown(router.dispose);

    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pumpAndSettle();

    // Forzar navegación a /login (puede que estemos en /splash).
    router.go('/login');
    await tester.pumpAndSettle();

    // Ambos métodos deben estar visibles (AC14, AC15).
    expect(find.text('Entrar'), findsOneWidget,
        reason: 'AC14: debe haber botón "Entrar" para login con correo');
    expect(find.text('Entrar con Google'), findsOneWidget,
        reason: 'AC15: debe haber botón "Entrar con Google"');
  });

  testWidgets('AC4: pantalla /register tiene el botón "Crear cuenta" '
      'y "Continuar con Google"', (WidgetTester tester) async {
    final router = buildAppRouter(
      authServiceGetter: () => getIt<AuthService>(),

    );
    addTearDown(router.dispose);

    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pumpAndSettle();

    router.go('/register');
    await tester.pumpAndSettle();

    expect(find.text('Crear cuenta'), findsWidgets,
        reason: 'AC4: el botón "Crear cuenta" debe estar en la pantalla');
    expect(find.text('Continuar con Google'), findsOneWidget,
        reason: 'AC8: el botón de Google debe estar debajo del formulario');
  });
}

/// Fake de `AuthService` para el integration test runner. Solo el método
/// que el redirect consulta (`getCurrentSession`) está implementado;
/// el resto lanza `UnimplementedError` si se llama. Es suficiente para
/// los smoke tests de este archivo (router redirect + render de
/// pantallas), no para flujos de sign-in reales.
class _NullAuthServiceForTest implements AuthService {
  @override
  sb.Session? getCurrentSession() => null;

  @override
  String? get currentUserId => null;

  @override
  Stream<sb.AuthState> get authStateChanges =>
      const Stream<sb.AuthState>.empty();

  @override
  Future<sb.AuthResponse> signUpWithEmail(
          {required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<sb.AuthResponse> signInWithEmail(
          {required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<sb.AuthResponse> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}

/// Fake de `BiometricService` para el integration test runner. No se usa
/// en estos smoke tests (no hay biometría configurada en el runner);
/// se necesita solo para satisfacer la firma de `buildAppRouter`.
class _NullBiometricServiceForTest implements BiometricService {
  @override
  Future<bool> isBiometricAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;

  @override
  Future<bool> isBiometricEnabled({required String userId}) async => false;

  @override
  Future<void> setBiometricEnabled(bool enabled, {required String userId}) async {}
}
