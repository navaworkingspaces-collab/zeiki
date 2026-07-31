// Entry point de Zeiki.
//
// HDU-001: base del proyecto.
// HDU-002: se inicializa el cliente de Supabase antes de `runApp` para
//   que cualquier feature que lo necesite pueda usarlo desde el primer
//   frame. El `.env` se carga como asset del bundle y se mapea a un
//   `EnvConfig` tipo-seguro. Si falta una variable requerida, la app
//   falla rápido con un mensaje claro (conventions §10 + spec HDU-002).
// HDU-003: se inicializa el `TierService` para que el feature flag system
//   esté listo antes del primer frame (la app sigue a `runApp` mientras
//   el cache se llena en background).
// HDU-004: el `MaterialApp` con `home:` se reemplaza por
//   `MaterialApp.router(routerConfig: ...)`. La navegación declarativa
//   vive en `lib/core/router/app_router.dart`.
// HDU-005 (Decisión A del review de HDU-004): el `appRouter` deja de
//   ser una variable global mutable y se obtiene de GetIt con
//   `getIt<GoRouter>()`. Esto le permite al `redirect` del router
//   consultar `AuthService` (también en GetIt) en cada navegación.
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_service.dart';
import 'core/constants/env_config.dart';
import 'core/di/service_locator.dart';
import 'core/router/app_links_handler.dart';
import 'core/supabase/supabase_client.dart';
import 'core/tiers/tier_service.dart';

Future<void> main() async {
  // Asegura el binding antes del await para no perder el primer frame.
  WidgetsFlutterBinding.ensureInitialized();

  // Carga `assets/.env` desde el asset bundle. Falla rápido si el
  // archivo no está — en dev, Hugo lo crea antes de `flutter run`
  // (ver `docs/runbooks/secrets.md` y spec HDU-002 §Riesgos).
  // `flutter_dotenv 5.x` unificó `loadFromAsset` en `load(fileName: ...)`;
  // el parámetro acepta la ruta completa del asset (prefijo `assets/`).
  await dotenv.load(fileName: 'assets/.env');

  // Mapea el `.env` a un objeto tipo-seguro. Si falta SUPABASE_URL o
  // SUPABASE_ANON_KEY, lanza `ArgumentError` con mensaje accionable.
  final env = EnvConfig.fromDotEnv(dotenv);

  // Inicializa el cliente de Supabase. Si la URL es inválida o la red
  // está caída, `Supabase.initialize` lanza — preferimos crash con
  // stack trace a "la app abre y todo falla en silencio".
  // IMPORTANTE: `initSupabase` debe ir ANTES de
  // `setupServiceLocator()` y `TierService.initialize()` porque
  // ambos servicios (incluido el nuevo `AuthService` de HDU-005)
  // dependen del cliente ya inicializado.
  await initSupabase(env);

  // Registra los singletons lazy en GetIt (ADR-005, ADR-011). Se hace
  // DESPUÉS de Supabase para que cualquier singleton que lo necesite
  // ya lo encuentre inicializado. `setupServiceLocator` ahora registra
  // también `AuthService`, `GoogleSignInHandler` y `GoRouter` (HDU-005).
  setupServiceLocator();

  // Pre-calienta `AuthService` para que `getCurrentSession()` esté
  // disponible ANTES del primer redirect del router. Si no, el redirect
  // podría leer `null` cuando en realidad hay una sesión persistida
  // (caso cold start con sesión viva — AC20, AC25).
  getIt<AuthService>();

  // Dispara el refresh inicial de los feature flags en background
  // (fire-and-forget, AC8 de HDU-003). El `await` solo bloquea la
  // asignación de config; internamente `initialize()` no espera al
  // refresh. La app sigue a `runApp` mientras el cache se llena. Si
  // la red está caída, el cache queda vacío (todos los flags en
  // `false` por fail-safe) y se loguea un warning — la UI no se rompe.
  await TierService.getInstance().initialize();

  // El router se obtiene de GetIt (HDU-005, Decisión A del review de
  // HDU-004). La factory `buildAppRouter` se evaluó al primer
  // `getIt<GoRouter>()` dentro de `setupServiceLocator` y queda
  // cacheada — esta llamada es la misma instancia.
  final router = getIt<GoRouter>();

  runApp(ZeikiApp(router: router));

  // HDU-004 AC5: cablea los deep links `zeiki://<ruta>` al router.
  // Se hace DESPUÉS de `runApp` para que el router ya esté montado
  // cuando llegue el primer intent. La suscripción NO se captura: vive
  // lo que vive el proceso (los tests sí la capturan para cancelarla
  // y verificar el deep link end-to-end).
  wireAppLinksDeepLinks(router);
}

class ZeikiApp extends StatelessWidget {
  const ZeikiApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    // `restorationScopeId` habilita state restoration (AC7 de HDU-004):
    // go_router 14.x se registra con el `RestorationMixin` y, en
    // rotación, preserva el stack de navegación. Sin este id, rotar
    // el celular regresa al usuario a `/splash`.
    return MaterialApp.router(
      title: 'Zeiki',
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'zeiki_app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
