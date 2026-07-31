// `SplashCubit` — la máquina de estados del splash (HDU-006, AC12, AC13).
//
// El splash tiene estado complejo: animaciones, sub-estados de carga,
// decisión de feature flag. Encapsularlo en un Cubit permite:
//   - Testear la lógica de estado sin widget tree (conventions §3).
//   - Reaccionar a cambios de estado desde el widget con
//     `BlocListener` (patrón BLoC estándar, ADR-004).
//   - Exponer el progreso de la animación de entrada a otros
//     consumidores (tests, telemetría futura) via `animationProgress`.
//
// **Decisiones de diseño (acordadas con el spec):**
//   - Cubit, no Bloc: no hay eventos, solo transiciones de estado
//     disparadas por el widget. Más simple que `Bloc` con `Event`.
//   - `SplashState` es una **sealed class** con 3 valores:
//     `SplashLoading`, `SplashReady`, `SplashHidden` (AC13).
//   - `animationProgress` es broadcast para que múltiples listeners
//     (widget + tests) puedan suscribirse simultáneamente.
//   - `setAnimationProgress` y `close` son idempotentes / no-op
//     post-close: el Cubit no debe crashear si el widget lo usa
//     después de un dispose (lección de HDU-003 / HDU-004).
//
// **Lo que NO hace este Cubit:**
//   - NO decide a dónde ir después (eso es el redirect del router,
//     ADR-012). Solo expone el estado `hidden` para que el widget
//     navegue.
//   - NO consulta `AuthService` ni `BiometricService` (AC10). Esa
//     lógica vive en el redirect y en el `UnlockScreen`.
//   - NO consulta el feature flag. Eso lo hace el widget en
//     `initState` (porque el Cubit es puro: no debe depender de
//     GetIt ni de `TierService`).
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Estados del splash (AC13). Sealed class para que el `switch` sobre
/// el estado sea exhaustivo en tiempo de compilación.
sealed class SplashState extends Equatable {
  const SplashState();
}

/// Estado inicial. La animación de entrada está corriendo en el widget.
final class SplashLoading extends SplashState {
  const SplashLoading();

  @override
  List<Object?> get props => <Object?>[];
}

/// La animación de entrada terminó. El widget está a punto de iniciar
/// el fade-out.
final class SplashReady extends SplashState {
  const SplashReady();

  @override
  List<Object?> get props => <Object?>[];
}

/// El fade-out terminó. El widget debe navegar a la ruta real (el
/// redirect del router decide el destino final).
final class SplashHidden extends SplashState {
  const SplashHidden();

  @override
  List<Object?> get props => <Object?>[];
}

class SplashCubit extends Cubit<SplashState> {
  SplashCubit() : super(const SplashLoading());

  // Stream de progreso de la animación de entrada (AC12). Broadcast
  // para que múltiples listeners puedan suscribirse.
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  /// Stream de progreso de la animación de entrada (0.0 → 1.0). El
  /// widget escribe con `setAnimationProgress()` en su
  /// `AnimationController.addListener`; los tests pueden escuchar
  /// para verificar que la animación corre sin montar el widget tree.
  Stream<double> get animationProgress => _progressController.stream;

  /// Marca la animación de entrada como completada. Llamado por el
  /// widget cuando su `AnimationController` emite
  /// `AnimationStatus.completed`.
  void markReady() {
    if (state is SplashReady || state is SplashHidden) return;
    emit(const SplashReady());
  }

  /// Marca el splash como listo para navegar. Llamado por el widget
  /// cuando su fade-out animation emite `AnimationStatus.completed`,
  /// o inmediatamente en el caso de "feature flag OFF" donde se
  /// salta la animación de entrada.
  void markHidden() {
    if (state is SplashHidden) return;
    emit(const SplashHidden());
  }

  /// Emite el progreso actual de la animación de entrada al stream
  /// `animationProgress`. No-op si el Cubit ya cerró (defensa contra
  /// race conditions entre `dispose()` y el listener de animación,
  /// ver HDU-003).
  void setAnimationProgress(double value) {
    if (_progressController.isClosed) return;
    _progressController.add(value);
  }

  @override
  Future<void> close() {
    if (!_progressController.isClosed) {
      _progressController.close();
    }
    return super.close();
  }
}
