// Enum `AppFeature` — la fuente canónica de feature flags en el cliente
// (ADR-010 + spec HDU-003 AC1).
//
// Cada valor:
//   - `name` es el `feature_key` que se usa en la tabla `app_tier_features`
//     de Supabase. La edge function `feature-flags` lo devuelve en el JSON.
//   - `description` documenta el propósito del feature (ayuda a debugging
//     y a la doc auto-generada de Target §15).
//
// Por qué un enum y no strings sueltos:
//   - Type-safe: la IDE autocompleta y el compilador atrapa typos.
//   - El `feature_sync_test` (integration_test/feature_sync_test.dart)
//     garantiza que cada valor de este enum tenga al menos una fila en
//     `app_tier_features`. Si agregas un valor aquí sin agregarlo al seed
//     de la BD, el test falla.
//
// Por qué empezar solo con `splash`:
//   - Target §10: "Agregar al menos un feature por HDU". El splash es el
//     primer feature que tendrá flag en producción (HDU-006 lo consume).
//   - Los demás features se agregan acá Y en el seed de la BD al mismo
//     tiempo, en HDUs futuras, según necesidad.
enum AppFeature {
  /// Pantalla de splash que se muestra al abrir la app. La HDU-006
  /// la implementa y la gatea con `TierService.has(AppFeature.splash)`.
  /// Seed actual: `('splash', 'free', true)`, `('splash', 'pro', true)`
  /// (aplicado en HDU-002).
  splash('splash', description: 'Splash screen shown on app launch.');

  const AppFeature(this.name, {required this.description});

  /// Identificador estable que se usa como `feature_key` en la tabla
  /// `app_tier_features` de Supabase. NO cambiar una vez publicado: hay
  /// datos en la BD con este valor.
  final String name;

  /// Documenta el propósito del feature. Aparece en logs, en la doc
  /// auto-generada y en mensajes de error.
  final String description;
}
