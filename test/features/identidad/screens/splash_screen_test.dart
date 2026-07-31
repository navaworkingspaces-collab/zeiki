// Tests del `SplashScreen` widget (HDU-006, AC17).
//
// Cubre:
//   - AC1: el widget `SplashScreen` existe y se puede renderizar.
//   - AC7: textos "ZEIKI" (72px bold), "LOADING" (18px), footer con
//     versión (14px) están presentes en el árbol.
//   - AC2: si el feature flag `AppFeature.splash` está OFF, el splash
//     NO muestra los textos del branding y triggea navegación a
//     `/home` (el redirect decide el destino final).
//   - AC11: cuando el Cubit emite `SplashHidden`, el widget dispara
//     el fade-out (Opacity → 0) y llama `context.go(...)`.
//   - AC9: NO `Future.delayed` artificial — el splash se va cuando el
//     estado lo dice, no por un timer.
//
// **Patrón de tests:** se usa `BlocProvider<SplashCubit>` con un Cubit
// real (no mock) para verificar las transiciones de estado. El
// `TierService` se inyecta con un fake simple (conventions §3: fakes
// > mocks). El router recibe el Cubit vía `splashCubit:` para que la
// ruta `/splash` lo provea al `SplashScreen`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

void main() {
  late _FakeTierService tier;
  late _FakeAuthService auth;
  late _FakeBiometricService biometric;
  late GoRouter router;
  late SplashCubit cubit;

  setUp(() {
    // Mock del plugin `package_info_plus` (HDU-006 v2, fix del reviewer).
    // Sin esto, `PackageInfo.fromPlatform()` lanza en tests porque el
    // plugin real requiere el contexto de Android/iOS. Mockeamos con la
    // versión real del pubspec (0.1.0) para que el test verifique el
    // comportamiento end-to-end del footer.
    PackageInfo.setMockInitialValues(
      appName: 'zeiki',
      packageName: 'com.zeiki.zeiki',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );

    tier = _FakeTierService();
    auth = _FakeAuthService();
    biometric = _FakeBiometricService();
    getIt.registerSingleton<TierService>(tier);
    getIt.registerSingleton<AuthService>(auth);
    getIt.registerSingleton<BiometricService>(biometric);
    getIt.registerSingleton<GoogleSignInHandler>(const GoogleSignInHandler());

    cubit = SplashCubit();
    // El router recibe el Cubit para que la ruta `/splash` lo provea
    // al `SplashScreen` via `BlocProvider.value`. El test tiene
    // control total sobre las transiciones de estado.
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

  /// Monta el `MaterialApp.router` con el router. Como la ruta
  /// inicial es `/splash`, el `SplashScreen` se renderiza
  /// automáticamente.
  Future<void> pumpSplash(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
  }

  group('SplashScreen — feature flag ON (default)', () {
    setUp(() {
      tier.flags[AppFeature.splash] = true;
    });

    testWidgets('render: muestra el texto "ZEIKI" 72px bold', (tester) async {
      await pumpSplash(tester);
      // El `Center` envuelve una `Column` con los textos. Aunque la
      // animación de entrada hace que la opacity sea 0 al inicio, el
      // widget sigue en el árbol y `find.text` lo encuentra.
      final zeikiFinder = find.text('ZEIKI');
      expect(zeikiFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(zeikiFinder);
      expect(textWidget.style?.fontSize, 72);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('render: muestra el texto "LOADING" 18px', (tester) async {
      await pumpSplash(tester);
      final loadingFinder = find.text('LOADING');
      expect(loadingFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(loadingFinder);
      expect(textWidget.style?.fontSize, 18);
    });

    testWidgets('render: el footer muestra "v{version} · Developed by Zeiki '
        'Team" 14px', (tester) async {
      await pumpSplash(tester);

      // **Endurecido post-review HDU-006 v2:** antes el test solo buscaba
      // "Developed by Zeiki Team", lo cual pasaba IGUAL con la versión
      // rota ("v?"). Ahora verificamos:
      //   1. Que NO existe "v?" (versión rota).
      //   2. Que la versión mockeada (0.1.0) sí está en el footer.
      // Si `PackageInfo.fromPlatform()` falla o el mock no se aplica, el
      // footer mostraría "v?" y el test falla.
      expect(
        find.textContaining('v?'),
        findsNothing,
        reason: 'Si la versión es "v?" significa que '
            'PackageInfo.fromPlatform() falló. Revisar _loadAppVersion() '
            'en splash_screen.dart.',
      );

      expect(
        find.text('v0.1.0 · Developed by Zeiki Team'),
        findsOneWidget,
        reason: 'La versión debe venir del pubspec.yaml vía '
            'package_info_plus (mock inicializado en setUp).',
      );

      final footerFinder = find.text('v0.1.0 · Developed by Zeiki Team');
      final textWidget = tester.widget<Text>(footerFinder);
      expect(textWidget.style?.fontSize, 14);
    });

    testWidgets(
        'estado inicial: el SplashCubit arranca en SplashLoading y NO navega',
        (tester) async {
      await pumpSplash(tester);

      // El Cubit debe estar en loading (no ha pasado nada todavía).
      expect(cubit.state, isA<SplashLoading>());
      // La ruta sigue siendo /splash (no navegó a ningún lado).
      expect(router.routerDelegate.currentConfiguration.uri.path, '/splash');
    });
  });

  group('SplashScreen — cache cold del TierService (HDU-006 v3)', () {
    // **Caso de uso:** primera instalación o red caída. El cache del
    // TierService está vacío (no hay keys en el map). El splash debe
    // mostrarse igual (fail-safe "ON por default") porque el splash es
    // branding, no funcionalidad. El usuario debe ver la marca al abrir
    // la app por primera vez. Si el flag explícitamente está OFF, no
    // se muestra (eso lo cubre el grupo "feature flag OFF" arriba).
    //
    // NO seteamos `tier.flags[...]` en setUp → el map queda vacío →
    // `isCacheLoaded()` retorna `false` → el splash se muestra.

    testWidgets('cache cold + sin flag explícito → splash SÍ renderiza '
        'el branding (fail-safe "ON")', (tester) async {
      await pumpSplash(tester);

      // El branding debe estar presente aunque el cache esté frío.
      expect(find.text('ZEIKI'), findsOneWidget,
          reason: 'con cache cold (sin refresh previo), el splash debe '
              'mostrar el branding por default (fail-safe ON)');
      expect(find.text('LOADING'), findsOneWidget,
          reason: 'mismo motivo: el "LOADING" es parte del branding');
    });

    testWidgets('cache cold + flag explícito OFF en Supabase → splash NO '
        'renderiza el branding (el OFF explícito gana)', (tester) async {
      // Simula que el refresh ya terminó y trajo `splash = false` desde
      // Supabase. El cache está cargado (1 key), pero el flag es OFF.
      tier.flags[AppFeature.splash] = false;

      await pumpSplash(tester);

      expect(find.text('ZEIKI'), findsNothing,
          reason: 'con cache loaded + flag OFF, el splash se salta');
      expect(find.text('LOADING'), findsNothing,
          reason: 'mismo motivo');
    });
  });

  group('SplashScreen — feature flag OFF (AC2)', () {
    setUp(() {
      tier.flags[AppFeature.splash] = false;
    });

    testWidgets('NO render del branding (sin "ZEIKI" ni "LOADING")',
        (tester) async {
      await pumpSplash(tester);
      // El splash no debe mostrar el branding cuando el flag está OFF.
      expect(find.text('ZEIKI'), findsNothing);
      expect(find.text('LOADING'), findsNothing);
    });

    testWidgets(
        'transiciona a SplashHidden (sin esperar la animación de entrada)',
        (tester) async {
      await pumpSplash(tester);
      // El splash debe auto-navegar cuando el flag está OFF. Después
      // de unos pumps, el Cubit debe estar en `hidden`.
      await tester.pump(const Duration(milliseconds: 50));
      expect(cubit.state, isA<SplashHidden>(),
          reason:
              'con flag OFF, el splash debe saltarse la entrada e ir a hidden');
    });

    testWidgets('dispara navegación a /home (el redirect decide el destino)',
        (tester) async {
      // Con sesión null, el redirect mandará /home → /login. Verificamos
      // que el splash llamó a `context.go('/home')`.
      await pumpSplash(tester);
      // El splash fade-out es ~250ms; dejamos pasar suficiente tiempo.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      // El redirect debe haber enviado al usuario a /login (sesión null +
      // ruta privada /home).
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login',
          reason:
              'flag OFF + sin sesión → splash llama context.go("/home") y '
              'el redirect manda a /login');
    });
  });

  group('SplashScreen — transición a SplashHidden (AC11)', () {
    setUp(() {
      tier.flags[AppFeature.splash] = true;
    });

    testWidgets(
        'cuando el Cubit emite SplashHidden, el widget hace fade-out y navega',
        (tester) async {
      await pumpSplash(tester);

      // Forzamos al Cubit a hidden manualmente (simula que el
      // AnimationController del entry terminó + fade-out terminó).
      cubit.markReady();
      cubit.markHidden();
      await tester.pump();

      // Después del fade-out (~250ms), debe haber navegado.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // El redirect manda a /login (sesión null).
      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    });
  });
}

/// `TierService` fake con el flag `splash` configurable por test.
class _FakeTierService implements TierService {
  final Map<AppFeature, bool> flags = <AppFeature, bool>{};

  @override
  bool has(AppFeature feature) => flags[feature] ?? false;

  @override
  bool isCacheLoaded() => flags.isNotEmpty;

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

/// `AuthService` fake mínimo (no usado por el splash — AC10).
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
        message: 'not used in splash_screen_test',
      );

  @override
  Future<sb.AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in splash_screen_test',
      );

  @override
  Future<sb.AuthResponse> signInWithGoogle() async => throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in splash_screen_test',
      );
}

/// `BiometricService` fake mínimo (no usado por el splash — AC10).
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
