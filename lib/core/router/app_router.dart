// Router declarativo de Zeiki (HDU-004).
//
// Mapa de rutas planas (sin ShellRoute, sin redirect, sin guards —
// eso llega en HDU-005/006). La ruta inicial es `/splash` para que
// la app pase por la pantalla de splash antes de decidir a dónde ir.
//
// Las 4 pantallas son placeholders en `lib/core/router/screens/` y
// se migrarán a `lib/features/<dominio>/` cuando cada una tenga
// contenido real (spec §Notas / "Fuera de scope").
//
// El enum `AppRoute` existe para evitar strings sueltos de rutas en
// el código de feature (conventions §1: "nombres describen intención,
// no implementación"). Usar `context.go(AppRoute.login.path)` en vez
// de `context.go('/login')`.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/home_placeholder.dart';
import 'screens/login_placeholder.dart';
import 'screens/onboarding_placeholder.dart';
import 'screens/splash_placeholder.dart';

/// Rutas declaradas por el router. El `.path` es lo que se usa en
/// `context.go(...)` y en `findMatch(route: ...)`.
enum AppRoute {
  splash('/splash'),
  onboarding('/onboarding'),
  login('/login'),
  home('/home');

  const AppRoute(this.path);

  final String path;
}

/// Router global. Se inyecta al `MaterialApp.router(routerConfig: ...)`
/// en `lib/main.dart`.
///
/// `errorBuilder` muestra un fallback cuando un deep link apunta a una
/// ruta que no existe (ej. `zeiki://configuracion-borrada`). Sin esto,
/// `go_router` muestra un widget rojo en debug y un `Scaffold` vacío
/// en release.
final GoRouter appRouter = GoRouter(
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
          const LoginPlaceholder(),
    ),
    GoRoute(
      path: AppRoute.home.path,
      builder: (BuildContext context, GoRouterState state) =>
          const HomePlaceholder(),
    ),
  ],
  errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
    appBar: AppBar(title: const Text('Zeiki')),
    body: Center(
      child: Text('Ruta no encontrada: ${state.uri}'),
    ),
  ),
);
