// Placeholder de Login (HDU-004).
//
// Andamio temporal hasta que la pantalla real de login llegue en HDU-005.
// Se migrará a `lib/features/identidad/screens/login_screen.dart`.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_router.dart';

class LoginPlaceholder extends StatelessWidget {
  const LoginPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Login',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => context.push(AppRoute.onboarding.path),
              child: const Text('Ir a Onboarding'),
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
