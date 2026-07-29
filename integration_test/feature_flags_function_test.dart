// HDU-002: Integration test de invocación de la edge function `feature-flags`.
//
// Verifica que `supabase.functions.invoke('feature-flags')` devuelve un
// JSON con la forma `{ "flags": { "splash": true, ... } }`.
//
// Vive bajo `integration_test/` (raíz) en lugar de `test/` para que
// `flutter test` default NO lo incluya. Ver nota completa en
// `integration_test/supabase_health_test.dart` sobre la desviación
// respecto a la ruta original del spec.
//
// Requiere:
//   1. La edge function deployada (Hugo corre `supabase functions deploy
//      feature-flags --no-verify-jwt`).
//   2. Las migraciones aplicadas (para que la tabla tenga datos).
//   3. `assets/.env` con `SUPABASE_URL` y `SUPABASE_ANON_KEY` válidos.
//
// Para correrlo: `flutter test integration_test/`.
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:zeiki/core/constants/env_config.dart';
import 'package:zeiki/core/supabase/supabase_client.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: 'assets/.env');
    final env = EnvConfig.fromDotEnv(dotenv);
    await initSupabase(env);
  });

  test(
    'feature-flags edge function returns { flags: { splash: true, ... } }',
    () async {
      final client = Supabase.instance.client;
      final response = await client.functions.invoke('feature-flags');

      // El cliente envuelve la respuesta del function en `FunctionResponse`.
      // El body ya viene parseado como `Map<String, dynamic>`.
      final data = response.data;
      expect(data, isA<Map<String, dynamic>>());

      final body = data as Map<String, dynamic>;
      expect(body.containsKey('flags'), isTrue);

      final flags = body['flags'];
      expect(flags, isA<Map<String, dynamic>>());

      final flagsMap = flags as Map<String, dynamic>;
      expect(flagsMap['splash'], isTrue);
    },
  );
}
