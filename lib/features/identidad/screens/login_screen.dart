// Pantalla de login (HDU-005, AC13-AC17).
//
// Decisión de scope (spec §Plan técnico paso 9): esta pantalla muestra
// AMBOS métodos (correo y Google). El usuario elige. Si elige el
// método incorrecto, Supabase rechaza con error y mostramos mensaje
// claro. La auto-detección sale en HDU futura (§Fuera de scope).
//
// Por qué este approach: la auto-detección requiere un `signInWithIdToken`
// "ciego" antes de cada login para saber con qué método se creó la
// cuenta — eso es fricción innecesaria y un riesgo de seguridad
// (exponer si la cuenta existe). El enfoque de "mostrar ambos y dejar
// que Supabase decida" es más simple y más transparente (conventions
// §8: "Nunca esconden la excepción original").
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_exception.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/router/app_router.dart';
import '../widgets/biometric_activation_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = getIt<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      await auth.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      // HDU-005b AC5-AC9: popup "¿Activar huella?" después del login
      // exitoso. One-shot por sesión.
      await _maybeShowBiometricActivationDialog(context);
      router.go(AppRoute.home.path);
    } on AuthException catch (e) {
      if (!mounted) return;
      // El mensaje ya viene mapeado. Si la cuenta fue creada con
      // Google, el error genérico de "credenciales inválidas" puede
      // confundir — la spec sugiere un mensaje específico. Por ahora
      // el mapeo devuelve "Correo o contraseña incorrectos." y eso
      // cubre el caso: si la cuenta es de Google, el password no
      // matchea (porque no tiene password). El usuario prueba el
      // botón de Google y entra.
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

  Future<void> _onGoogle() async {
    setState(() => _isLoading = true);
    final auth = getIt<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      await auth.signInWithGoogle();
      if (!mounted) return;
      // HDU-005b AC5-AC9: mismo popup que en el flujo de email.
      await _maybeShowBiometricActivationDialog(context);
      router.go(AppRoute.home.path);
    } on UserCancelledAuthFlow {
      // AC10: cancelar el popup NO es error.
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
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  key: const Key('login_email'),
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
                  key: const Key('login_password'),
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
                  key: const Key('login_submit'),
                  onPressed: _isLoading ? null : _onSubmit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('login_google'),
                  onPressed: _isLoading ? null : _onGoogle,
                  icon: const Icon(Icons.login),
                  label: const Text('Entrar con Google'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => context.go(AppRoute.register.path),
                  child: const Text('¿No tienes cuenta? Créala'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Biometría (HDU-005b, AC5-AC9)
  // ============================================================

  /// Muestra el popup "¿Activar huella?" si aplica (one-shot por
  /// sesión). Misma lógica que en `RegisterScreen`. La factoricé
  /// aquí en vez de extraer a un helper compartido porque la lógica
  /// es trivial (5 líneas) y mantenerla local hace más fácil leer
  /// cada pantalla sin saltar entre archivos. Si crece (ej. más
  /// post-auth hooks), sale a un helper.
  Future<void> _maybeShowBiometricActivationDialog(
    BuildContext context,
  ) async {
    final auth = getIt<AuthService>();
    final biometric = getIt<BiometricService>();
    final activation = BiometricActivationService(biometric: biometric);
    final userId = auth.currentUserId;
    if (userId == null) return;
    if (!await activation.consumeIfShouldShow(userId: userId)) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => BiometricActivationDialog(
        biometric: biometric,
        userId: userId,
      ),
    );
  }

  // ============================================================
  // Validadores
  // ============================================================

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu correo';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(v)) return 'Correo no válido';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Ingresa tu contraseña';
    return null;
  }
}
