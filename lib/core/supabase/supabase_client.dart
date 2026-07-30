// Inicialización del cliente de Supabase (HDU-002).
//
// Sigue Target §6: Supabase es transversal a todos los dominios, vive
// en `lib/core/` y `features → core` está permitido (al revés no).
// No contiene lógica de feature flags ni de sesión — eso es responsabilidad
// de `lib/core/tiers/` (TierService) y `lib/core/auth/` (AuthService)
// en HDUs futuras.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/env_config.dart';

/// Inicializa el cliente global de Supabase con la configuración del
/// entorno. Idempotente: `Supabase.initialize` ya detecta re-inicialización
/// y retorna sin error. Esto permite llamar `initSupabase` desde `main()`
/// y desde tests sin romper.
///
/// Lanza excepción si falla la inicialización (URL malformada, red
/// caída, etc.). El caller decide si eso es recuperable — en `main()`
/// la app muere con stack trace claro.
Future<void> initSupabase(EnvConfig env) async {
  await Supabase.initialize(
    url: env.supabaseUrl,
    // `anonKey` fue renombrado a `publishableKey` en supabase_flutter 2.x.
    // El valor sigue siendo la `anon` (publicable) key de Supabase, no la
    // `service_role` (secreta) — esa NUNCA debe llegar al cliente
    // (conventions §6 + `docs/runbooks/secrets.md`).
    publishableKey: env.supabaseAnonKey,
  );
}
