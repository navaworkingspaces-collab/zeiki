// Tests de `BiometricActivationService` y `BiometricActivationDialog`
// (HDU-005b, AC5-AC9, AC28).
//
// `BiometricActivationService` mantiene un flag en memoria
// (one-shot por sesión) que decide si se muestra el popup después
// del register/login. El flag se resetea cuando la app se cierra
// (el singleton se destruye).
//
// `BiometricActivationDialog` es el widget `AlertDialog` modal con
// el texto y los 2 botones del spec (AC5).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:zeiki/core/auth/biometric_service.dart';
import 'package:zeiki/features/identidad/widgets/biometric_activation_dialog.dart';

// ====================================================================
// Fakes (top-level)
// ====================================================================

/// Fake de `BiometricService` con control total de los métodos que
/// el dialog y el service consultan. Implementa la clase concreta
/// (no la interfaz) porque `BiometricService` es una clase no
/// abstracta con dependencias inyectadas; sin embargo, sus campos
/// son privados, así que extendemos y sobreescribimos solo lo que
/// nos importa.
class _FakeBiometricService extends BiometricService {
  _FakeBiometricService({
    this.availableResult = true,
    this.authenticateResult = true,
    this.enabledResult = false,
    this.authenticateError,
  });

  bool availableResult;
  bool authenticateResult;
  bool enabledResult;
  Object? authenticateError;
  int authenticateCalls = 0;
  int setEnabledCalls = 0;
  String? setEnabledLastUserId;
  bool? setEnabledLastValue;

  @override
  Future<bool> isBiometricAvailable() async => availableResult;

  @override
  Future<bool> authenticate(String reason) async {
    authenticateCalls++;
    // El BiometricService real captura excepciones y devuelve false.
    // El fake se comporta igual para que los tests reflejen el
    // comportamiento del código de producción.
    if (authenticateError != null) return false;
    return authenticateResult;
  }

  @override
  Future<bool> isBiometricEnabled({required String userId}) async =>
      enabledResult;

  @override
  Future<void> setBiometricEnabled(
    bool enabled, {
    required String userId,
  }) async {
    setEnabledCalls++;
    setEnabledLastUserId = userId;
    setEnabledLastValue = enabled;
  }
}

void main() {
  // ====================================================================
  // BiometricActivationService
  // ====================================================================

  group('BiometricActivationService (one-shot por sesión, AC7, AC8)', () {
    test('1ra vez por userId con biometría disponible → consume=true',
        () async {
      final biometric = _FakeBiometricService(availableResult: true);
      final service = BiometricActivationService(biometric: biometric);

      expect(
        await service.consumeIfShouldShow(userId: 'user-1'),
        isTrue,
        reason: 'primera vez por userId, con biometría → mostrar',
      );
    });

    test('2da vez por el mismo userId → consume=false (one-shot AC7)',
        () async {
      final biometric = _FakeBiometricService(availableResult: true);
      final service = BiometricActivationService(biometric: biometric);

      await service.consumeIfShouldShow(userId: 'user-1');
      expect(
        await service.consumeIfShouldShow(userId: 'user-1'),
        isFalse,
        reason: 'one-shot por sesión: el 2do consume devuelve false',
      );
    });

    test('userIds distintos se tratan como sesiones independientes', () async {
      final biometric = _FakeBiometricService(availableResult: true);
      final service = BiometricActivationService(biometric: biometric);

      // user-1 ve el popup.
      expect(await service.consumeIfShouldShow(userId: 'user-1'), isTrue);
      // user-2 también lo ve (es "otra sesión de uso" en el
      // mismo device — AC8).
      expect(await service.consumeIfShouldShow(userId: 'user-2'), isTrue,
          reason: 'AC8: distintos userIds = distintas sesiones');
    });

    test('biometría no disponible → consume=false (AC9)', () async {
      final biometric = _FakeBiometricService(availableResult: false);
      final service = BiometricActivationService(biometric: biometric);

      expect(await service.consumeIfShouldShow(userId: 'user-1'), isFalse,
          reason: 'AC9: sin biometría en el SO, no se ofrece el popup');
    });

    test('biometría YA activada para este userId → consume=false '
        '(no ofrecer algo que ya está activo)', () async {
      final biometric = _FakeBiometricService(
        availableResult: true,
        enabledResult: true,
      );
      final service = BiometricActivationService(biometric: biometric);

      expect(await service.consumeIfShouldShow(userId: 'user-1'), isFalse,
          reason: 'si ya activó biometría, el popup no aplica');
    });
  });

  // ====================================================================
  // BiometricActivationDialog (widget, AC5, AC6, AC7, AC28)
  // ====================================================================

  Future<void> pumpDialog(
    WidgetTester tester, {
    required _FakeBiometricService biometric,
    String userId = 'user-1',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BiometricActivationDialog(
            biometric: biometric,
            userId: userId,
          ),
        ),
      ),
    );
  }

  group('BiometricActivationDialog (AC5, AC6, AC7, AC28)', () {
    testWidgets('renderiza texto del spec y los 2 botones (AC5)',
        (tester) async {
      final biometric = _FakeBiometricService();
      await pumpDialog(tester, biometric: biometric);

      // Texto exacto del spec AC5.
      expect(
        find.text('¿Quieres usar tu huella para entrar más rápido la próxima vez?'),
        findsOneWidget,
      );
      // 2 botones.
      expect(find.text('Activar'), findsOneWidget);
      expect(find.text('Ahora no'), findsOneWidget);
    });

    testWidgets('"Activar" + huella válida → setBiometricEnabled(true) y '
        'cierra (AC6)', (tester) async {
      final biometric = _FakeBiometricService(authenticateResult: true);
      await pumpDialog(tester, biometric: biometric);

      await tester.tap(find.text('Activar'));
      await tester.pumpAndSettle();

      expect(biometric.authenticateCalls, 1);
      expect(biometric.setEnabledCalls, 1,
          reason: 'AC6: huella válida → setBiometricEnabled(true)');
      expect(biometric.setEnabledLastUserId, 'user-1');
      expect(biometric.setEnabledLastValue, isTrue);
      // El dialog debe estar cerrado.
      expect(find.text('Activar'), findsNothing);
    });

    testWidgets('"Activar" + huella cancelada/fallida → cierra SIN guardar '
        '(AC6, "Si falla o cancela, cierra el popup sin guardar")',
        (tester) async {
      final biometric = _FakeBiometricService(authenticateResult: false);
      await pumpDialog(tester, biometric: biometric);

      await tester.tap(find.text('Activar'));
      await tester.pumpAndSettle();

      expect(biometric.authenticateCalls, 1);
      expect(biometric.setEnabledCalls, 0,
          reason: 'si authenticate devuelve false, NO se guarda el flag');
      // El dialog está cerrado.
      expect(find.text('Activar'), findsNothing);
    });

    testWidgets('"Activar" + PlatformException → cierra SIN guardar '
        '(defensa, no propagación)', (tester) async {
      final biometric = _FakeBiometricService(
        authenticateError: Exception('PlatformException(lockout)'),
      );
      await pumpDialog(tester, biometric: biometric);

      await tester.tap(find.text('Activar'));
      await tester.pumpAndSettle();

      expect(biometric.setEnabledCalls, 0);
      expect(find.text('Activar'), findsNothing,
          reason: 'el dialog cierra aunque authenticate lance');
    });

    testWidgets('"Ahora no" → cierra SIN guardar (AC7)', (tester) async {
      final biometric = _FakeBiometricService();
      await pumpDialog(tester, biometric: biometric);

      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();

      expect(biometric.authenticateCalls, 0,
          reason: '"Ahora no" NO debe llamar a authenticate');
      expect(biometric.setEnabledCalls, 0,
          reason: '"Ahora no" NO debe guardar el flag');
      // El dialog está cerrado.
      expect(find.text('Ahora no'), findsNothing);
    });
  });

  // Evitar el warning de sb.User no usado (lo importamos para que el
  // archivo compile si en el futuro se necesita).
  // ignore: unused_local_variable
  final _ = sb.User;
}
