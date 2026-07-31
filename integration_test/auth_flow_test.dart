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

import 'package:zeiki/core/router/app_router.dart';
import 'package:zeiki/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // El test runner de integration_test NO llama a `main()` por su
  // cuenta. La forma estándar es montar `ZeikiApp` con un router
  // construido aquí. El `setupServiceLocator` también lo llamamos
  // aquí para que `getIt<GoRouter>()` y `getIt<AuthService>()`
  // estén disponibles.
  //
  // **IMPORTANTE:** este test asume que `assets/.env` tiene
  // `SUPABASE_URL` y `SUPABASE_ANON_KEY` reales. Sin eso, la app
  // crashea al `initSupabase`. Para QA sin device, usar `flutter run`
  // directamente (donde `main()` se llama completo).
  setUpAll(() {
    // El setup de GetIt ya se hace en `main()` cuando se corre con
    // `flutter run`. En el integration test runner, lo hacemos aquí
    // — pero `initSupabase` requiere que `assets/.env` esté cargado,
    // lo cual es responsabilidad del operador (Hugo).
    // setupServiceLocator();
  });

  testWidgets('AC25: cold start sin sesión termina en /splash o /login',
      (WidgetTester tester) async {
    final router = buildAppRouter(
      // El AuthService real no está disponible en el test runner
      // sin `initSupabase`. Para este smoke test, basta con que el
      // redirect reciba un getter que devuelva `null` siempre.
      authServiceGetter: () => throw _NoAuthServiceAvailable(),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(ZeikiApp(router: router));
    await tester.pumpAndSettle();

    final currentPath =
        router.routerDelegate.currentConfiguration.uri.path;
    // Sin sesión y sin la posibilidad de obtenerla, el redirect
    // manda a /login (cualquier ruta que no sea /splash ni
    // /onboarding redirige a /login cuando no hay sesión).
    expect(currentPath, isIn(<String>{'/splash', '/login'}),
        reason: 'cold start sin sesión debe terminar en /splash o /login');
  });

  testWidgets('AC14, AC15: pantalla /login tiene ambos métodos de auth',
      (WidgetTester tester) async {
    final router = buildAppRouter(
      authServiceGetter: () => throw _NoAuthServiceAvailable(),
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
      authServiceGetter: () => throw _NoAuthServiceAvailable(),
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

/// Excepción interna del test para señalar que el AuthService real
/// no está disponible en el integration test runner sin `initSupabase`.
class _NoAuthServiceAvailable implements Exception {
  @override
  String toString() => 'NoAuthServiceAvailable';
}
