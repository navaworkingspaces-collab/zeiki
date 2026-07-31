// Pantalla de home (HDU-005, AC18, AC19, + HDU-005b settings chiquito).
//
// Lo que muestra hoy:
//   - El email del usuario actual (de `AuthService.getCurrentSession()`).
//   - Un menú con 2 acciones:
//     - "Activar/Desactivar biometría" (toggle, HDU-005b).
//     - "Salir" (signOut + navega a /login).
//
// Lo que NO muestra (out of scope para HDU-005 / HDU-005b):
//   - Dashboard fiscal, lista de CFDIs, métricas. Esas son features
//     de Fase 1 que llegan en HDUs futuras (Fiscal, Reportes).
//   - Configuración completa de perfil. Sale en HDU de Configuración.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_exception.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/router/app_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = getIt<AuthService>();
  final _biometric = getIt<BiometricService>();

  // Cached en el primer build para evitar un round-trip a storage
  // cada vez que el user abre el menú. Se actualiza tras toggle.
  bool? _biometricEnabled;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
  }

  Future<void> _loadBiometricStatus() async {
    final userId = _auth.currentUserId;
    if (userId == null) {
      setState(() => _biometricEnabled = false);
      return;
    }
    final enabled = await _biometric.isBiometricEnabled(userId: userId);
    if (!mounted) return;
    setState(() => _biometricEnabled = enabled);
  }

  Future<void> _toggleBiometric() async {
    if (_isToggling) return;
    setState(() => _isToggling = true);

    final userId = _auth.currentUserId;
    if (userId == null) return;

    final currentlyEnabled = _biometricEnabled ?? false;

    if (currentlyEnabled) {
      // Desactivar: directo (no requiere auth, el user ya está
      // logueado).
      await _biometric.setBiometricEnabled(false, userId: userId);
      if (!mounted) return;
      setState(() {
        _biometricEnabled = false;
        _isToggling = false;
      });
      _showSnack('Biometría desactivada');
      return;
    }

    // Activar: requiere verificar huella UNA VEZ (popup del SO).
    final ok = await _biometric.authenticate(
      'Activar biometría para Zeiki',
    );
    if (!mounted) return;
    if (ok) {
      await _biometric.setBiometricEnabled(true, userId: userId);
      if (!mounted) return;
      setState(() {
        _biometricEnabled = true;
        _isToggling = false;
      });
      _showSnack('Biometría activada');
    } else {
      if (!mounted) return;
      setState(() => _isToggling = false);
      _showSnack('No se pudo activar la biometría');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _onSignOut() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      await _auth.signOut();
      if (!mounted) return;
      // El redirect del router manda a /login cuando no hay sesión.
      // Navegamos explícitamente para que la transición sea inmediata.
      router.go(AppRoute.login.path);
    } on AuthException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('No pudimos cerrar la sesión.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = getIt<AuthService>().getCurrentSession();
    final email = session?.user.email ?? 'usuario';
    final biometricLabel = (_biometricEnabled ?? false)
        ? 'Desactivar biometría'
        : 'Activar biometría';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        automaticallyImplyLeading: false, // sin back: home es la raíz
        actions: <Widget>[
          PopupMenuButton<String>(
            key: const Key('home_menu'),
            tooltip: 'Más opciones',
            onSelected: (String value) {
              switch (value) {
                case 'biometric':
                  _toggleBiometric();
                case 'signout':
                  _onSignOut();
              }
            },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                key: const Key('home_menu_biometric'),
                value: 'biometric',
                enabled: !_isToggling,
                child: Text(biometricLabel),
              ),
              const PopupMenuItem<String>(
                key: Key('home_menu_signout'),
                value: 'signout',
                child: Text('Salir'),
              ),
            ],
          ),
        ],
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
            ],
          ),
        ),
      ),
    );
  }
}
