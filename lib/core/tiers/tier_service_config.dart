// Config inmutable de `TierService` (spec HDU-003 AC6).
//
// Se construye una vez en `main()` y se pasa a `TierService.initialize()`.
// Inmutable: una vez construida, no se puede cambiar. Esto evita que
// código de UI o de features mute el refreshInterval o los overrides
// después de iniciada la app.
import 'app_feature.dart';

class TierServiceConfig {
  const TierServiceConfig({
    this.refreshInterval = const Duration(minutes: 15),
    this.debugOverrides = const <AppFeature, bool>{},
    this.debugEnabled = false,
  });

  /// Cada cuánto el `TierService` (en versiones futuras, con
  /// `Timer.periodic`) refresca el cache desde la edge function.
  ///
  /// En HDU-003 NO se usa el timer — el refresh es pull-based (el
  /// consumidor llama `refresh()` cuando lo necesita). Se deja
  /// declarado para que HDU futura (probablemente la de "configuración
  /// de refresh" en Configuración del usuario) lo conecte sin breaking
  /// change.
  final Duration refreshInterval;

  /// Mapa de overrides para QA/dev: fuerza el valor de un feature sin
  /// importar lo que diga la edge function. Solo aplica si
  /// [debugEnabled] es `true`. NO se persiste — solo vive durante la
  /// ejecución de la app.
  ///
  /// Ejemplo de uso: QA quiere probar el flujo "splash deshabilitado"
  /// sin tocar la BD.
  final Map<AppFeature, bool> debugOverrides;

  /// Si es `true`, los overrides de [debugOverrides] tienen prioridad
  /// sobre el cache. Si es `false`, los overrides se ignoran.
  /// Por defecto `false` — los overrides son explícitos, no implícitos.
  final bool debugEnabled;
}
