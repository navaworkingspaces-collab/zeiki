// Smoke test mínimo para HDU-001.
// Verifica que la app arranca y muestra el placeholder "Zeiki — base del proyecto".
// Criticidad: baja (matriz §11 de Target Architecture). Solo confirma que el
// harness de Flutter funciona; no valida flujos de negocio (esos llegan en HDUs
// de feature).
import 'package:flutter_test/flutter_test.dart';
import 'package:zeiki/main.dart';

void main() {
  testWidgets('app arranca y muestra el placeholder de HDU-001', (
    WidgetTester tester,
  ) async {
    // Act: arranca la app
    await tester.pumpWidget(const ZeikiApp());

    // Assert: el placeholder es visible
    expect(find.text('Zeiki — base del proyecto'), findsOneWidget);
  });
}
