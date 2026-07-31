// Pantalla de home (HDU-005, AC18, AC19).
//
// Lo que muestra hoy:
//   - El email del usuario actual (de `AuthService.getCurrentSession()`).
//   - Un botón "Salir" que llama `signOut()` y navega a /login.
//
// Lo que NO muestra (out of scope para HDU-005):
//   - Dashboard fiscal, lista de CFDIs, métricas. Esas son features
//     de Fase 1 que llegan en HDUs futuras (Fiscal, Reportes).
//   - Configuración de perfil. Sale en HDU de Configuración.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_exception.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/router/app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _onSignOut(BuildContext context) async {
    final auth = getIt<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      await auth.signOut();
      if (!context.mounted) return;
      // El redirect del router manda a /login cuando no hay sesión.
      // Navegamos explícitamente para que la transición sea inmediata.
      router.go(AppRoute.login.path);
    } on AuthException catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('No pudimos cerrar la sesión.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = getIt<AuthService>().getCurrentSession();
    final email = session?.user.email ?? 'usuario';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        automaticallyImplyLeading: false, // sin back: home es la raíz
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Bienvenido',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                email,
                key: const Key('home_email'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),
              FilledButton.tonalIcon(
                key: const Key('home_signout'),
                onPressed: () => _onSignOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('Salir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
