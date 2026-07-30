// Placeholder de Splash (HDU-004).
//
// Es un andamio temporal mientras la pantalla real de splash llega en
// HDU-006. Cuando esa HDU implemente la pantalla, este archivo se
// migra a `lib/features/identidad/screens/splash_screen.dart` y el
// `app_router.dart` actualiza su import (spec §Notas).
//
// El botón "Ir a Onboarding" simula el caso en que el usuario ya pasó
// el splash y entra al onboarding. El botón "Ir a Login" cubre el
// caso en que el splash decide que el usuario ya tiene cuenta.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_router.dart';

class SplashPlaceholder extends StatelessWidget {
  const SplashPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Splash',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => context.push(AppRoute.onboarding.path),
              child: const Text('Ir a Onboarding'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push(AppRoute.login.path),
              child: const Text('Ir a Login'),
            ),
          ],
        ),
      ),
    );
  }
}
