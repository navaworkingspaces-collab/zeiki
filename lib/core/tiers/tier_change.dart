// Tipo del stream `changes` de `TierService` (spec HDU-003 paso 4 del plan
// técnico).
//
// Se emite cada vez que el valor de un feature cambia en el cache
// (después de un refresh exitoso, o por un override de debug).
import 'app_feature.dart';

/// Origen del cambio. Útil para que la UI decida cómo reaccionar:
/// un cambio por `remote` puede disparar telemetría, un cambio por
/// `debugOverride` se loguea como warning en QA, un `reset` (no usado
/// en HDU-003, reservado para HDUs futuras que agreguen "reset cache")
/// se trata distinto.
enum ChangeSource {
  /// Cambio causado por un refresh desde la edge function.
  remote,

  /// Cambio forzado por un override de debug (solo en dev/QA).
  debugOverride,

  /// Cache reseteado a vacío. Reservado para uso futuro (ej. logout).
  reset,
}

class TierChange {
  const TierChange({
    required this.feature,
    required this.newValue,
    required this.source,
  });

  final AppFeature feature;
  final bool newValue;
  final ChangeSource source;

  @override
  String toString() =>
      'TierChange(${feature.name} → $newValue, source: ${source.name})';
}
