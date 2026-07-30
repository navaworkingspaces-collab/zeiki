// Entry point de Zeiki.
//
// HDU-001: base del proyecto. La app solo muestra un placeholder para
// confirmar que el ciclo de vida de Flutter funciona. Sin splash real, sin
// navegación, sin features. Esas llegan en HDUs posteriores.
//
// HDU-002: se inicializa el cliente de Supabase antes de `runApp` para
// que cualquier feature que lo necesite pueda usarlo desde el primer
// frame. El `.env` se carga como asset del bundle y se mapea a un
// `EnvConfig` tipo-seguro. Si falta una variable requerida, la app
// falla rápido con un mensaje claro (conventions §10 + spec HDU-002).
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/constants/env_config.dart';
import 'core/di/service_locator.dart';
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
  // (fire-and-forget, AC8). El `await` solo bloquea la asignación de
  // config; internamente `initialize()` no espera al refresh. La app
  // sigue a `runApp` mientras el cache se llena. Si la red está caída,
  // el cache queda vacío (todos los flags en `false` por fail-safe) y
  // se loguea un warning — la UI no se rompe.
  await TierService.getInstance().initialize();

  // HDU-001 AC5: el placeholder debe ser visible por al menos 1 segundo.
  // Este delay es solo para confirmar el ciclo de vida — NO es splash real.
  // El splash real llega en una HDU aparte (ver spec HDU-001 §Fuera de scope).
  await Future<void>.delayed(const Duration(seconds: 1));

  runApp(const ZeikiApp());
}

class ZeikiApp extends StatelessWidget {
  const ZeikiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zeiki',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _PlaceholderPage(),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Zeiki — base del proyecto',
          style: TextStyle(fontSize: 20),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
