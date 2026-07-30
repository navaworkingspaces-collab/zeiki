// Integration test que verifica que el enum `AppFeature` y la tabla
// `app_tier_features` de Supabase están sincronizados (spec HDU-003 AC9,
// requisito de Target §15 "Documentos pendientes").
//
// Es un test de "regression contra drift": si alguien agrega un valor al
// enum sin agregar la fila correspondiente a la BD (o viceversa), este
// test falla con un mensaje accionable.
//
// Vive bajo `integration_test/` (raíz) en lugar de `test/` para que
// `flutter test` default NO lo incluya.
//
// Requiere:
//   1. Las migraciones de HDU-002 aplicadas (tabla `app_tier_features`
//      con datos del seed).
//   2. `assets/.env` con `SUPABASE_URL` y `SUPABASE_ANON_KEY` válidos.
//
// Para correrlo: `flutter test integration_test/` (en Xiaomi).
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:zeiki/core/constants/env_config.dart';
import 'package:zeiki/core/supabase/supabase_client.dart';
import 'package:zeiki/core/tiers/app_feature.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: 'assets/.env');
    final env = EnvConfig.fromDotEnv(dotenv);
    await initSupabase(env);
  });

  test('cada valor del enum `AppFeature` tiene al menos una fila en '
      '`app_tier_features` (AC9)', () async {
    final client = Supabase.instance.client;

    // `select` sin filtro devuelve todas las filas. La columna
    // `feature_key` es el `name` del enum.
    final response = await client
        .from('app_tier_features')
        .select('feature_key');

    final dbFeatureKeys = (response as List)
        .map((row) => row['feature_key'] as String)
        .toSet();

    final enumNames = AppFeature.values.map((f) => f.name).toSet();

    // Cada valor del enum debe estar en la BD. Si falta, el test falla
    // con un mensaje que dice exactamente qué feature hay que agregar al
    // seed.
    final missingInDb = enumNames.difference(dbFeatureKeys);
    expect(missingInDb, isEmpty,
        reason: 'Features en el enum pero no en `app_tier_features`: '
            '$missingInDb. Agrega una fila por cada tier (free, pro) con '
            '(feature_key="<nombre>", tier_code="<tier>", enabled=true) '
            'al seed.');
  });

  test('cada `feature_key` en la BD corresponde a un valor del enum',
      () async {
    final client = Supabase.instance.client;

    final response = await client
        .from('app_tier_features')
        .select('feature_key');

    final dbFeatureKeys = (response as List)
        .map((row) => row['feature_key'] as String)
        .toSet();

    final enumNames = AppFeature.values.map((f) => f.name).toSet();

    // Cada fila de la BD debe tener un valor en el enum. Si sobra, el
    // test falla con un mensaje que dice exactamente qué feature hay
    // que agregar al enum.
    final extraInDb = dbFeatureKeys.difference(enumNames);
    expect(extraInDb, isEmpty,
        reason: 'Features en `app_tier_features` que no están en el enum '
            '`AppFeature`: $extraInDb. Agrégalas a `AppFeature` en '
            '`lib/core/tiers/app_feature.dart` con su `description` y '
            'verifica que el `name` matchee el `feature_key` de la BD.');
  });
}
