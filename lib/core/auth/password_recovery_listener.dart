// Listener de `AuthChangeEvent.passwordRecovery` (HDU-007).
//
// **Por qué existe — red de seguridad (knowledge reuse del legacy
// `seiki_legacy_temp/lib/main.dart:79-97`):** cuando el user llega
// por el deep link de reset password
// (`io.supabase.flutter://reset-password/?token=...`), Supabase crea
// una sesión temporal al procesar el token (necesaria para que
// `updateUser` funcione en `ResetPasswordScreen`). Sin este listener,
// el flujo puede fallar en una condición de carrera:
//
//   1. El intent del deep link llega y Supabase procesa el token →
//      emite `passwordRecovery` + crea sesión temporal.
//   2. `wireAppLinksDeepLinks` (en `main.dart`, llamado DESPUÉS de
//      `runApp`) recibe el URI y hace `router.go('/auth/reset-password')`.
//   3. El redirect del router evalúa la URL con sesión temporal →
//      como `/auth/reset-password` es **terminal** (no redirige), se
//      muestra la pantalla correctamente.
//
// El problema es si el paso 1 ocurre ANTES del paso 2: Supabase emite
// `passwordRecovery` con sesión temporal, el redirect no se ha
// evaluado todavía, y el `authStateChanges` se dispara sin que
// `wireAppLinksDeepLinks` haya navegado. Sin este listener, el user
// queda con la sesión creada pero sin pantalla de reset (la sesión
// temporal existe, pero la URL actual sigue siendo `/splash` o la
// que estuviera antes). El listener cierra esa ventana: cuando
// Supabase emite `passwordRecovery`, navegamos nosotros al reset.
//
// **Knowledge reuse del legacy:** el `seiki_app` legacy tenía el
// mismo patrón (`onAuthStateChange.listen(...)` con handler para
// `AuthChangeEvent.passwordRecovery` que hacía
// `navigatorKey.currentState.pushReplacementNamed(AppRoutes.resetPassword)`).
// La diferencia es que el legacy usaba un `GlobalKey<NavigatorState>`
// para navegar; nosotros usamos el `GoRouter` registrado en GetIt.
//
// **Por qué se registra como `LazySingleton`:** para que
// `getIt.reset()` (en el `tearDown` de los tests) llame a
// `onDispose()` y cancele la suscripción, evitando memory leaks
// entre tests. En producción, la suscripción vive lo que vive el
// proceso — el dispose se llama en el cold start de un test (si se
// reutiliza el proceso), no en la app real.
import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../router/app_router.dart';
import 'auth_service.dart';

class PasswordRecoveryListener implements Disposable {
  PasswordRecoveryListener({
    required AuthService auth,
    required GoRouter router,
  }) : _subscription = auth.authStateChanges.listen((state) {
          if (state.event == sb.AuthChangeEvent.passwordRecovery) {
            router.go(AppRoute.resetPassword.path);
          }
        });

  final StreamSubscription<sb.AuthState> _subscription;

  /// Llamado por `getIt.reset()` cuando el tipo implementa
  /// `Disposable`. Cancela la suscripción para liberar el closure
  /// que referencia al `AuthService` y al `GoRouter`.
  @override
  FutureOr<void> onDispose() {
    _subscription.cancel();
  }
}
