// Monitor de inactividad de Zeiki (HDU-005b, AC17-AC21, AC26).
//
// Dos piezas:
//
// 1. `InactivityTimer` — clase pura con `start() / reset() / dispose()`.
//    Mantiene un `Timer` con el `Duration` configurado; al expirar
//    llama al `onTimeout`. Se testea con `fake_async`.
//
// 2. `InactivityMonitor` — widget que envuelve la app. Detecta
//    pointer events / scroll notifications y llama a `InactivityTimer.
//    reset()` en cada uno. NO se pausa en background (matchea bancos).
//
// **Por qué se separan:** la lógica del timer es pura (sin widget
// tree), testeable con `fakeAsync` sin esperar 5 minutos. El widget
// solo se encarga de la captura de gestos. Mismo principio que
// `TierService` (lógica) + el widget que la consume (HDU-003).
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'auth_service_config.dart';

/// Factory de `Timer` inyectable para tests. El default usa
/// `Timer.new`; en tests se sustituye por un fake que no se ejecuta
/// para poder verificar efectos secundarios (cancel + nuevo timer)
/// sin esperar tiempo real.
typedef TimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

/// Callback que el timer invoca al expirar.
typedef TimeoutCallback = FutureOr<void> Function();

/// Lógica pura del timer de inactividad. Se separa del widget para
/// poder testearla con `fakeAsync` (control total del tiempo).
///
/// **Patrón de guards** (lección de HDU-003 / HDU-004): `dispose()`
/// es idempotente, `reset()` post-dispose es no-op. Esto protege
/// contra re-entry (desmontar + remontar el widget) y contra un
/// último `reset()` que llega justo antes del dispose.
class InactivityTimer {
  InactivityTimer({
    required this.config,
    required this.onTimeout,
    TimerFactory? timerFactory,
  }) : _timerFactory = timerFactory ?? Timer.new;

  final AuthServiceConfig config;
  final TimeoutCallback onTimeout;
  final TimerFactory _timerFactory;

  Timer? _timer;
  bool _disposed = false;

  /// Arma el primer timer. Llamar una vez al inicializar.
  void start() {
    if (_disposed) return;
    _reset();
  }

  /// Cancela el timer actual y arma uno nuevo desde cero. Llamar en
  /// cada interacción del usuario (tap, scroll, etc.).
  ///
  /// **No-op después de `dispose()`** — defensa contra un último
  /// reset que llegue cuando el widget ya se desmontó.
  void reset() {
    if (_disposed) return;
    _reset();
  }

  /// Cancela el timer y marca el monitor como disposed. Llamar una
  /// vez en el `dispose()` del widget.
  ///
  /// **Idempotente** — llamar 2 veces no lanza.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  void _reset() {
    _timer?.cancel();
    _timer = _timerFactory(config.inactivityTimeout, () {
      if (_disposed) return;
      // El callback puede ser `FutureOr<void>`; lo dejamos correr.
      // Si lanza, el `Zone` lo captura — no silenciamos errores
      // (conventions §8: "no catch vacío").
      onTimeout();
    });
  }
}

/// Widget que envuelve la app y resetea el `InactivityTimer` en
/// cada pointer event / scroll notification.
///
/// **Cómo se conecta al `AuthService`:** el caller pasa un
/// `signOutFn: () => authService.signOut()`. El monitor NO conoce
/// `AuthService` directamente — eso lo hace más fácil de testear
/// (inyecto un fake) y respeta la regla de "core no depende de
/// features" (Target §6).
///
/// **Por qué `Listener` + `NotificationListener`:** los pointer
/// events (down, move, signal) cubren taps, drags y clicks. Los
/// `ScrollNotification` cubren scrolls en `ListView`/`ScrollView`
/// (que internamente NO generan pointer events, sino `ScrollNotification`).
/// `HitTestBehavior.translucent` permite que los pointer events
/// burbujeen a los hijos sin consumirlos.
class InactivityMonitor extends StatefulWidget {
  const InactivityMonitor({
    super.key,
    required this.child,
    this.config = const AuthServiceConfig(),
    required this.signOutFn,
    this.timerFactory,
  });

  final Widget child;
  final AuthServiceConfig config;

  /// Lo que pasa cuando el timer vence. En producción =
  /// `() => getIt<AuthService>().signOut()`.
  final Future<void> Function() signOutFn;

  /// Inyectable para tests. Default = `Timer.new`.
  final TimerFactory? timerFactory;

  @override
  State<InactivityMonitor> createState() => _InactivityMonitorState();
}

class _InactivityMonitorState extends State<InactivityMonitor>
    with WidgetsBindingObserver {
  late InactivityTimer _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = InactivityTimer(
      config: widget.config,
      onTimeout: widget.signOutFn,
      timerFactory: widget.timerFactory,
    );
    _timer.start();
  }

  @override
  void dispose() {
    _timer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// **No pausamos el timer en background** (AC19, matchea bancos).
  /// Si la app vuelve al foreground después de > X minutos, el
  /// callback ya se ejecutó → `signOut` → `authStateChanges` emite
  /// → el `GoRouter.refreshListenable` (conectado en
  /// `service_locator.dart`) re-evalúa el redirect → manda a
  /// `/login` o `/unlock` según si `biometricEnabled` está activo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No-op explícito: documentamos la decisión de NO pausar.
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _timer.reset(),
      onPointerMove: (_) => _timer.reset(),
      onPointerSignal: (_) => _timer.reset(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _timer.reset();
          // Devolvemos `false` para NO consumir la notificación —
          // otros listeners (ej. un `ScrollController` del feature)
          // también la necesitan.
          return false;
        },
        child: widget.child,
      ),
    );
  }
}
