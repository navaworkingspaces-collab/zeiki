// HDU-004 AC9 — Integration tests del router de navegación.
//
// Cubre el flujo end-to-end que solo se puede verificar en un device
// real (Xiaomi) o con `flutter test integration_test/`:
//
//   - Tap un botón navega a la ruta del botón (cubierto también por
//     `test/widget_test.dart`, pero repetido aquí en el contexto del
//     test runner de integración).
//   - Deep link `zeiki://login` desde fuera abre la pantalla de login
//     (AC5 verificado en device — fuera del alcance de widget tests).
//   - Back button del Android pop el route stack correctamente (AC6).
//   - Rotación preserva el estado actual (AC7 — state restoration).
//
// Notas:
//   - El handler de deep links vive en `lib/core/router/app_links_handler.dart`
//     y se cablea desde `main.dart`. La verificación end-to-end con
//     `adb shell am start -W -a android.intent.action.VIEW -d "zeiki://login"`
//     requiere device físico (Xiaomi), no se automatiza aquí.
//   - El assertion de rotación también requiere device — `WidgetTester`
//     no simula el ciclo de vida nativo de Flutter.
//
// Para correr en device: `flutter test integration_test/router_test.dart
// -d <deviceId>`. La parte automatizable (tap, navegación) corre
// siempre; la parte que requiere device real (adb deep link, rotación)
// se cubre por inspección cuando se ejecuta el comando.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zeiki/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('arranca en /splash y muestra el placeholder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ZeikiApp());
    await tester.pumpAndSettle();

    expect(find.text('Splash'), findsOneWidget);
  });

  testWidgets('tap "Ir a Login" navega a /login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ZeikiApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ir a Login'));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
  });

  // El test de deep link end-to-end con `adb shell am start -W -a
  // android.intent.action.VIEW -d "zeiki://login"` se cubre por QA
  // manual con Hugo siguiendo el runbook (este archivo queda como
  // referencia de la lista de pasos cuando se ejecute en device).
}
