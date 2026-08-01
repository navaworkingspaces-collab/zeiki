// `TierService` — la pieza central del feature flag system del cliente
// (spec HDU-003, ADR-010, ADR-005).
//
// Responsabilidades:
//   - Mantener un cache local en memoria de los feature flags.
//   - Sincronizar el cache con la edge function `feature-flags` de Supabase.
//   - Exponer una API síncrona (`has()`) y una reactiva (`changes`).
//
// Patrón: state global cross-cutting (ADR-010) registrado como singleton
// lazy en GetIt (ADR-005, AC7 del spec). Se accede vía
// `TierService.getInstance()` o `getIt<TierService>()`.
//
// Importante — no usar el constructor directamente. GetIt es quien
// instancia (en `service_locator.dart`). El "fire-and-forget" del
// `refresh()` en `initialize()` se hace explícito con `unawaited(...)`
// para que el linter no se queje y para documentar la intención.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_feature.dart';
import 'tier_change.dart';
import 'tier_service_config.dart';

/// Función que el `TierService` usa para pedir los flags a la red.
/// Inyectable para que los unit tests puedan usar un fake (conventions
/// §3: preferir fakes sobre mockito). El default pega a la edge function
/// `feature-flags` de Supabase (HDU-002).
typedef FeatureFlagsFetcher = Future<Map<String, dynamic>> Function();

/// Fetch por default: llama a la edge function `feature-flags` y devuelve
/// el body parseado como `Map<String, dynamic>`.
///
/// Lanza `FormatException` si la respuesta no tiene la forma esperada.
/// El `refresh()` captura esa excepción y conserva el cache anterior.
Future<Map<String, dynamic>> _defaultFeatureFlagsFetcher() async {
  final response = await Supabase.instance.client.functions.invoke(
    'feature-flags',
  );
  final data = response.data;
  if (data is Map<String, dynamic>) return data;
  throw FormatException(
    'feature-flags: response is not a JSON object (got ${data.runtimeType})',
  );
}

class TierService {
  /// Constructor público SOLO para que `GetIt` (en
  /// `service_locator.dart`) pueda instanciar el singleton via factory.
  ///
  /// **No llamar directamente desde código de feature.** Usar
  /// `TierService.getInstance()` o `getIt<TierService>()`.
  ///
  /// `fetcher` se inyecta para tests (fake); en producción se deja null
  /// y se usa el default que pega a la edge function.
  TierService({FeatureFlagsFetcher? fetcher})
      : _fetcher = fetcher ?? _defaultFeatureFlagsFetcher;

  final FeatureFlagsFetcher _fetcher;

  /// Config inyectada en `initialize()`. Antes de eso, defaults.
  TierServiceConfig _config = const TierServiceConfig();

  /// Cache de feature flags. Inicia vacío (AC4) — la primera vez que
  /// la UI pregunta `has()` y el cache está frío, devuelve `false`
  /// (fail-safe). El `initialize()` dispara un refresh fire-and-forget
  /// que llena el cache sin bloquear el primer frame.
  final Map<AppFeature, bool> _cache = <AppFeature, bool>{};

  /// Stream broadcast para notificar cambios a quien esté suscrito
  /// (ej. widgets que invalidan cache local). Se usa
  /// `StreamController.broadcast` para que múltiples listeners no
  /// necesiten desuscribirse manualmente en orden.
  final StreamController<TierChange> _controller =
      StreamController<TierChange>.broadcast();

  /// Singleton. Consulta GetIt, que es quien mantiene la instancia única
  /// (registrada como `registerLazySingleton` en `service_locator.dart`).
  /// Antes de que `setupServiceLocator()` corra, GetIt devuelve
  /// un `TypeNotRegisteredException` — eso es OK porque `main.dart`
  /// siempre llama `setupServiceLocator()` antes que
  /// `TierService.initialize()`.
  static TierService getInstance() => GetIt.instance<TierService>();

  /// Stream que emite cada vez que un feature cambia de valor en el
  /// cache (después de un refresh exitoso o por un override de debug).
  ///
  /// Importante: NO emite cuando el valor es el mismo que ya estaba en
  /// el cache. Los listeners solo reciben cambios reales.
  Stream<TierChange> get changes => _controller.stream;

  /// Indica si el cache ya tiene datos (al menos un feature cargado).
  ///
  /// **Caso de uso (HDU-006 v3):** en la primera instalación, el cache
  /// está vacío hasta que el primer `refresh()` (fire-and-forget) complete.
  /// Las UIs que tienen un fail-safe de "mostrar por default" necesitan
  /// distinguir entre "el flag está OFF" y "todavía no sé el flag". Esta
  /// API les permite hacer esa distinción.
  ///
  /// Retorna `true` si el cache tiene al menos un feature cargado
  /// (post-refresh exitoso) o si hay un override de debug activo.
  /// Retorna `false` si el cache está frío (primera instalación, red
  /// caída, refresh aún no completa).
  bool isCacheLoaded() {
    return _cache.isNotEmpty || _config.debugEnabled;
  }

  /// Devuelve si un feature está habilitado. **Sincrónica** (AC3) —
  /// consulta el cache local en memoria, no pega a la red. Latencia
  /// < 1 ms.
  ///
  /// Fail-safe: si el feature no está en el cache (cache frío o feature
  /// desconocido), devuelve `false`. Esto evita que la UI asuma `true`
  /// por default y rompa antes de que el primer refresh llegue.
  ///
  /// El override de debug tiene prioridad sobre el cache (AC6).
  bool has(AppFeature feature) {
    if (_config.debugEnabled) {
      final override = _config.debugOverrides[feature];
      if (override != null) return override;
    }
    return _cache[feature] ?? false;
  }

  /// Setea la config y dispara un refresh en background. NO espera al
  /// refresh — la app sigue a `runApp` mientras el cache se llena
  /// (AC8: "la app NO espera a que termine el refresh inicial").
  ///
  /// El `await` está SOLO para que el call site sea `await`
  /// (consistencia con `initSupabase`), pero internamente el refresh
  /// es fire-and-forget.
  Future<void> initialize({TierServiceConfig? config}) async {
    if (config != null) _config = config;
    // Fire-and-forget: el refresh corre en background. La UI no espera.
    // `unawaited` documenta explícitamente la intención.
    unawaited(refresh());
  }

  /// Pega a la edge function y actualiza el cache.
  ///
  /// Si la llamada falla (red caída, Supabase caído, JSON inválido),
  /// se loguea un warning y **se conserva el cache anterior** (AC5).
  /// La UI no se rompe.
  ///
  /// `force` se reserva para uso futuro (HDU de "refresh manual
  /// desde configuración") — en HDU-003 no se usa, siempre refresh
  /// si se llama.
  ///
  /// **Race condition con `dispose()`:** si el caller llama
  /// `dispose()` mientras el `await _fetcher()` está pendiente, el
  /// controller queda cerrado. Cuando el fetcher responde, este método
  /// intenta emitir al controller cerrado y lanza
  /// `Bad state: Cannot add new events after calling close`. Por eso
  /// cada `add` / `addError` va guardado con `_controller.isClosed`
  /// (cubierto por el test de regression en
  /// `test/core/tiers/tier_service_test.dart`).
  Future<void> refresh({bool force = false}) async {
    try {
      final body = await _fetcher();
      final newFlags = _parseFlags(body);
      _applyRemoteUpdate(newFlags);
    } catch (e, st) {
      // AC5: NO romper la UI. Loguear y conservar cache.
      // Sanitizado: NO loggeamos la excepción completa (puede contener
      // URLs, headers, o info de Supabase). Solo el tipo y un mensaje
      // genérico. El error completo va al `addError` de abajo, que
      // listeners pueden consumir.
      debugPrint('TierService: refresh failed (${e.runtimeType}) — '
          'keeping previous cache');
      // `addError` para que listeners que quieran reaccionar a fallos
      // puedan hacerlo. Por ahora nadie lo usa.
      // Guard: si `dispose()` se llamó mientras el fetcher esperaba,
      // el controller ya está cerrado. NO emitimos — no hay nadie
      // escuchando y emitir lanzaría `Bad state`.
      if (_controller.isClosed) return;
      _controller.addError(e, st);
    }
  }

  /// Parsea el body de la edge function y devuelve un mapa
  /// `AppFeature → bool`. Solo incluye features conocidas (que estén en
  /// el enum). Features desconocidas en la BD se ignoran — no rompen,
  /// solo no se cachean.
  Map<AppFeature, bool> _parseFlags(Map<String, dynamic> body) {
    final flags = body['flags'];
    if (flags is! Map<String, dynamic>) {
      throw const FormatException(
        'feature-flags: "flags" key missing or not an object',
      );
    }
    final result = <AppFeature, bool>{};
    for (final feature in AppFeature.values) {
      final value = flags[feature.name];
      if (value is bool) {
        result[feature] = value;
      }
    }
    return result;
  }

  /// Aplica los flags nuevos al cache. Emite un `TierChange` por cada
  /// feature cuyo valor realmente cambió (no emite si el valor es el
  /// mismo — el spec pide "cambios reales").
  void _applyRemoteUpdate(Map<AppFeature, bool> newFlags) {
    for (final entry in newFlags.entries) {
      final oldValue = _cache[entry.key] ?? false;
      if (entry.value != oldValue) {
        _cache[entry.key] = entry.value;
        // Guard: si `dispose()` se llamó mientras el `await _fetcher()`
        // estaba pendiente, el controller ya está cerrado. NO emitimos
        // — no hay nadie escuchando y emitir lanzaría `Bad state`.
        if (_controller.isClosed) return;
        _controller.add(
          TierChange(
            feature: entry.key,
            newValue: entry.value,
            source: ChangeSource.remote,
          ),
        );
      }
    }
  }

  /// Cierra el stream. Solo para tests y para `dispose()` global. NO
  /// llamar desde código de feature.
  ///
  /// Idempotente: si ya estaba cerrado, no hace nada. Esto protege
  /// contra doble `dispose()` desde `tearDown` encadenados o re-entry
  /// en `getIt.reset()` + re-registro. Cubierto por el test
  /// `dispose() es idempotente: llamar dos veces no lanza`.
  void dispose() {
    if (_controller.isClosed) return;
    _controller.close();
  }
}
