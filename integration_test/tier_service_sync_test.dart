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
    setupServiceLocator();
  });

  // Reset entre tests: el singleton conserva el cache, pero queremos
  // verificar que cada test empieza con un refresh limpio.
  setUp(() {
    if (getIt.isRegistered<TierService>()) {
      getIt<TierService>().dispose();
      getIt.reset();
      setupServiceLocator();
    }
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
