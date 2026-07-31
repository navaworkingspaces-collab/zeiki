// Integration test del `TierService` con la edge function real
// (spec HDU-003 AC8 + AC10).
//
// Verifica que el flujo end-to-end funciona:
//   1. `TierService.initialize()` dispara un refresh fire-and-forget.
//   2. El refresh pega a la edge function `feature-flags` deployada en
//      HDU-002.
//   3. El cache se actualiza con la respuesta real.
//   4. `has(AppFeature.splash)` devuelve `true` (seed de HDU-002:
//      `('splash', 'free', true)`, `('splash', 'pro', true)`).
//
// Vive bajo `integration_test/` (raíz) en lugar de `test/` para que
// `flutter test` default NO lo incluya.
//
// Requiere:
//   1. La edge function `feature-flags` deployada (HDU-002).
//   2. Las migraciones aplicadas (para que la tabla tenga datos).
//   3. `assets/.env` con `SUPABASE_URL` y `SUPABASE_ANON_KEY` válidos.
//
// Para correrlo: `flutter test integration_test/` (en Xiaomi).
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:zeiki/core/constants/env_config.dart';
import 'package:zeiki/core/di/service_locator.dart';
import 'package:zeiki/core/supabase/supabase_client.dart';
import 'package:zeiki/core/tiers/app_feature.dart';
import 'package:zeiki/core/tiers/tier_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: 'assets/.env');
    final env = EnvConfig.fromDotEnv(dotenv);
    await initSupabase(env);

    // CRÍTICO: registra el `TierService` en GetIt.
    //
    // Los integration tests NO arrancan la app completa — solo hacen
    // `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`, por
    // lo que `main.dart` NUNCA corre y `setupServiceLocator()` no se
    // llama automáticamente. Sin esta línea, el primer
    // `TierService.getInstance()` de los tests lanza
    // `GetIt: Object/factory with type TierService is not registered
    // inside GetIt`.
    //
    // **NO QUITAR.** Si parece redundante, leer el comentario de arriba.
    setupServiceLocator(env);
  });

  // Reset entre tests: el singleton conserva el cache y su
  // `StreamController` (cerrado tras `dispose()`), pero queremos
  // verificar que cada test arranca con un `TierService` fresco.
  //
  // Flujo: si hay un singleton del test anterior, lo disposeamos
  // (cierra el controller). Después `getIt.reset()` borra el registro.
  // Después `setupServiceLocator()` re-registra la factory lazy para
  // que el test que sigue la instancie de cero. `setupServiceLocator`
  // es idempotente (chequea `isRegistered` antes de registrar), así
  // que se puede llamar siempre sin miedo.
  setUp(() {
    if (getIt.isRegistered<TierService>()) {
      getIt<TierService>().dispose();
    }
    getIt.reset();
    // BUG-001: setupServiceLocator ahora toma el `EnvConfig` como
    // parámetro. Recargamos el `.env` para tener el `env` actualizado
    // (los tests individuales pueden haber mutado variables).
    final env = EnvConfig.fromDotEnv(dotenv);
    setupServiceLocator(env);
  });

  test('refresh real actualiza el cache con `splash=true` (AC8)', () async {
    final service = TierService.getInstance();
    await service.refresh();

    // El seed de HDU-002 garantiza que `splash` está habilitado.
    expect(service.has(AppFeature.splash), isTrue,
        reason: 'edge function debe devolver splash=true; si falla, '
            'verifica que el seed de HDU-002 está aplicado');
  });

  test('el stream `changes` emite cuando el primer refresh llena el cache',
      () async {
    final service = TierService.getInstance();

    // El cache está vacío al inicio. Si el refresh encuentra un valor
    // distinto al default (false), emite. Como el seed tiene splash=true,
    // va a emitir false → true.
    final received = <bool>[];
    final sub = service.changes.listen((change) {
      received.add(change.newValue);
    });

    await service.refresh();
    // Pequeño delay para que el broadcast se propague.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(received, isNotEmpty,
        reason: 'el stream debe emitir al menos 1 vez cuando el cache '
            'pasa de vacío a tener `splash=true`');
    expect(received, contains(isTrue),
        reason: 'el cambio false → true debe estar en los eventos emitidos');
    await sub.cancel();
  });
}
