// Pantalla de register (HDU-005, AC4-AC11).
//
// Pantalla **funcional, no bonita** (spec §Notas). El diseño visual
// sale en HDU futura. Esta HDU es el "esqueleto funcional".
//
// Flujo:
//   1. Usuario llena email + password.
//   2. Tap "Crear cuenta" → valida en cliente (AC6). Si pasa, llama
//      `AuthService.signUpWithEmail` (AC5). Si Supabase responde
//      éxito → navega a /home. Si falla → SnackBar con mensaje
//      accionable (AC7).
//   3. Tap "Continuar con Google" → dispara el popup del SO (AC9). Si
//      confirma → `signInWithGoogle` → /home. Si cancela (AC10) → no
//      se hace nada, no se muestra error.
//
// **Por qué `StatefulWidget`:** el `Form` con `_formKey` y los
// controllers de los `TextFormField` necesitan estado que sobreviva
// a los rebuilds. `ConsumerStatefulWidget` sería overkill — no
// necesitamos escuchar al `AuthService` reactivamente (el servicio
// no cambia durante el flujo de register, solo se invoca una vez).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_exception.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/router/app_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // Handlers
  // ============================================================

  Future<void> _onSubmit() async {
    // Validación de cliente primero (AC6). Si el form no es válido,
    // `_formKey.currentState!.validate()` retorna `false` y los
    // mensajes de error aparecen bajo cada campo.
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = getIt<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      await auth.signUpWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      // El router se encarga del resto vía `redirect`: si hay sesión,
      // /home está OK. Aquí navegamos explícitamente para que la
      // transición sea inmediata, sin esperar la próxima navegación.
      router.go(AppRoute.home.path);
    } on AuthException catch (e) {
      // Mensaje ya viene en español y accionable (conventions §6, §8).
      // NO se loguea la causa (puede contener PII) en este punto;
      // el `AuthService` ya la loguea sanitizada.
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      // Defensa: cualquier excepción NO mapeada cae aquí.
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Algo salió mal. Intenta de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onGoogle() async {
    setState(() => _isLoading = true);
    final auth = getIt<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      await auth.signInWithGoogle();
      if (!mounted) return;
      router.go(AppRoute.home.path);
    } on UserCancelledAuthFlow {
      // AC10: cancelar el popup NO es error. La pantalla se queda
      // como está, sin mensaje.
      if (!mounted) return;
    } on AuthException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Algo salió mal. Intenta de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        leading: IconButton(
          // Back al login (no al splash — la app ya pasó splash).
          // `context.pop` respeta el stack; si no hay stack, va a /login.
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoute.login.path);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  key: const Key('register_email'),
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('register_password'),
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('register_submit'),
                  onPressed: _isLoading ? null : _onSubmit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Crear cuenta'),
                ),
                const SizedBox(height: 16),
                // AC8: el botón de Google va DEBAJO del formulario.
                OutlinedButton.icon(
                  key: const Key('register_google'),
                  onPressed: _isLoading ? null : _onGoogle,
                  icon: const Icon(Icons.login),
                  label: const Text('Continuar con Google'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => context.go(AppRoute.login.path),
                  child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Validadores
  // ============================================================

  /// Validación de email en cliente (AC6). No es perfecta (la única
  /// verdad es la regex RFC 5322), pero cubre el 99% de los casos
  /// sin agregar una dependencia.
  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu correo';
    // Regex práctica: algo@algo.algo. No cubre todos los RFC pero
    // sí los correos reales (Gmail, Outlook, dominios corporativos).
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(v)) return 'Correo no válido';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Ingresa una contraseña';
    if (v.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
    return null;
  }
}
