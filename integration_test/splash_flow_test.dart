// Integration test del splash + feature flag (HDU-006, AC20).
//
// Cubre en device real (Xiaomi) el flujo end-to-end:
//
//   - **Cold start con `AppFeature.splash = ON`:** la app muestra el
//     splash con el branding (logo + "ZEIKI" + "LOADING" + footer),
//     reproduce las animaciones de entrada, hace fade-out, y el
//     redirect decide a dónde ir según la sesión.
//
//   - **Cold start con `AppFeature.splash = OFF`:** la app NO muestra
//     el branding, salta directo al destino que el redirect decide
//     (sin las animaciones de entrada).
//
//   - **El redirect del router funciona en ambos casos:** la decisión
//     post-cold-start es coherente con la sesión persistida.
//
// **Por qué se automatiza parcialmente:** la parte que requiere device
// real (render del logo, animaciones, integración con el sistema
// gráfico) se cubre con `flutter test integration_test/`. La parte de
// "que se vea bonito" la verifica Hugo en QA local (no se automatiza).
//
// **Cómo se corre:**
// ```
// flutter test integration_test/splash_flow_test.dart -d <deviceId>
// ```
// Requiere un device físico o emulador. La feature flag se setea
// desde el dashboard de Supabase (ver `docs/runbooks/splash-feature-flag.md`).
//
// **Lo que NO se automatiza aquí:**
//   - El cambio de la feature flag en Supabase (Hugo lo hace desde el
//     dashboard antes de correr el test).
//   - Verificación visual del logo / animaciones (QA con Hugo).
//   - Latencia de la animación de entrada (no es testeable
//     deterministicamente; depende del hardware).
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:zeiki/core/auth/auth_exception.dart';
import 'package:zeiki/core/auth/auth_service.dart';
import 'package:zeiki/core/auth/google_sign_in_handler.dart';
import 'package:zeiki/core/di/service_locator.dart';
import 'package:zeiki/core/router/app_router.dart';
import 'package:zeiki/core/services/biometric_service.dart';
import 'package:zeiki/core/tiers/app_feature.dart';
import 'package:zeiki/core/tiers/tier_change.dart';
import 'package:zeiki/core/tiers/tier_service.dart';
import 'package:zeiki/core/tiers/tier_service_config.dart';
import 'package:zeiki/features/identidad/blocs/splash_cubit.dart';
import 'package:zeiki/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late GoRouter router;
  late _FakeAuthService fakeAuth;
  late _FakeTierService tier;
  late SplashCubit cubit;

  setUp(() {
    fakeAuth = _FakeAuthService();
    tier = _FakeTierService();
    getIt.registerSingleton<AuthService>(fakeAuth);
    getIt.registerSingleton<BiometricService>(_FakeBiometricService());
    getIt.registerSingleton<GoogleSignInHandler>(
      const GoogleSignInHandler(),
    );
    getIt.registerSingleton<TierService>(tier);

    cubit = SplashCubit();
    router = buildAppRouter(
      authServiceGetter: () => getIt<AuthService>(),
      splashCubit: cubit,
    );
  });

  tearDown(() async {
    await cubit.close();
    router.dispose();
    await getIt.reset();
  });

  testWidgets(
      'cold start con splash flag ON: muestra el branding, fade-out, '
      'navega al destino del redirect', (tester) async {
    // El flag está ON: el splash reproduce las animaciones de entrada.
    tier.flags[AppFeature.splash] = true;
    // Sin sesión: el redirect mandará /home → /login al final.
    fakeAuth.session = null;

    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pump();

    // El splash está montado en /splash con el branding visible
    // (pese a la opacity=0 inicial de la entrada, los widgets
    // están en el árbol).
    expect(find.text('ZEIKI'), findsOneWidget,
        reason: 'flag ON: el branding "ZEIKI" se renderiza');
    expect(find.text('LOADING'), findsOneWidget,
        reason: 'flag ON: el branding "LOADING" se renderiza');
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/splash',
      reason: 'flag ON: estamos en /splash (animación en curso)',
    );

    // Dejamos pasar la animación de entrada (2500ms) + fade-out
    // (250ms) + un poco de margen. Después, el splash debe haberse
    // auto-navegado y el redirect debe haber decidido.
    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pumpAndSettle();

    // El redirect mandó /home → /login (sin sesión).
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/login',
      reason:
          'flag ON + sin sesión: el splash completó, llamó '
          'context.go("/home"), y el redirect mandó a /login',
    );
  });

  testWidgets(
      'cold start con splash flag OFF: NO muestra el branding, salta '
      'directo al destino del redirect', (tester) async {
    // El flag está OFF: el splash NO renderiza el branding. En la
    // práctica, se salta al destino que el redirect decida.
    tier.flags[AppFeature.splash] = false;
    fakeAuth.session = null;

    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pump();

    // El splash se auto-navegó, NO se renderiza el branding.
    expect(find.text('ZEIKI'), findsNothing,
        reason: 'flag OFF: el branding NO se renderiza');
    expect(find.text('LOADING'), findsNothing,
        reason: 'flag OFF: el branding NO se renderiza');

    // Dejamos que la navegación + redirect se asienten.
    await tester.pumpAndSettle();

    // El redirect mandó /home → /login.
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/login',
      reason:
          'flag OFF + sin sesión: el splash auto-navegó, el redirect '
          'mandó a /login',
    );
  });
}

/// `TierService` fake con el flag `splash` configurable.
class _FakeTierService implements TierService {
  final Map<AppFeature, bool> flags = <AppFeature, bool>{};
  // ignore: unused_field
  final bool debugEnabled;

  // ignore: unused_element_parameter
  _FakeTierService({this.debugEnabled = false});

  @override
  bool has(AppFeature feature) => flags[feature] ?? false;

  /// Match con el real: `debugEnabled || flags.isNotEmpty`.
  // ignore: unused_element_parameter
  @override
  bool isCacheLoaded() => debugEnabled || flags.isNotEmpty;

  @override
  Stream<TierChange> get changes => const Stream<TierChange>.empty();

  @override
  Future<void> refresh({bool force = false}) async {}

  @override
  Future<void> initialize({TierServiceConfig? config}) async {}

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `AuthService` fake con sesión controlable.
class _FakeAuthService implements AuthService {
  sb.Session? session;

  @override
  sb.Session? getCurrentSession() => session;

  @override
  String? get currentUserId => session?.user.id;

  @override
  Future<void> signOut() async {
    session = null;
  }

  @override
  Stream<sb.AuthState> get authStateChanges =>
      const Stream<sb.AuthState>.empty();

  @override
  Future<sb.AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? emailRedirectTo,
  }) async =>
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in splash_flow_test',
      );

  @override
  Future<sb.AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in splash_flow_test',
      );

  @override
  Future<sb.AuthResponse> signInWithGoogle() async => throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in splash_flow_test',
      );

  // HDU-007: stubs mínimos. No usados en este integration test.
  @override
  Future<void> resetPasswordForEmail({required String email}) async => throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in splash_flow_test',
      );

  @override
  Future<sb.UserResponse> updateUserPassword({required String newPassword}) async => throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in splash_flow_test',
      );
}

/// `BiometricService` fake mínimo.
class _FakeBiometricService implements BiometricService {
  @override
  Future<bool> isBiometricEnabled({required String userId}) async => false;

  @override
  Future<bool> isBiometricAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;

  @override
  Future<void> setBiometricEnabled(
    bool enabled, {
    required String userId,
  }) async {}
}
