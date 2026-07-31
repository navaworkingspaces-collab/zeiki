// Service locator de Zeiki (ADR-005).
//
// `getIt` es la instancia global de `GetIt`. Se inicializa en
// `setupServiceLocator()`, llamado desde `main.dart` después de
// `initSupabase(env)` y antes de `TierService.initialize()`.
//
// Patrón:
//   - Singleton lazy para servicios cross-cutting (`TierService`,
//     `AuthService`, `BiometricService`, `GoRouter`).
//   - Los features NO reciben dependencias por constructor — las
//     consumen vía `getIt<T>()` cuando las necesitan.
//
// Por qué `TierService` SÍ está en GetIt aunque ADR-010 diga lo
// contrario: el spec de la HDU-003 (AC2 + AC7) y la decisión de
// Hugo en la sesión de implementación son explícitos sobre
// registrarlo como singleton lazy. ADR-010 se queda como
// precedente histórico y se revisará si aparece fricción.
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../services/biometric_service.dart';
import '../auth/google_sign_in_handler.dart';
import '../router/app_router.dart';
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

  // `AuthService` (HDU-005, AC2): singleton lazy, igual que
  // `TierService`. El constructor por default pega a
  // `Supabase.instance.client.auth`; los tests inyectan fakes.
  // También registramos `GoogleSignInHandler` para que `AuthService`
  // lo encuentre con `getIt<GoogleSignInHandler>()` cuando se cree.
  if (!getIt.isRegistered<GoogleSignInHandler>()) {
    getIt.registerLazySingleton<GoogleSignInHandler>(
      // Factory: `registerLazySingleton` espera `T Function()`, no
      // un valor. El handler tiene un const constructor así que
      // construirlo en cada `getIt<...>()` es prácticamente gratis.
      () => const GoogleSignInHandler(),
    );
  }
  if (!getIt.isRegistered<AuthService>()) {
    getIt.registerLazySingleton<AuthService>(
      () => AuthService(googleSignInHandler: getIt<GoogleSignInHandler>()),
    );
  }

  // `BiometricService` (HDU-005b, AC2): singleton lazy. Usa
  // `local_auth` y `flutter_secure_storage` por default. Los tests
  // inyectan fakes (funciones y un `_MemoryStorage`).
  if (!getIt.isRegistered<BiometricService>()) {
    getIt.registerLazySingleton<BiometricService>(BiometricService.new);
  }

  // `InactivityMonitor` (HDU-005b, AC20): NO se registra como
  // singleton lazy. Es un widget — se instancia cuando
  // `MaterialApp` lo monta (en `main.dart`, dentro del `runApp`).
  // El widget recibe `signOutFn` por constructor (closure) que
  // captura `getIt<AuthService>()`, no necesita estar en GetIt.

  // `GoRouter` (HDU-005, AC23 — Decisión A del review de HDU-004):
  // se registra como singleton lazy. La razón: el `redirect` del
  // router consulta `AuthService` antes de cada navegación, y el
  // `redirect` no puede usar un import circular ni una variable
  // global mutable. Con el router en GetIt, `buildAppRouter(authService:
  // getIt<AuthService>())` resuelve la dependencia limpiamente.
  //
  // **HDU-005b (AC22-24):** conectamos `authStateChanges` al
  // `GoRouter.refreshListenable` vía `refreshStream`. Resultado:
  // `signOut` desde cualquier pantalla hace que el router
  // re-evalúe el `redirect` automáticamente (sin tocar la pantalla).
  //
  // **HDU-005b (AC10, AC15, AC16):** el `initialLocation` default
  // es `/splash`. Si el cold start tiene sesión + biometría,
  // `main.dart` lo override con `router.go('/unlock')` antes de
  // `runApp`. Trade-off: el usuario ve un flash del splash antes
  // de ir a /unlock. En la práctica, el frame del splash + el
  // redirect son imperceptibles (no es un round-trip a la red).
  // La alternativa (pre-cargar el cache de BiometricService de
  // forma asíncrona antes de construir el router) requiere una
  // API más complicada (separar el registro del router del
  // service_locator) y se documenta como follow-up si la UX lo
  // exige.
  if (!getIt.isRegistered<GoRouter>()) {
    getIt.registerLazySingleton<GoRouter>(
      // El router recibe GETTERS, no instancias, para que el redirect
      // consulte los servicios actuales en cada navegación. Esto permite
      // que `signIn*` y `signOut` (que mutan la sesión) se reflejen en
      // el router sin tener que reconstruirlo.
      () => buildAppRouter(
        authServiceGetter: () => getIt<AuthService>(),
        refreshStream: getIt<AuthService>().authStateChanges,
      ),
    );
  }
}
