// Tests del `service_locator.dart` (ADR-005).
//
// Criticidad: media. El service locator es el "puente" entre el código
// de feature y los singletons lazy. Si alguien borra el registro de un
// servicio, la app crashea al primer `getIt<T>()` con `GetIt: ... is
// not registered`.
//
// Servicios registrados (HDU-001 → HDU-007):
//   - `TierService` (HDU-003).
//   - `AuthService` (HDU-005, AC2).
//   - `GoogleSignInHandler` (HDU-005).
//   - `GoRouter` (HDU-005, AC23 — Decisión A del review de HDU-004).
//   - `PasswordRecoveryListener` (HDU-007 — red de seguridad del deep
//     link de reset password). Implementa `Disposable` para que
//     `getIt.reset()` cancele la suscripción limpiamente.
//
// Por qué este test existe:
//
//   1. **Regresión contra "olvidé registrar X".** Si alguien borra un
//      `registerLazySingleton` en `service_locator.dart`, este test
//      falla inmediatamente en CI.
//
//   2. **Idempotencia.** `setupServiceLocator()` debe poderse llamar
//      múltiples veces sin lanzar (lo usan los integration tests con
//      `getIt.reset()` + re-registro entre casos). Sin idempotencia,
//      el segundo `registerLazySingleton` lanza `Already registered`.
//
//   3. **`getIt.reset()` limpia el registro.** Verificar que después
//      de `reset()`, los singletons YA NO están registrados.
//
//   4. **Wiring del listener de `passwordRecovery` (HDU-007).**
//      Cuando Supabase emite `AuthChangeEvent.passwordRecovery`, el
//      listener debe navegar al reset password. Ver grupo
//      `PasswordRecoveryListener` más abajo.
//
// Patrón: fakes solo donde tiene sentido. Aquí no se necesita fake
// de los servicios para los tests de registro — verificamos que
// `setupServiceLocator` REGISTRA las clases, no que funcionen (eso
// lo cubren los tests específicos). Para el test del listener sí se
// necesita un `AuthService` fake con un stream controlado.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:zeiki/core/auth/auth_exception.dart';
import 'package:zeiki/core/auth/auth_service.dart';
import 'package:zeiki/core/auth/google_sign_in_handler.dart';
import 'package:zeiki/core/auth/password_recovery_listener.dart';
import 'package:zeiki/core/constants/env_config.dart';
import 'package:zeiki/core/di/service_locator.dart';
import 'package:zeiki/core/tiers/tier_service.dart';
import 'package:zeiki/features/identidad/blocs/splash_cubit.dart';

void main() {
  // Reset entre tests. `service_locator` usa la instancia global de
  // `getIt`; sin reset, los registros de un test contaminan al siguiente.
  tearDown(() async {
    await getIt.reset();
  });

  // `EnvConfig` fake con valores dummy. El `service_locator` solo lee
  // `env.googleWebClientId` (lo pasa al `GoogleSignInHandler`), los
  // demás campos no se usan en estos tests. Si `setupServiceLocator`
  // empieza a leer más campos, este fake se ajusta.
  // BUG-001: este fake es el que evita que `setupServiceLocator`
  // lance al boot de los tests por falta de `.env` real.
  final testEnv = EnvConfig(
    supabaseUrl: 'https://test.supabase.co',
    supabaseAnonKey: 'test-anon-key',
    appEnv: 'test',
    debugLogs: false,
    googleWebClientId: 'test-web-client-id.apps.googleusercontent.com',
  );

  group('setupServiceLocator()', () {
    test('registra TierService en GetIt (regression HDU-003)', () {
      // Antes de llamar setupServiceLocator, NO debe estar registrado
      // (el tearDown del test anterior hizo reset).
      expect(getIt.isRegistered<TierService>(), isFalse,
          reason: 'asumimos estado limpio (tearDown del test anterior)');

      setupServiceLocator(testEnv);

      // Después de llamar, SÍ está registrado.
      expect(getIt.isRegistered<TierService>(), isTrue,
          reason: 'TierService debe estar registrado en GetIt después '
              'de setupServiceLocator() — sin esto, TierService.getInstance() '
              'lanza "is not registered"');
    });

    test('registra AuthService en GetIt (regression HDU-005, AC2)', () {
      // Pre-condición: GoRouter y AuthService NO registrados.
      expect(getIt.isRegistered<AuthService>(), isFalse);
      expect(getIt.isRegistered<GoogleSignInHandler>(), isFalse);

      setupServiceLocator(testEnv);

      expect(getIt.isRegistered<AuthService>(), isTrue,
          reason: 'AuthService debe estar registrado en GetIt (HDU-005 AC2)');
      expect(getIt.isRegistered<GoogleSignInHandler>(), isTrue,
          reason: 'GoogleSignInHandler debe estar registrado (lo usa '
              'AuthService internamente)');
    });

    test('registra GoRouter en GetIt (regression HDU-005, AC23)', () {
      expect(getIt.isRegistered<GoRouter>(), isFalse,
          reason: 'antes de setupServiceLocator, GoRouter NO debe estar '
              'registrado (asumimos estado limpio)');

      setupServiceLocator(testEnv);

      expect(getIt.isRegistered<GoRouter>(), isTrue,
          reason: 'GoRouter debe estar registrado en GetIt (HDU-005 AC23 — '
              'Decisión A del review de HDU-004). Sin esto, main.dart no '
              'puede obtener el router con getIt<GoRouter>()');
    });

    test('es idempotente: llamarlo 2 veces NO lanza (lo usan los '
        'integration tests entre casos)', () {
      setupServiceLocator(testEnv);
      // El segundo call NO debe lanzar "already registered".
      expect(() => setupServiceLocator(testEnv), returnsNormally,
          reason: 'setupServiceLocator debe ser idempotente: chequea '
              'isRegistered antes de registrar. Los integration tests '
              'confían en esto para hacer reset + re-registro entre tests');
    });

    test('después de getIt.reset(), ningún servicio queda registrado',
        () async {
      setupServiceLocator(testEnv);
      expect(getIt.isRegistered<TierService>(), isTrue);
      expect(getIt.isRegistered<AuthService>(), isTrue);
      expect(getIt.isRegistered<GoRouter>(), isTrue);
      expect(getIt.isRegistered<PasswordRecoveryListener>(), isTrue);

      // `getIt.reset()` es async. Sin `await`, el assert de abajo
      // corre antes de que el reset termine y falla con un falso
      // positivo.
      await getIt.reset();

      expect(getIt.isRegistered<TierService>(), isFalse,
          reason: 'reset() debe limpiar TODOS los registros');
      expect(getIt.isRegistered<AuthService>(), isFalse,
          reason: 'reset() debe limpiar AuthService también');
      expect(getIt.isRegistered<GoRouter>(), isFalse,
          reason: 'reset() debe limpiar GoRouter también');
      expect(getIt.isRegistered<PasswordRecoveryListener>(), isFalse,
          reason: 'reset() debe limpiar el listener (HDU-007) también');
    });

    test('TierService.getInstance() devuelve el singleton registrado', () {
      // Esto es el path que usan los integration tests y main.dart.
      // Si falla, la causa #1 es que setupServiceLocator() no se llamó.
      setupServiceLocator(testEnv);

      final service = TierService.getInstance();

      expect(service, isA<TierService>(),
          reason: 'getInstance() debe devolver una instancia de TierService');
    });

    test('registra PasswordRecoveryListener en GetIt (HDU-007, red de '
        'seguridad del deep link de reset password)', () {
      // Pre-condición: NO registrado.
      expect(getIt.isRegistered<PasswordRecoveryListener>(), isFalse);

      setupServiceLocator(testEnv);

      // Después de setupServiceLocator, SÍ está registrado.
      expect(getIt.isRegistered<PasswordRecoveryListener>(), isTrue,
          reason: 'PasswordRecoveryListener debe estar registrado (HDU-007) '
              '— sin esto, el deep link de reset password puede dejar al '
              'user con sesión temporal pero sin pantalla de reset');
    });
  });

  // HDU-007: el listener de `passwordRecovery` es la red de seguridad
  // del deep link de reset password. Si el listener NO está bien
  // cableado, el user queda con sesión temporal pero sin pantalla de
  // reset. Este test verifica el wiring end-to-end:
  //
  //   1. `AuthService` fake con un `StreamController<AuthState>` controlado.
  //   2. `setupServiceLocator(testEnv)` registra los singletons lazy.
  //   3. `getIt<PasswordRecoveryListener>()` dispara la factory.
  //   4. `getIt<GoRouter>()` dispara la factory del router (usa el
  //      `AuthService` fake, no Supabase real).
  //   5. Envolvemos el router en `MaterialApp.router` y hacemos
  //      `pumpWidget` (sin esto, `routerDelegate.currentConfiguration`
  //      queda vacío hasta el primer build).
  //   6. Emitimos `AuthChangeEvent.passwordRecovery` desde el controller.
  //   7. Verificamos que el router navegó a `/auth/reset-password`.
  //
  // **Por qué pre-registramos el `AuthService` fake con
  // `registerSingleton` (no con `setupServiceLocator`):** si dejáramos
  // que el factory de `AuthService` corriera, su default
  // `_defaultAuthStateChange` pegaría a
  // `Supabase.instance.client.auth.onAuthStateChange` y crashearía
  // con "You must initialize the supabase instance". Pre-registrar
  // el fake evita esa ruta y mantiene el test aislado.
  //
  // **Por qué usamos `buildAppRouter` directo (no `getIt<GoRouter>()`):**
  // `getIt<GoRouter>()` reusa el singleton lazy, pero queremos un
  // router con la ruta `/auth/reset-password` que `buildAppRouter`
  // declara. El factory de `service_locator` usa `buildAppRouter`
  // también, así que el comportamiento bajo test es el mismo.
  group('PasswordRecoveryListener (HDU-007 — red de seguridad)', () {
    late StreamController<sb.AuthState> authStateController;
    late AuthService fakeAuth;

    setUp(() {
      authStateController = StreamController<sb.AuthState>.broadcast();
      addTearDown(authStateController.close);

      fakeAuth = _FakeAuthServiceForListener(
        authStateStream: authStateController.stream,
      );

      // Pre-registramos el fake ANTES de `setupServiceLocator` para
      // que la factory de `AuthService` no se dispare (usaría
      // Supabase real y crashearía el test).
      getIt.registerSingleton<AuthService>(fakeAuth);
      getIt.registerSingleton<GoogleSignInHandler>(
        const GoogleSignInHandler(),
      );
    });

    testWidgets('emite passwordRecovery → router navega a '
        '/auth/reset-password', (tester) async {
      setupServiceLocator(testEnv);

      // Disparar la factory del listener (necesita el router ya
      // creado).
      getIt<PasswordRecoveryListener>();
      final router = getIt<GoRouter>();

      // Montar el router para que `routerDelegate.currentConfiguration`
      // refleje la ruta actual. Sin esto, el delegate queda en estado
      // vacío y el `expect` falla con `Actual: ''`.
      //
      // **Por qué el `BlocProvider<SplashCubit>`:** la ruta
      // `/splash` renderiza `SplashScreen`, que requiere un
      // `SplashCubit` accesible. En `main.dart` se provee a nivel
      // de app; aquí replicamos el patrón. Si no, el primer build
      // tira `ProviderNotFoundException`.
      await tester.pumpWidget(
        BlocProvider<SplashCubit>(
          create: (_) => SplashCubit(),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      // Pre-condición: el router empieza en /splash (initialLocation
      // por default).
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/splash',
        reason: 'pre-condición: initialLocation default es /splash',
      );

      // Simulamos que Supabase procesó el token de reset password y
      // emitió el evento `passwordRecovery` con sesión temporal.
      authStateController.add(
        const sb.AuthState(sb.AuthChangeEvent.passwordRecovery, null),
      );
      // Damos tiempo a que el listener procese el evento y al router
      // a actualizar su estado.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/auth/reset-password',
        reason: 'Cuando Supabase emite passwordRecovery, el listener debe '
            'navegar a /auth/reset-password (HDU-007, AC8). Sin este '
            'wiring, el deep link puede dejar al user con sesión '
            'temporal pero sin pantalla de reset.',
      );
    });

    testWidgets('otro evento (signedIn) NO navega al reset password',
        (tester) async {
      // Cobertura de "el listener filtra correctamente": solo
      // `passwordRecovery` debe navegar. Otros eventos (signedIn,
      // signedOut, etc.) deben ser ignorados.
      setupServiceLocator(testEnv);
      getIt<PasswordRecoveryListener>();
      final router = getIt<GoRouter>();

      await tester.pumpWidget(
        BlocProvider<SplashCubit>(
          create: (_) => SplashCubit(),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      authStateController.add(
        const sb.AuthState(sb.AuthChangeEvent.signedIn, null),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/splash',
        reason: 'El listener SOLO navega a /auth/reset-password cuando '
            'el evento es passwordRecovery. signedIn (u otros) deben '
            'ser ignorados.',
      );
    });

    test('reset() llama onDispose del listener y cancela la suscripción',
        () async {
      // El listener implementa `Disposable` para que `getIt.reset()`
      // (en `tearDown` de los tests) cancele la suscripción. Esta
      // cobertura evita que un cambio futuro a un patrón "fire and
      // forget" (sin `Disposable`) pase desapercibido: la
      // cancelación explícita es lo que mantiene los tests aislados.
      setupServiceLocator(testEnv);
      getIt<PasswordRecoveryListener>();

      // Pre-condición: registrado.
      expect(getIt.isRegistered<PasswordRecoveryListener>(), isTrue);

      // El reset es async — `getIt.reset()` invoca `onDispose()` y
      // luego desregistra.
      await getIt.reset();

      expect(getIt.isRegistered<PasswordRecoveryListener>(), isFalse,
          reason: 'reset() debe desregistrar el listener (HDU-007)');
    });
  });

  // Housekeeping bundle #4, follow-up #9: el helper
  // `registerLazySingletonIfNotRegistered` centraliza el patrón
  // idempotente de `setupServiceLocator`. Estos tests cubren su
  // contrato explícitamente.
  group('registerLazySingletonIfNotRegistered()', () {
    test('registra el tipo si NO está registrado', () {
      // Pre-condición: tipo custom NO registrado.
      expect(getIt.isRegistered<_SampleService>(), isFalse);

      registerLazySingletonIfNotRegistered<_SampleService>(
        () => _SampleService(label: 'primera'),
      );

      expect(getIt.isRegistered<_SampleService>(), isTrue);
      expect(getIt<_SampleService>().label, 'primera',
          reason: 'el factory debe invocarse en el primer registro');
    });

    test('NO re-registra si el tipo YA está registrado (idempotente)', () {
      registerLazySingletonIfNotRegistered<_SampleService>(
        () => _SampleService(label: 'primera'),
      );
      final original = getIt<_SampleService>();

      // Segundo intento con factory diferente. NO debe sobrescribir.
      registerLazySingletonIfNotRegistered<_SampleService>(
        () => _SampleService(label: 'segunda'),
      );

      expect(identical(getIt<_SampleService>(), original), isTrue,
          reason: 'el helper es idempotente: el segundo call es no-op, '
              'no se reemplaza el singleton original');
      expect(getIt<_SampleService>().label, 'primera',
          reason: 'el factory "segunda" NUNCA debe invocarse');
    });

    test('NO lanza si el tipo ya está registrado (a diferencia de '
        'registerLazySingleton directo)', () {
      registerLazySingletonIfNotRegistered<_SampleService>(
        () => _SampleService(label: 'a'),
      );

      // El segundo call no debe lanzar (a diferencia de
      // `getIt.registerLazySingleton` que SÍ lanza).
      expect(
        () => registerLazySingletonIfNotRegistered<_SampleService>(
          () => _SampleService(label: 'b'),
        ),
        returnsNormally,
      );
    });
  });
}

/// Tipo custom solo para los tests del helper. No se usa en la app.
class _SampleService {
  _SampleService({required this.label});
  final String label;
}

/// Fake de `AuthService` para el test del listener de
/// `passwordRecovery` (HDU-007). Devuelve un stream controlado
/// desde el constructor; los demás métodos lanzan `AuthException`
/// (no se usan en estos tests, pero `implements AuthService` los
/// exige).
///
/// **Por qué este fake es local a `service_locator_test.dart` y NO
/// se reutiliza desde `auth_service_test.dart`:** la suite de
/// `auth_service` tiene su propio `_SupabaseStubs` (con stubs de
/// `signUp`, `signIn`, etc. + `StreamController` opcional). Mover
/// ese helper a un archivo compartido obligaría a importar Supabase
/// y los typedefs desde muchos tests; aquí solo necesitamos lo
/// mínimo (un stream inyectable + "no usado" para el resto).
class _FakeAuthServiceForListener implements AuthService {
  _FakeAuthServiceForListener({required Stream<sb.AuthState> authStateStream})
      : _authStateStream = authStateStream;

  final Stream<sb.AuthState> _authStateStream;

  @override
  Stream<sb.AuthState> get authStateChanges => _authStateStream;

  @override
  sb.Session? getCurrentSession() => null;

  @override
  String? get currentUserId => null;

  @override
  Future<sb.AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? emailRedirectTo,
  }) async =>
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in service_locator_test',
      );

  @override
  Future<sb.AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in service_locator_test',
      );

  @override
  Future<sb.AuthResponse> signInWithGoogle() async =>
      throw const AuthException(
        kind: AuthErrorKind.unknown,
        message: 'not used in service_locator_test',
      );

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resetPasswordForEmail({required String email}) async {
    throw const AuthException(
      kind: AuthErrorKind.unknown,
      message: 'not used in service_locator_test',
    );
  }

  @override
  Future<sb.UserResponse> updateUserPassword({
    required String newPassword,
  }) async {
    throw const AuthException(
      kind: AuthErrorKind.unknown,
      message: 'not used in service_locator_test',
    );
  }
}
