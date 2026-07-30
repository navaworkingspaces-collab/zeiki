// Service locator de Zeiki (ADR-005).
//
// `getIt` es la instancia global de `GetIt`. Se inicializa en
// `setupServiceLocator()`, llamado desde `main.dart` después de
// `initSupabase(env)` y antes de `TierService.initialize()`.
//
// Patrón:
//   - Singleton lazy para servicios cross-cutting (`TierService`).
//   - Los features NO reciben dependencias por constructor — las
//     consumen vía `getIt<T>()` cuando las necesitan.
//
// Por qué `TierService` SÍ está en GetIt aunque ADR-010 diga lo
// contrario: el spec de la HDU-003 (AC2 + AC7) y la decisión de
// Hugo en la sesión de implementación son explícitos sobre
// registrarlo como singleton lazy. ADR-010 se queda como
// precedente histórico y se revisará si aparece fricción.
import 'package:get_it/get_it.dart';

import '../tiers/tier_service.dart';

/// Instancia global de GetIt. Acceso desde features:
/// `final tierService = getIt<TierService>();`
final GetIt getIt = GetIt.instance;

/// Registra todos los singletons lazy de la app. Llamar UNA vez desde
/// `main.dart` después de `initSupabase(env)`. Idempotente: si se
/// llama dos veces, la segunda es no-op (los registros existentes
/// se conservan).
void setupServiceLocator() {
  // `TierService` se registra como singleton lazy para que:
  //   1. No se cree hasta que alguien lo pida (ahorra memoria en
  //      arranque frío).
  //   2. Los tests puedan hacer `getIt.reset()` y registrar un fake
  //      antes del primer uso.
  // El constructor de `TierService` usa el fetcher por default
  // (pega a la edge function de Supabase). Los tests inyectan un fake
  // registrando manualmente su propia factory después del reset.
  if (!getIt.isRegistered<TierService>()) {
    getIt.registerLazySingleton<TierService>(TierService.new);
  }
}
