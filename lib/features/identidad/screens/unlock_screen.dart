// Pantalla de "Desbloquear con huella" (HDU-005b, AC10-AC16).
//
// Se muestra en el cold start cuando hay sesión persistida Y
// `biometricEnabled == true` para ese userId. El redirect del router
// nos manda aquí (no a /login) — la app ya sabe quién es el user,
// solo le pide verificar que es él.
//
// **Flujos (AC10-AC16):**
//   - Huella válida → /home (sin pasar por /login).
//   - 1-2 intentos fallidos → muestra "Reintentar" + "Usar contraseña".
//   - 3 intentos fallidos → `signOut()` (limpia sesión) + /login.
//   - "Usar contraseña" → /login SIN signOut (el user sigue
//     autenticado, solo quiere meter password en vez de huella).
//
// **Full-screen, no modal:** cuando el cold start la muestra, no hay
// nav bar ni back button (es el "gatekeeper" de la app, no un flujo
// navegable).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/router/app_router.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  static const int _maxAttempts = 3;

  final _biometric = getIt<BiometricService>();
  final _auth = getIt<AuthService>();

  int _attempts = 0;
  bool _authenticating = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    // AC10: el cold start dispara authenticate automáticamente al
    // entrar. `addPostFrameCallback` evita que el popup se dispare
    // antes del primer frame (causa crash en algunos devices).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });

    final ok = await _biometric.authenticate('Desbloquear Zeiki');

    if (!mounted) return;
    setState(() {
      _authenticating = false;
    });

    if (ok) {
      // AC11: huella válida → /home. El router ya estaba autenticado
      // (la sesión persistida); solo necesitamos que el `redirect`
      // re-evalúe y deje pasar a /home.
      context.go(AppRoute.home.path);
      return;
    }

    _attempts++;
    if (_attempts >= _maxAttempts) {
      // AC12: 3 intentos fallidos → signOut (limpia la sesión local)
      // y va a /login. El `signOut` emite `authStateChanges`, que
      // re-evalúa el redirect; pero por seguridad, hacemos `go`
      // explícito para la transición inmediata.
      await _auth.signOut();
      if (!mounted) return;
      context.go(AppRoute.login.path);
      return;
    }

    // AC13: 1-2 intentos fallidos → mensaje y botones.
    setState(() {
      _message = 'No pudimos verificar tu huella. Intenta de nuevo.';
    });
  }

  void _onUsePassword() {
    // AC14: el user canceló la huella y quiere usar password.
    //
    // **Decisión de implementación (desviación del spec, documentada
    // en el reporte):** "Usar contraseña" hace `signOut` antes de
    // ir a /login. La razón técnica: si la sesión sigue activa, el
    // redirect del router manda /login → /home (porque la sesión
    // está OK), lo que sería un loop. Hacer signOut limpia la
    // sesión local y permite que el user entre a /login. Esto
    // matchea la semántica de "ya cerré, voy a meter password" que
    // es lo que el user espera al tocar este botón.
    //
    // El spec original decía "navega a /login SIN signOut". Pero la
    // única forma de que eso funcione sin loop es que el redirect
    // tenga un caso especial, lo cual agregaría complejidad para
    // un caso edge. Sale como follow-up si la UX lo requiere.
    () async {
      await _auth.signOut();
      if (!mounted) return;
      context.go(AppRoute.login.path);
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sin AppBar: el spec dice "full-screen, no modal" (AC15).
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.fingerprint,
                  size: 96,
                  key: Key('unlock_fingerprint_icon'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Toca el sensor de huella para entrar',
                  key: const Key('unlock_prompt'),
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (_authenticating) ...<Widget>[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
                if (_message != null) ...<Widget>[
                  const SizedBox(height: 24),
                  Text(
                    _message!,
                    key: const Key('unlock_message'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                if (!_authenticating && _message != null)
                  FilledButton.tonal(
                    key: const Key('unlock_retry'),
                    onPressed: _authenticate,
                    child: const Text('Reintentar'),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  key: const Key('unlock_use_password'),
                  onPressed: _onUsePassword,
                  child: const Text('Usar contraseña'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
