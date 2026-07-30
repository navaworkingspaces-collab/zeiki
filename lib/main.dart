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
//   `MaterialApp.router(routerConfig: appRouter)`. La navegación
//   declarativa vive en `lib/core/router/app_router.dart`. Las pantallas
//   son placeholders temporales (espec §AC2) que se migran a
//   `lib/features/<dominio>/` cuando cada una tenga contenido real.
//   Se elimina el `Future.delayed(1s)` que HDU-001 había dejado como
//   prueba de vida (espec §AC12) — la app ya no espera 1s artificial
//   antes de mostrar la primera pantalla.
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/constants/env_config.dart';
import 'core/di/service_locator.dart';
import 'core/router/app_links_handler.dart';
import 'core/router/app_router.dart';
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
  // `TierService.initialize()` porque el refresh inicial del
  // `TierService` llama a `supabase.functions.invoke('feature-flags')`
  // (spec HDU-003 §Notas — orden explícito por lección HDU-001/002).
  await initSupabase(env);

  // Registra los singletons lazy en GetIt (ADR-005). Se hace DESPUÉS
  // de Supabase para que cualquier singleton que lo necesite ya lo
  // encuentre inicializado.
  setupServiceLocator();

  // Dispara el refresh inicial de los feature flags en background
  // (fire-and-forget, AC8 de HDU-003). El `await` solo bloquea la
  // asignación de config; internamente `initialize()` no espera al
  // refresh. La app sigue a `runApp` mientras el cache se llena. Si
  // la red está caída, el cache queda vacío (todos los flags en
  // `false` por fail-safe) y se loguea un warning — la UI no se rompe.
  await TierService.getInstance().initialize();

  runApp(const ZeikiApp());

  // HDU-004 AC5: cablea los deep links `zeiki://<ruta>` al router.
  // Se hace DESPUÉS de `runApp` para que el router ya esté montado
  // cuando llegue el primer intent. La suscripción NO se captura: vive
  // lo que vive el proceso (los tests sí la capturan para cancelarla
  // y verificar el deep link end-to-end).
  wireAppLinksDeepLinks(appRouter);
}

class ZeikiApp extends StatelessWidget {
  const ZeikiApp({super.key});

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
      routerConfig: appRouter,
    );
  }
}
