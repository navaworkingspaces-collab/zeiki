// HDU-002 (fix): Integration test de regresión de RLS para `app_tier_features`.
//
// El spec HDU-002 lo pedía explícitamente:
//   - Línea 88: "RLS de la tabla | Muy alta (afecta seguridad) | Test de
//     integración que verifica que anon puede SELECT pero NO puede
//     INSERT/UPDATE/DELETE. TDD crítico aquí."
//   - Línea 125: "Security ... RLS de la tabla verificada por test".
//
// El test de SELECT ya existe en `supabase_health_test.dart`. Este archivo
// agrega los 3 tests de regresión que faltaban: si una migración futura
// rompe las policies de RLS accidentalmente (ej. un GRANT demasiado
// permisivo, una policy con `TO public`, o el GRANT de
// `20260729150000_grant_app_tier_features.sql` que se invierta), el pipeline
// falla aquí antes de que un cambio llegue a producción.
//
// Sigue el patrón del implementer: `setUpAll` carga `.env` y llama
// `initSupabase`. El cliente público usa la `anon_key` (publishable), por
// lo que cualquier intento de INSERT/UPDATE/DELET debe fallar por la
// policy definida en
// `supabase/migrations/20260729140000_create_app_tier_features.sql`.
//
// Requiere:
//   1. Las migraciones aplicadas en Supabase (Hugo las aplica manual).
//   2. `assets/.env` con `SUPABASE_URL` y `SUPABASE_ANON_KEY` válidos.
@Tags(['integration'])
library;

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

  // Test 1 — duplicado intencional del coverage de `supabase_health_test.dart`
  // para que el grupo RLS sea autocontenido. Si en el futuro alguien borra
  // el health test, este sigue verificando que `anon` puede leer.
  test(
    'RLS: anon can SELECT from app_tier_features',
    () async {
      final client = Supabase.instance.client;
      final response = await client.from('app_tier_features').select();
      expect(response, isNotNull);
    },
  );

  // Tests 2-4: `anon` NO debe poder escribir. Se espera `PostgrestException`
  // — `postgrest_builder.dart:264` lo lanza cuando el response tiene
  // statusCode no-2xx (Supabase devuelve 401/403 cuando la policy lo niega).
  // No validamos el código exacto ni el mensaje porque pueden cambiar entre
  // versiones de Supabase; lo que nos importa es que NO pase silenciosamente.
  test(
    'RLS: anon cannot INSERT into app_tier_features',
    () async {
      final client = Supabase.instance.client;
      await expectLater(
        () => client.from('app_tier_features').insert({
          'feature_key': 'rls_regression_anon_insert',
          'tier': 'test',
          'enabled': true,
        }),
        throwsA(isA<PostgrestException>()),
      );
    },
  );

  test(
    'RLS: anon cannot UPDATE app_tier_features',
    () async {
      final client = Supabase.instance.client;
      // Apunta a una fila real del seed (`splash`/`free`) — el UPDATE
      // fallaría por RLS antes de que Postgres evalúe el WHERE.
      await expectLater(
        () => client
            .from('app_tier_features')
            .update({'enabled': false})
            .eq('feature_key', 'splash')
            .eq('tier', 'free'),
        throwsA(isA<PostgrestException>()),
      );
    },
  );

  test(
    'RLS: anon cannot DELETE from app_tier_features',
    () async {
      final client = Supabase.instance.client;
      // Igual que UPDATE: la policy de ALL para `service_role` excluye a
      // `anon`, así que la operación es rechazada antes de tocar filas.
      await expectLater(
        () => client
            .from('app_tier_features')
            .delete()
            .eq('feature_key', 'splash')
            .eq('tier', 'free'),
        throwsA(isA<PostgrestException>()),
      );
    },
  );

  // Test 5 (skipeado intencionalmente):
  //   "service_role SÍ puede hacer ALL" — requeriría construir un cliente
  //   con la `service_role_key`, que es SECRETA y vive en Supabase secrets,
  //   NO en `assets/.env` (conventions §6 + comentario de `supabase_client.dart:27`).
  //   El coverage de `service_role` vive en los tests Deno de la edge function
  //   `feature-flags`, donde sí puede leerse vía `Deno.env.get()`.
  //   Si en el futuro queremos un test cliente → service_role, va como HDU
  //   separada con un canal seguro para inyectar la key en CI.
}
