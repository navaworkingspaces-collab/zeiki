// Router declarativo de Zeiki (HDU-004 base, HDU-005 extiende, HDU-005b
// biometría + unlock, HDU-006 splash real).
import 'dart:async';
//
// Cambios de HDU-005:
//   - **Decisión A (review de HDU-004):** `appRouter` deja de ser una
//     variable global mutable y pasa a ser una factory
//     `buildAppRouter(authService: ...)`. Se registra en GetIt como
//     singleton lazy (`service_locator.dart`). El redirect necesita
//     consultar `AuthService.currentSession` — sin GetIt, no había
//     forma limpia de inyectarlo.
//   - **Redirect global (AC24, AC25):** decide a dónde va el usuario
//     antes de cada navegación. La lógica se aísla en
//     `computeAuthRedirect({goingTo, isLoggedIn})` para poder
//     testearla sin widget tree.
//   - **Nueva ruta `/register` (AC4):** la pantalla de register vive
//     en `lib/features/identidad/screens/register_screen.dart`.
//
// Cambios de HDU-005b (esta HDU):
//   - **Nueva ruta `/unlock` (AC15):** la pantalla
//     `UnlockScreen` se muestra cuando el cold start tiene sesión
//     persistida Y `biometricEnabled` para ese userId. Pide huella
//     antes de dejar pasar al usuario a /home.
//   - **`refreshStream` finalmente se conecta (AC22-24):** el
//     `GoRouterRefreshStream` que HDU-005 dejó construido se conecta
//     al `authStateChanges` del `AuthService`. Resultado: `signOut`
//     desde cualquier pantalla hace que el router re-evalúe el
//     `redirect` automáticamente (sin tocar la pantalla).
//
// Cambios de HDU-006 (esta HDU):
//   - **Splash real:** la ruta `/splash` ya no renderiza
//     `SplashPlaceholder` (andamio de HDU-004) sino `SplashScreen`.
//     El widget se envuelve en `BlocProvider<SplashCubit>` para que la
//     máquina de estados del splash (loading → ready → hidden) sea
//     inyectable y testeable.
//
// **Por qué el redirect NO consulta biometricEnabled:** el redirect
// aplica a CADA navegación, no solo al cold start. Si el user está
// en /home, hace logout, y va a /login, el redirect NO debe
// re-mandarlo a /unlock (eso causaría un loop). La decisión de
// "mostrar /unlock en el cold start" se toma UNA vez al construir
// el router (en `service_locator.dart`); después, el UnlockScreen
// mismo decide a dónde ir (éxito → /home, fallo 3x → /login).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../../features/identidad/blocs/splash_cubit.dart';
import '../../features/identidad/screens/home_screen.dart';
import '../../features/identidad/screens/login_screen.dart';
import '../../features/identidad/screens/register_screen.dart';
import '../../features/identidad/screens/splash_screen.dart';
import '../../features/identidad/screens/unlock_screen.dart';
import 'screens/onboarding_placeholder.dart';

/// Rutas declaradas por el router. El `.path` es lo que se usa en
/// `context.go(...)` y en `findMatch(route: ...)`.
///
/// **HDU-005** agregó `register`. **HDU-005b** agrega `unlock` para el
/// cold start con sesión + biometría habilitada.
enum AppRoute {
  splash('/splash'),
  onboarding('/onboarding'),
  login('/login'),
  register('/register'),
  unlock('/unlock'),
  home('/home');

  const AppRoute(this.path);

  final String path;
}

/// Lógica pura de redirect. Se exporta para que los tests la cubran
/// sin montar un widget tree (conventions §3: unit test cuando el
/// comportamiento es puro).
///
/// **Reglas (AC24, HDU-005b):**
///   - `/splash`, `/onboarding` → nunca redirigen (públicas).
///   - `/login`, `/register`    → redirigen a `/home` si hay sesión.
///   - `/unlock`                → terminal; el `UnlockScreen`
///                                decide internamente.
///   - Rutas privadas (`/home` y futuras) sin sesión → `/login`.
///
/// **No hay loops infinitos:** el `redirect` de `go_router` deja de
/// llamar a la función cuando el resultado es `null`. Las reglas
/// anteriores garantizan que `/login` sin sesión, `/home` con sesión,
/// y `/unlock` siempre son terminales.
String? computeAuthRedirect({
  required String goingTo,
  required bool isLoggedIn,
}) {
  if (goingTo == AppRoute.splash.path ||
      goingTo == AppRoute.onboarding.path) {
    return null;
  }
  if (goingTo == AppRoute.login.path || goingTo == AppRoute.register.path) {
    return isLoggedIn ? AppRoute.home.path : null;
  }
  if (goingTo == AppRoute.unlock.path) {
    // El UnlockScreen decide internamente; no redirigimos.
    return null;
  }
  // Rutas privadas (incluyendo /home y futuras como /fiscal).
  if (!isLoggedIn) {
    return AppRoute.login.path;
  }
  return null;
}

/// Construye el `GoRouter` de Zeiki. Se llama desde
/// `service_locator.dart` (registro lazy) o desde los tests con
/// `AuthService` y `BiometricService` fakes.
///
/// `authServiceGetter` es una **función** que devuelve el
/// `AuthService` actual. El redirect la llama en cada navegación para
/// leer la sesión. Esto permite que los tests reemplacen el
/// `AuthService` en `getIt` sin tener que reconstruir el router
/// (conventions §3).
///
/// `refreshStream` se conecta al `authStateChanges` para que el
/// router re-evalúe el `redirect` cuando el user hace signOut (sin
/// esperar la próxima navegación). Por default es null — el redirect
/// corre en cada navegación, que es suficiente para MVP (HDU-005b
/// ya lo conecta en `service_locator.dart`).
///
/// `initialLocation` permite que `service_locator.dart` elija `/unlock`
/// como punto de partida en el cold start cuando hay sesión +
/// biometría habilitada. Default: `/splash`.
///
/// `splashCubit` (HDU-006): si se pasa, el `BlocProvider` de la
/// ruta `/splash` envuelve el Cubit pasado (en vez de crear uno
/// nuevo). Esto permite que los tests inyecten un Cubit controlado
/// sin tener que `pumpAndSettle` para esperar las animaciones. En
/// producción se deja null y se crea uno nuevo.
GoRouter buildAppRouter({
  required AuthService Function() authServiceGetter,
  Stream<void>? refreshStream,
  String initialLocation = '/splash',
  SplashCubit? splashCubit,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.splash.path,
        // El `BlocProvider<SplashCubit>` se provee aquí solo si el
        // router recibió un Cubit inyectado (vía `splashCubit:`).
        // En producción NO se pasa (el router solo enruta) y el
        // Cubit se provee en `main.dart` con un `BlocProvider` de
        // app-level. En tests se pasa para inyectar un Cubit
        // controlado.
        builder: (BuildContext context, GoRouterState state) {
          if (splashCubit != null) {
            return BlocProvider<SplashCubit>.value(
              value: splashCubit,
              child: const SplashScreen(),
            );
          }
          return const SplashScreen();
        },
      ),
      GoRoute(
        path: AppRoute.onboarding.path,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingPlaceholder(),
      ),
      GoRoute(
        path: AppRoute.login.path,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: AppRoute.register.path,
        builder: (BuildContext context, GoRouterState state) =>
            const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoute.unlock.path,
        builder: (BuildContext context, GoRouterState state) =>
            const UnlockScreen(),
      ),
      GoRoute(
        path: AppRoute.home.path,
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(),
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final session = authServiceGetter().getCurrentSession();
      return computeAuthRedirect(
        goingTo: state.matchedLocation,
        isLoggedIn: session != null,
      );
    },
    refreshListenable: refreshStream == null
        ? null
        : GoRouterRefreshStream(refreshStream),
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      appBar: AppBar(title: const Text('Zeiki')),
      body: Center(
        child: Text('Ruta no encontrada: ${state.uri}'),
      ),
    ),
  );
}

/// Adaptador de un `Stream<void>` a `Listenable` para que `go_router`
/// pueda re-evaluar el `redirect` cuando el stream emita.
///
/// **Por qué existe:** `go_router.refreshListenable` espera un
/// `Listenable`. Sin este adapter, no podríamos conectar un stream de
/// cambios de sesión al router. **HDU-005b** lo conecta por fin al
/// `authStateChanges` del `AuthService` (AC22).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<void> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
        );
  }

  late final StreamSubscription<void> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
