// Pantalla de reset password (HDU-007, AC8, AC9).
//
// Se llega a esta pantalla cuando el user hace click en el link
// del email de reset password (deep link
// `io.supabase.flutter://reset-password/?token=...`). El handler de
// deep links (`app_links_handler.dart`) traduce la URI a
// `/auth/reset-password` y el router (`app_router.dart`) renderiza
// esta pantalla.
//
// **Por qué la ruta es terminal** (no redirige aunque haya sesión
// activa): ver el bloque de cambios HDU-007 en la cabecera de
// `app_router.dart`. Resumen: Supabase crea una sesión temporal al
// procesar el deep link y el redirect debe dejarnos terminar el
// cambio de password antes de movernos a /home.
//
// **Flujo:**
//   1. User llena nueva password + confirmación.
//   2. Tap "Cambiar contraseña" → valida (coincidencia, ≥ 8 chars).
//   3. Llama `AuthService.updateUserPassword(...)` (AC9).
//   4. Al éxito, navega a /home (el redirect del router deja pasar
//      porque ahora hay sesión real del cambio de password).
//   5. Si falla → SnackBar con mensaje accionable.
//
// Pantalla **funcional, no bonita** (mismo scope que el resto de
// HDU-005/007). El diseño visual sale en HDU futura.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_exception.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/router/app_router.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // Handlers
  // ============================================================

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = getIt<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      await auth.updateUserPassword(newPassword: _newPasswordCtrl.text);
      if (!mounted) return;
      // El router se encarga del resto vía `redirect`: con la sesión
      // que Supabase refrescó al cambiar la password, /home está OK.
      router.go(AppRoute.home.path);
    } on AuthException catch (e) {
      // Mensaje ya viene en español y accionable (conventions §6, §8).
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
      appBar: AppBar(title: const Text('Nueva contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  key: const Key('reset_password_new'),
                  controller: _newPasswordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('reset_password_confirm'),
                  controller: _confirmPasswordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Confirma tu contraseña',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: _validateConfirmPassword,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('reset_password_submit'),
                  onPressed: _isLoading ? null : _onSubmit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cambiar contraseña'),
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

  /// Misma regla que el register: ≥ 8 caracteres. Supabase también
  /// la valida server-side, pero el chequeo cliente da feedback
  /// inmediato sin un round-trip.
  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Ingresa una contraseña';
    if (v.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    return null;
  }

  /// Verifica que el campo de confirmación coincida con la nueva
  /// password. Solo aplica si la nueva password ya pasó su propia
  /// validación (>= 8 chars) — si no, el mensaje de "mínimo 8" se
  /// muestra en el campo `new` y este campo no se queja.
  String? _validateConfirmPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Confirma tu contraseña';
    if (v != _newPasswordCtrl.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }
}
