// Pantalla de "email confirmado" (HDU-007, AC3).
//
// Se llega a esta pantalla cuando el user hace click en el link del
// email de confirmación de cuenta (deep link
// `io.supabase.flutter://verify-email/?token=...`). El handler de
// deep links (`app_links_handler.dart`) traduce la URI a
// `/auth/verify-email` y el router (`app_router.dart`) renderiza
// esta pantalla.
//
// **Pantalla mínima, no bonita** (mismo scope que el resto de la HDU):
// muestra el mensaje de éxito y un CTA para ir a /login (donde el
// user podrá iniciar sesión con su cuenta recién confirmada).
//
// **Por qué esta pantalla existe como ruta independiente:** la spec
// (AC3) requiere que el user vea el mensaje "Cuenta confirmada, ya
// puedes iniciar sesión" ANTES de cualquier redirección. Esta pantalla
// desacopla la confirmación visual de la sesión activa.
//
// **Por qué la ruta es terminal** (no redirige aunque haya sesión):
// ver el bloque de cambios HDU-007 en la cabecera de `app_router.dart`.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta confirmada')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.check_circle_outline,
                  size: 96,
                  color: Colors.green,
                ),
                const SizedBox(height: 24),
                Text(
                  'Cuenta confirmada, ya puedes iniciar sesión.',
                  key: const Key('verify_email_message'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  key: const Key('verify_email_cta'),
                  onPressed: () => context.go(AppRoute.login.path),
                  child: const Text('Iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
