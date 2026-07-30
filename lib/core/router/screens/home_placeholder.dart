// Placeholder de Home (HDU-004).
//
// Andamio temporal hasta que llegue la pantalla real de Home.
// No se sabe todavía a qué dominio pertenecerá (Target §6 lista
// `identidad`, `fiscal`, `clientes`, `reportes`, `asistencia`,
// `configuracion`; la decisión se toma cuando Home tenga contenido).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_router.dart';

class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Home',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => context.push(AppRoute.login.path),
              child: const Text('Ir a Login'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push(AppRoute.splash.path),
              child: const Text('Ir a Splash'),
            ),
          ],
        ),
      ),
    );
  }
}
