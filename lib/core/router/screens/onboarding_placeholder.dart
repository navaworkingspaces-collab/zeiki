// Placeholder de Onboarding (HDU-004).
//
// Andamio temporal hasta que la pantalla real de onboarding llegue.
// Se migrará a `lib/features/identidad/screens/` cuando tenga contenido.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_router.dart';

class OnboardingPlaceholder extends StatelessWidget {
  const OnboardingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Onboarding',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => context.push(AppRoute.login.path),
              child: const Text('Ir a Login'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push(AppRoute.home.path),
              child: const Text('Ir a Home'),
            ),
          ],
        ),
      ),
    );
  }
}
