// Entry point de Zeiki.
//
// HDU-001: base del proyecto. La app solo muestra un placeholder para
// confirmar que el ciclo de vida de Flutter funciona. Sin splash real, sin
// navegación, sin features. Esas llegan en HDUs posteriores.
import 'package:flutter/material.dart';

void main() async {
  // Asegura el binding antes del await para no perder el primer frame.
  WidgetsFlutterBinding.ensureInitialized();

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
