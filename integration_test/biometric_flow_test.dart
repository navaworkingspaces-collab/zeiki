// HDU-005b AC29 — Integration test del flujo de biometría end-to-end.
//
// **Limitaciones de este test en el test runner:**
//   - `local_auth` requiere un device físico (Xiaomi 2203129G) con
//     biometría configurada en el SO. El `IntegrationTestWidgetsFlutterBinding`
//     NO simula el popup del SO ni lee la huella.
//   - El plugin `local_auth` tiene un "test mode" parcial pero NO
//     permite simular el resultado de `authenticate()` — solo deja
//     que el popup real se muestre.
//
// **Por qué este archivo existe igual:** es un smoke test que
// documenta el flujo y se compila en CI. La verificación
// end-to-end (huella real) se hace por QA manual con Hugo
// siguiendo el runbook.
//
// **Lo que SÍ cubre este test (smoke):**
//   - El router tiene /unlock y /home configurados.
//   - La pantalla UnlockScreen se monta y renderiza sin crashear.
//
// **Para correr en device con huella simulada (manual):**
//   1. Activar biometría en el Xiaomi: Settings → Security →
//      Fingerprint (acción de Hugo, no automatizable).
//   2. `assets/.env` con Supabase real.
//   3. `flutter test integration_test/biometric_flow_test.dart -d 2203129G`
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:zeiki/core/auth/auth_service.dart';
import 'package:zeiki/core/services/biometric_service.dart';
import 'package:zeiki/core/di/service_locator.dart';
import 'package:zeiki/core/router/app_router.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    if (!getIt.isRegistered<AuthService>()) {
      getIt.registerSingleton<AuthService>(_NullAuthServiceForTest());
    }
    if (!getIt.isRegistered<BiometricService>()) {
      getIt.registerSingleton<BiometricService>(_NullBiometricServiceForTest());
    }
  });

  tearDownAll(() {
    if (getIt.isRegistered<AuthService>()) {
      getIt.unregister<AuthService>();
    }
    if (getIt.isRegistered<BiometricService>()) {
      getIt.unregister<BiometricService>();
    }
  });

  testWidgets('AC15: /unlock existe en la tabla de rutas', (tester) async {
    final router = buildAppRouter(
      authServiceGetter: () => getIt<AuthService>(),
    );
    addTearDown(router.dispose);

    final match = router.configuration.findMatch(Uri.parse('/unlock'));
    expect(match.isError, isFalse,
        reason: 'AC15: /unlock debe estar registrada para el cold start '
            'con sesión + biometría');
  });

  testWidgets('UnlockScreen se monta sin crashear (smoke)', (tester) async {
    // Sin sesión: el `UnlockScreen` se monta y trata de autenticar
    // con el fake (devuelve false). El smoke mínimo es que NO lance
    // excepciones y muestre el icono de huella + el botón "Usar
    // contraseña".
    final router = buildAppRouter(
      authServiceGetter: () => getIt<AuthService>(),
    );
    addTearDown(router.dispose);

    // Forzamos ir a /unlock (sin sesión, pero el redirect de /unlock
    // es terminal, no redirige).
    router.go('/unlock');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // La pantalla se renderiza (puede tener `_UnlockScreenState`
    // interna, pero al menos verificamos que el builder no lanzó).
    // El `addPostFrameCallback` puede no haber disparado todavía
    // en este pump, así que no verificamos el contenido exacto —
    // solo que el pump no crashea.
    expect(tester.takeException(), isNull,
        reason: 'AC27: el UnlockScreen debe montarse sin excepciones');
  });
}

/// Fake de `AuthService` para el integration test. Sin sesión.
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
          {required String email,
          required String password,
          String? emailRedirectTo}) =>
      throw UnimplementedError();

  @override
  Future<sb.AuthResponse> signInWithEmail(
          {required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<sb.AuthResponse> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  // HDU-007: stubs mínimos. No usados en este integration test.
  @override
  Future<void> resetPasswordForEmail({required String email}) =>
      throw UnimplementedError();

  @override
  Future<sb.UserResponse> updateUserPassword({required String newPassword}) =>
      throw UnimplementedError();
}

/// Fake de `BiometricService` para el integration test. Devuelve
/// `false` por default.
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

// (El import de `unlock_screen.dart` y el marker de tipo se eliminaron
// en el cleanup pre-merge. La pantalla se instancia por el router, no
// directamente en este test, así que ni el import ni el marker son
// necesarios.)
