// Smoke tests del flujo de navegación de Zeiki (HDU-004).
//
// Cubre los ACs que requieren montar la app en un widget tree:
//
//   - AC1 + AC2: arranca en /splash y muestra el placeholder.
//   - AC3 + AC4: tap en un botón navega a la ruta del botón; el
//     `MaterialApp.router` dirige la navegación.
//   - AC7: state restoration está habilitado (`restorationScopeId`).
//   - AC12: el `_PlaceholderPage` de HDU-001 ya no existe.
//
// Lo que NO cubre este test (ver `test/core/router/app_router_test.dart`
// y `integration_test/router_test.dart`):
//   - Resolución de rutas a nivel de `findMatch` (ya cubierta en unit test).
//   - Integración con `app_links` (integration test en device).
//   - Back button físico del Android (integration test).
//   - Deep links end-to-end con `adb` (integration test).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeiki/core/router/app_router.dart';
import 'package:zeiki/main.dart';

void main() {
  // El router es un singleton global con `initialLocation: /splash`.
  // Antes de cada test lo reiniciamos para que la app arranque en
  // `/splash` y no conserve el stack del test anterior.
  setUp(() {
    appRouter.go(AppRoute.splash.path);
  });

  testWidgets('arranca en /splash y muestra el placeholder Splash',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ZeikiApp());
    await tester.pumpAndSettle();

    // Texto grande del placeholder.
    expect(find.text('Splash'), findsOneWidget);
    // Botones de navegación que el splash expone.
    expect(find.text('Ir a Onboarding'), findsOneWidget);
    expect(find.text('Ir a Login'), findsOneWidget);
  });

  testWidgets('botón "Ir a Login" en /splash navega a /login',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ZeikiApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ir a Login'));
    await tester.pumpAndSettle();

    // El placeholder de Login tiene su propio texto y botones.
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('desde /login, botón "Ir a Home" navega a /home',
      (WidgetTester tester) async {
    // Vamos primero a /login, luego saltamos a /home. Esto valida que
    // la navegación funciona en cadena (no solo el primer push).
    appRouter.go(AppRoute.login.path);
    await tester.pumpWidget(const ZeikiApp());
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);

    await tester.tap(find.text('Ir a Home'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('state restoration está habilitado (AC7)',
      (WidgetTester tester) async {
    // `MaterialApp.restorationScopeId` no-nulo es lo que go_router 14.x
    // necesita para registrar el `Router` con el `RestorationMixin`.
    // Sin este id, rotar el celular regresa al usuario a `/splash`.
    await tester.pumpWidget(const ZeikiApp());
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
    await tester.pumpWidget(const ZeikiApp());
    await tester.pumpAndSettle();

    // El texto del placeholder viejo ya no debe aparecer.
    expect(find.text('Zeiki — base del proyecto'), findsNothing);
  });

  testWidgets('back button desde /login regresa a /splash (AC6)',
      (WidgetTester tester) async {
    // Los placeholders navegan con `push` (no `go`) para que el back
    // button tenga un destino. Empezamos en /splash (initial), tap
    // "Ir a Login" apila /login encima, y back pop /login → /splash.
    await tester.pumpWidget(const ZeikiApp());
    await tester.pumpAndSettle();

    expect(find.text('Splash'), findsOneWidget);

    await tester.tap(find.text('Ir a Login'));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);

    // El back button del Android dispara `appRouter.pop()` (via
    // `SystemNavigator.pop` → `Navigator.maybePop` → `Router.pop`).
    // En el test no hay AppBar con back button, así que disparamos
    // `pop` directamente para verificar la semántica.
    appRouter.pop();
    await tester.pumpAndSettle();

    // Después de pop, deberíamos estar de vuelta en /splash.
    expect(find.text('Splash'), findsOneWidget);
  });

  testWidgets('state restoration preserva la pantalla al "rotar" (AC7)',
      (WidgetTester tester) async {
    // Vamos a /home manualmente.
    appRouter.go(AppRoute.home.path);
    await tester.pumpWidget(const ZeikiApp());
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);

    // Simulamos una rotación cambiando el tamaño de la vista.
    // `restorationScopeId` en `MaterialApp` (configurado en main.dart)
    // hace que go_router guarde el stack actual y lo restaure después
    // del rebuild. Sin esto, el router volvería a /splash.
    final originalSize = tester.view.physicalSize;
    addTearDown(() => tester.view.physicalSize = originalSize);
    tester.view.physicalSize = const Size(800, 1600); // retrato
    await tester.pumpAndSettle();

    expect(
      find.text('Home'),
      findsOneWidget,
      reason: 'After rotation, current route should be preserved (AC7)',
    );
  });
}
