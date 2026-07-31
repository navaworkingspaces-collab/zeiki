// Smoke tests del flujo de navegación de Zeiki (HDU-004 base + HDU-005
// + HDU-005b + HDU-006).
//
// Cubre los ACs que requieren montar la app en un widget tree:
//
//   - HDU-006: el splash real arranca en /splash y, al completarse,
//     navega a /login (porque no hay sesión). El `SplashScreen`
//     (no el `SplashPlaceholder` viejo) se renderiza.
//   - AC7 de HDU-004: state restoration está habilitado.
//   - AC4, AC12 de HDU-001: el `_PlaceholderPage` viejo ya no existe.
//   - El redirect del router funciona: ir a /home sin sesión → /login.
//
// **Lo que cambió de HDU-005 a HDU-006:**
//   - El `SplashPlaceholder` (andamio de HDU-004) se reemplazó por
//     el `SplashScreen` real (branding + feature flag + animaciones).
//   - El `BlocProvider<SplashCubit>` se provee a nivel de app
//     (`main.dart`). El smoke test hereda este Cubit.
//   - Para que el splash no bloquee los smoke tests, registramos un
//     `TierService` con `AppFeature.splash = false` → el splash
//     auto-navega sin reproducir las animaciones de entrada.
//
// Por la naturaleza de los cambios, este archivo se enfoca en:
//   - El splash real se renderiza (sin necesidad de ver branding).
//   - State restoration.
//   - `_PlaceholderPage` de HDU-001 ya no existe.
//   - El redirect del router funciona.
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
import 'package:zeiki/core/tiers/app_feature.dart';
import 'package:zeiki/core/tiers/tier_change.dart';
import 'package:zeiki/core/tiers/tier_service.dart';
import 'package:zeiki/core/tiers/tier_service_config.dart';
import 'package:zeiki/features/identidad/blocs/splash_cubit.dart';
import 'package:zeiki/main.dart';

void main() {
  late GoRouter router;
  late _FakeAuthService fakeAuth;
  late _FakeTierService tier;
  late SplashCubit cubit;

  setUp(() async {
    // Reset GetIt entre tests para que el singleton de GoRouter (de
    // la corrida anterior) no contamine.
    if (getIt.isRegistered<GoRouter>()) {
      await getIt.unregister<GoRouter>();
    }

    fakeAuth = _FakeAuthService();
    tier = _FakeTierService();
    // HDU-006: el splash debe auto-navegar para que el smoke test
    // no quede esperando 2500ms de animación. Ponemos el flag en OFF.
    tier.flags[AppFeature.splash] = false;

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

  testWidgets('arranca en /splash, el SplashScreen se monta y, con el flag '
      'splash OFF, auto-navega a /login (sin sesión)', (tester) async {
    // `ZeikiApp` envuelve el árbol con `BlocProvider<SplashCubit>` en
    // `main.dart`. El smoke test verifica que la app arranca sin
    // crashear y que el splash se reemplaza por la ruta real.
    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pumpAndSettle();

    // Con flag OFF + sin sesión, el splash se auto-navegó al destino
    // real, que es /login (el redirect manda /home → /login sin sesión).
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/login',
      reason:
          'flag splash OFF + sin sesión → el splash se auto-navega y el '
          'redirect manda a /login',
    );
  });

  testWidgets('con el flag splash ON, el splash renderiza el branding '
      'mientras está en /splash', (tester) async {
    // Sobreescribimos el flag para este test: el splash debe mostrar
    // "ZEIKI" y "LOADING" durante la animación de entrada.
    tier.flags[AppFeature.splash] = true;

    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pump();

    // Después del primer frame (sin pumpAndSettle para no completar
    // las animaciones), el branding debe estar en el árbol.
    expect(find.text('ZEIKI'), findsOneWidget);
    expect(find.text('LOADING'), findsOneWidget);
  });

  testWidgets('redirect manda a /login cuando se intenta ir a /home sin '
      'sesión (AC24)', (WidgetTester tester) async {
    // Forzamos navegación a /home con sesión nula. El splash se
    // auto-navegó primero (flag OFF), así que estamos en /login. Ir
    // a /home debe disparar el redirect → /login.
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

/// `TierService` fake con el flag `splash` configurable. El splash
/// consulta `tier.has(AppFeature.splash)` en `initState` (HDU-006).
class _FakeTierService implements TierService {
  final Map<AppFeature, bool> flags = <AppFeature, bool>{};

  @override
  bool has(AppFeature feature) => flags[feature] ?? false;

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
