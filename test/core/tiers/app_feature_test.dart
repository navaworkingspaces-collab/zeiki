// Unit tests del enum `AppFeature` (spec HDU-003 AC1).
//
// Criticidad: media (matriz §11 de Target Architecture). El enum no
// tiene lógica, pero validamos su shape para que el `feature_sync_test`
// (integration) tenga sentido y para evitar regresiones tontas
// (typos en `name`, descripciones vacías, etc.).
import 'package:flutter_test/flutter_test.dart';
import 'package:zeiki/core/tiers/app_feature.dart';

void main() {
  group('AppFeature', () {
    test('tiene al menos 1 valor', () {
      // Arrange-Act-Assert: el enum no puede estar vacío o el resto del
      // sistema pierde sentido (el primer feature que se gatea es `splash`).
      expect(AppFeature.values, isNotEmpty);
    });

    test('todos los `name` son únicos', () {
      // Arrange
      final names = AppFeature.values.map((f) => f.name).toList();
      // Assert: si hubiera duplicados, el set colapsaría.
      expect(names.toSet(), hasLength(names.length),
          reason: 'dos features con el mismo `name` rompen el `feature_sync_test`');
    });

    test('todos los `name` son snake_case válidos', () {
      // Snake_case = empieza con letra minúscula, seguido de letras
      // minúsculas, dígitos o guión bajo. Esto matchea la convención
      // de `feature_key` en la tabla `app_tier_features` (ADR-010 +
      // spec HDU-003 §AC1 nota "el método `name` del enum es el
      // `feature_key` que se usa en la tabla").
      final snakeCasePattern = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final feature in AppFeature.values) {
        expect(snakeCasePattern.hasMatch(feature.name), isTrue,
            reason:
                'feature ${feature.name} no es snake_case; la BD lo rechazaría');
      }
    });

    test('todas las descripciones no están vacías', () {
      // Documentamos el "porqué" de cada feature. Una descripción vacía
      // es regresión silenciosa — el dev olvidó documentar.
      for (final feature in AppFeature.values) {
        expect(feature.description.trim(), isNotEmpty,
            reason: '${feature.name} sin description');
      }
    });

    test('el primer feature es `splash` (semántica de la HDU-003)', () {
      // El spec dice: "Empezar solo con `splash` (Target §10 sugiere
      // 'Agregar al menos un feature por HDU')". Este test es
      // redundante con el de "tiene al menos 1 valor", pero documenta
      // explícitamente la decisión.
      expect(AppFeature.values.first.name, 'splash');
    });
  });
}
