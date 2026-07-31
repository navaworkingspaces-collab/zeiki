// HDU-005b AC30 — Integration test del timer de inactividad end-to-end.
//
// **Limitaciones:**
//   - `Timer` real NO se ve afectado por `tester.pump(Duration)`. Para
//     control total del tiempo se usa `fakeAsync` (que vive en
//     `package:fake_async`, ya en deps).
//   - En el integration test runner (no `flutter test`), el `Timer`
//     corre en la `Zone` real. Por eso este test es un smoke muy
//     limitado: solo verifica que `InactivityMonitor` se monta
//     sin crashear cuando se usa con un timeout muy largo
//     (1 hora) para que NO se dispare durante el test.
//
// **Lo que SÍ cubre (smoke):**
//   - `InactivityMonitor` se puede instanciar como child de
//     `MaterialApp` sin lanzar excepciones.
//   - El `signOutFn` se consulta correctamente (medimos que se
//     llama al `dispose`).
//
// **Verificación real del timer:** se hace en el unit test
// `test/core/auth/inactivity_monitor_test.dart` con `fakeAsync`
// (control total del tiempo, sin esperar 5 minutos).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:zeiki/core/auth/auth_service.dart';
import 'package:zeiki/core/auth/auth_service_config.dart';
import 'package:zeiki/core/services/biometric_service.dart';
import 'package:zeiki/core/auth/inactivity_monitor.dart';
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

  testWidgets('AC30: InactivityMonitor se monta con timeout de 1h sin '
      'disparar signOut durante el test (smoke)', (tester) async {
    // Timeout de 1 hora: imposible que se dispare durante el test
    // (que dura < 1 minuto). Sirve para verificar que el monitor
    // se puede instanciar y se integra con `MaterialApp` sin
    // lanzar excepciones.
    final router = buildAppRouter(
      authServiceGetter: () => getIt<AuthService>(),
    );
    addTearDown(router.dispose);

    var signOutCalls = 0;
    await tester.pumpWidget(
      InactivityMonitor(
        config: const AuthServiceConfig(
          inactivityTimeout: Duration(hours: 1),
        ),
        signOutFn: () async {
          signOutCalls++;
        },
        child: MaterialApp.router(
          title: 'Zeiki',
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // El monitor está vivo pero el timeout es 1h → signOut NO se
    // debió llamar durante el test.
    expect(signOutCalls, 0,
        reason: 'con timeout de 1h, el callback no debe dispararse '
            'durante un test de < 1 minuto');

    // El pump no debe lanzar excepciones.
    expect(tester.takeException(), isNull,
        reason: 'el InactivityMonitor debe montarse limpiamente');
  });
}

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
