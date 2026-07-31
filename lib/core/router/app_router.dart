// Router declarativo de Zeiki (HDU-004 base, HDU-005 extiende).
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
// Las 4 rutas originales de HDU-004 (`/splash`, `/onboarding`,
// `/login`, `/home`) SE MANTIENEN (AC35). Se renombran pantallas
// (login/home ahora son reales, no placeholders), pero los paths
// no cambian.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../../features/identidad/screens/home_screen.dart';
import '../../features/identidad/screens/login_screen.dart';
import '../../features/identidad/screens/register_screen.dart';
import 'screens/onboarding_placeholder.dart';
import 'screens/splash_placeholder.dart';

/// Rutas declaradas por el router. El `.path` es lo que se usa en
/// `context.go(...)` y en `findMatch(route: ...)`.
///
/// HDU-005 agregó `register`. Los otros 4 vienen de HDU-004 (AC1).
enum AppRoute {
  splash('/splash'),
  onboarding('/onboarding'),
  login('/login'),
  register('/register'),
  home('/home');

  const AppRoute(this.path);

  final String path;
}

/// Lógica pura de redirect. Se exporta para que los tests la cubran
/// sin montar un widget tree (conventions §3: unit test cuando el
/// comportamiento es puro).
///
/// Reglas (AC24):
///   - `/splash`, `/onboarding` → nunca redirigen (públicas).
///   - `/login`, `/register`    → redirigen a `/home` si hay sesión.
///   - Cualquier otra ruta     → redirigen a `/login` si NO hay sesión.
///
/// **No hay loops infinitos:** el `redirect` de `go_router` deja de
/// llamar a la función cuando el resultado es `null`. Las reglas
/// anteriores garantizan que `/login` sin sesión y `/home` con sesión
/// son terminales (devuelven `null`).
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
  return isLoggedIn ? null : AppRoute.login.path;
}

/// Construye el `GoRouter` de Zeiki. Se llama desde
/// `service_locator.dart` (registro lazy) o desde los tests con un
/// `AuthService` fake.
///
/// `authServiceGetter` es una **función** que devuelve el `AuthService`
/// actual. El redirect la llama en cada navegación para leer la
/// sesión. Esto permite que los tests reemplacen el `AuthService` en
/// `getIt` sin tener que reconstruir el router (conventions §3:
/// "los tests son más simples si el SUT se acopla al lookup, no a
/// la instancia fija").
///
/// `refreshStream` se puede pasar en tests para forzar un re-redirect
/// (ej. cuando cambia la sesión y queremos que el router reaccione
/// sin esperar la próxima navegación). Por default es null — el
/// redirect corre en cada navegación, que es suficiente para MVP.
GoRouter buildAppRouter({
  required AuthService Function() authServiceGetter,
  Stream<void>? refreshStream,
}) {
  return GoRouter(
    initialLocation: AppRoute.splash.path,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.splash.path,
        builder: (BuildContext context, GoRouterState state) =>
            const SplashPlaceholder(),
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
        path: AppRoute.home.path,
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(),
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      // El getter resuelve el AuthService en cada navegación. Esto
      // permite que el router reaccione a sign-in / sign-out sin
      // necesidad de un refreshListenable.
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
/// cambios de sesión al router (lo cual será necesario en HDU-005b
/// cuando se agregue biometría y auto-logout). Hoy se deja
/// disponible aunque `refreshStream` sea null por default.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<void> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
        );
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
