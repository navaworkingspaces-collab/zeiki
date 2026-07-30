// HDU-002: Integration test de health check del cliente contra Supabase.
//
// Verifica que el cliente puede leer la tabla `app_tier_features` usando
// las credenciales del `.env` y que devuelve filas (el seed de AC3).
//
// Vive bajo `integration_test/` (raíz) en lugar de `test/` para que
// `flutter test` default NO lo incluya. `flutter test` ejecuta
// `test/**/*.dart` por default; los tests que requieren backend vivo
// (Supabase configurado, migraciones aplicadas, edge function deployada)
// viven en `integration_test/` y se corren por separado con:
//   flutter test integration_test/
// (Es la convención estándar de Flutter para tests que tocan un
// sistema externo. El spec original mencionaba `test/integration/`, pero
// esa ruta no permite excluir los tests del `flutter test` default de
// forma portable. Reportado al orquestador como desviación técnica.)
//
// Requiere:
//   1. Las migraciones aplicadas en Supabase (Hugo las aplica manual).
//   2. La edge function deployada (Hugo la deploya manual).
//   3. `assets/.env` con `SUPABASE_URL` y `SUPABASE_ANON_KEY` válidos.
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
    'SELECT from app_tier_features returns at least the seed row',
    () async {
      final client = Supabase.instance.client;
      final response = await client.from('app_tier_features').select();

      // El seed de HDU-002 inserta `splash` para `free` y `pro`. Si la
      // tabla está vacía, las migraciones no se aplicaron (Hugo debe
      // correrlas antes de que este test pase).
      expect(response, isNotNull);
      final rows = response as List<dynamic>;
      expect(
        rows,
        isNotEmpty,
        reason:
            'Expected at least one row in app_tier_features. '
            'Did Hugo apply the migrations and the seed?',
      );

      // Verifica que al menos existe `splash` en algún tier. El detalle
      // de la forma de cada fila es del spec de Supabase; lo importante
      // es que `splash` esté presente.
      final hasSplash = rows.any(
        (row) => (row as Map<String, dynamic>)['feature_key'] == 'splash',
      );
      expect(hasSplash, isTrue, reason: 'Expected splash flag in the table.');
    },
  );
}
