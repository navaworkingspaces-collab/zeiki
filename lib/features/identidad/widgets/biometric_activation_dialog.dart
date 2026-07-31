// Helper one-shot + Dialog de activación de biometría (HDU-005b, AC5-AC9, AC28).
//
// `BiometricActivationService` mantiene un flag en memoria
// (one-shot por sesión) que decide si se muestra el popup después
// del register/login exitoso.
//
// `BiometricActivationDialog` es el widget `AlertDialog` modal con el
// texto y los 2 botones del spec (AC5).
//
// **Por qué un helper aparte del BiometricService:** el `BiometricService`
// solo conoce el flag persistente (secure storage). El "ya se mostró
// este login" es estado de UI que no debe persistirse entre cierres
// de app (si el user cierra y reabre, el popup vuelve a salir — AC8).
// Lo más limpio es un Set<String> en memoria que se destruye al
// cerrar la app.
import 'package:flutter/material.dart';

import '../../../core/services/biometric_service.dart';

/// Servicio que decide si mostrar el popup de "¿Activar huella?"
/// después del register/login (HDU-005b, AC7, AC8).
///
/// **Reglas (consumidas en orden):**
///  1. Si ya se mostró en esta sesión para este userId → `false`.
///  2. Si el dispositivo no tiene biometría disponible → `false`.
///  3. Si el usuario YA activó biometría antes → `false`.
///  4. Si no, → `true` y marca como mostrado.
///
/// El "marcar como mostrado" es interno a `consumeIfShouldShow` (no
/// hay `markShown` público) — es consume semantics atómico: la
/// primera llamada devuelve `true` y siguientes `false`.
class BiometricActivationService {
  BiometricActivationService({BiometricService? biometric})
      : _biometric = biometric;

  final BiometricService? _biometric;

  /// Set de userIds a los que ya se les mostró el popup en esta
  /// sesión. Vive en memoria; se resetea al cerrar la app (el
  /// singleton de GetIt se destruye).
  final Set<String> _shownForUsers = <String>{};

  /// Devuelve `true` si el popup debe mostrarse para este userId.
  /// Después de devolver `true`, el `userId` queda marcado y
  /// siguientes llamadas devuelven `false`.
  Future<bool> consumeIfShouldShow({required String userId}) async {
    if (_shownForUsers.contains(userId)) return false;
    final biometric = _biometric;
    if (biometric == null) return false;
    if (!await biometric.isBiometricAvailable()) return false;
    if (await biometric.isBiometricEnabled(userId: userId)) return false;
    _shownForUsers.add(userId);
    return true;
  }
}

/// Dialog modal de "¿Activar huella?" (HDU-005b, AC5-AC7, AC28).
///
/// **Texto exacto:** "El popup tiene 2 botones: 'Activar' y
/// 'Ahora no'." — copiado literal del spec (cualquier cambio de
/// wording requiere actualizar el spec y el test de render).
///
/// **Flujo del botón "Activar" (AC6):**
///  1. Llama a `biometric.authenticate('Activar biometría para Zeiki')`.
///  2. Si pasa → `setBiometricEnabled(true)` y cierra.
///  3. Si falla o cancela → cierra sin guardar.
class BiometricActivationDialog extends StatelessWidget {
  const BiometricActivationDialog({
    super.key,
    required this.biometric,
    required this.userId,
  });

  final BiometricService biometric;
  final String userId;

  Future<void> _onActivate(BuildContext context) async {
    final ok = await biometric.authenticate('Activar biometría para Zeiki');
    if (ok) {
      await biometric.setBiometricEnabled(true, userId: userId);
    }
    if (context.mounted) {
      Navigator.of(context).pop(ok);
    }
  }

  void _onDismiss(BuildContext context) {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Título corto para que el dialog se vea como un prompt, no
      // como un modal de información. El contenido principal es el
      // body.
      title: const Text('Activar huella'),
      content: const Text(
        '¿Quieres usar tu huella para entrar más rápido la próxima vez?',
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('biometric_activation_dismiss'),
          onPressed: () => _onDismiss(context),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          key: const Key('biometric_activation_accept'),
          onPressed: () => _onActivate(context),
          child: const Text('Activar'),
        ),
      ],
    );
  }
}
