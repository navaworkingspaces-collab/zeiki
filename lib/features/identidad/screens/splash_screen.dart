// `SplashScreen` — la primera impresión visual de Zeiki (HDU-006).
//
// **Lo que hace:**
//   - Renderiza el logo "Z", los textos "ZEIKI"/"LOADING", un progress
//     bar, el footer con la versión, y el fondo animado (50 partículas
//     + 3 anillos).
//   - Reproduce las 6 animaciones de entrada del legacy (scale,
//     rotation, opacity del logo; slide, opacity del texto; width del
//     progress bar) con `Tween` + `CurvedAnimation`.
//   - Cuando las animaciones terminan, hace un fade-out de 250ms y
//     navega a `/home` (el redirect del router decide el destino
//     final — `/login` si no hay sesión, `/unlock` si hay biometría).
//
// **Lo que NO hace (decisiones arquitectónicas del spec):**
//   - ❌ NO consulta `AuthService` ni `BiometricService` (AC10). Esa
//     lógica vive en el redirect.
//   - ❌ NO tiene `Future.delayed` artificial (AC9, "sin tiempo
//     mínimo"). La salida se coordina con el Cubit via
//     `BlocListener` + `AnimationController.addStatusListener`.
//   - ❌ NO decide a dónde ir. La única llamada de navegación es
//     `context.go(AppRoute.home.path)` — el redirect hace el resto.
//   - ❌ NO reintroduce el bug del cortado del legacy. El Cubit
//     coordina estados (`loading` → `ready` → `hidden`); nunca hay
//     doble `pushReplacement` ni `signOut()`.
//
// **Detrás de feature flag `AppFeature.splash` (AC2, AC16):**
//   - Si el flag está OFF al construir el widget, NO se renderiza el
//     branding y se transiciona directo a `SplashHidden` para
//     navegar al destino real (el redirect decide).
//   - Esto es la única decisión que el splash hace "por sí mismo":
//     saltar la animación cuando el flag dice que no debe mostrarse.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/expanding_rings.dart';
import '../../../app/widgets/particles_background.dart';
import '../../../app/widgets/zeiki_logo.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/tiers/app_feature.dart';
import '../../../core/tiers/tier_service.dart';
import '../blocs/splash_cubit.dart';

/// Splash screen de Zeiki. Detrás de `AppFeature.splash` (Target §10).
///
/// **Estructura:** el `SplashScreen` es un `ConsumerWidget` que consume
/// el `SplashCubit` del `BuildContext` (vía `BlocProvider`). El
/// `BlocProvider<SplashCubit>` se provee desde el router en
/// `app_router.dart` (siguiendo el patrón del resto de las features:
/// la lógica de DI vive en el router, no en la pantalla). Esto permite
/// que los tests inyecten un Cubit con un `BlocProvider.value` para
/// controlar las transiciones de estado.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SplashView();
  }
}

class _SplashView extends StatefulWidget {
  const _SplashView();

  @override
  State<_SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<_SplashView>
    with TickerProviderStateMixin {
  // Controller de la animación de entrada (2500ms, AC5).
  late final AnimationController _entryController;

  // Controller del fade-out de salida (250ms, AC11).
  late final AnimationController _fadeOutController;

  // Sub-animaciones de la entrada. Las 6 del legacy (HDU-EXPLORE-001
  // tabla B4) con los mismos intervalos y curvas.
  late final Animation<double> _logoScale;
  late final Animation<double> _logoRotation;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textOpacity;
  late final Animation<double> _progressBarWidth;

  // Versión leída de pubspec.yaml (AC8). Cacheada en el primer build.
  String? _appVersion;

  // Bandera para evitar navegar 2 veces (defensa contra `addStatusListener`
  // que dispara `completed` y luego `dismissed` en `reverse()`).
  bool _navigated = false;

  // Bandera para saber si el splash se debe mostrar o auto-navegar
  // por el feature flag OFF (AC2).
  late final bool _splashEnabled;

  @override
  void initState() {
    super.initState();

    // El TierService se consulta UNA vez al construir; si el flag
    // cambia después, NO afecta a este splash (es OK — los flags no
    // se "apagan" en runtime, se apagan en deploy).
    final tier = getIt<TierService>();
    _splashEnabled = tier.has(AppFeature.splash);

    _entryController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // Curvas de la animación de entrada (mismas que el legacy).
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _logoRotation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 50),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeIn),
      ),
    );
    _progressBarWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Cuando la animación de entrada COMPLETA, marcar el Cubit como
    // `ready`. El listener luego dispara el fade-out.
    _entryController.addStatusListener(_onEntryStatusChanged);

    // Cuando el fade-out COMPLETA, navegar a /home.
    _fadeOutController.addStatusListener(_onFadeOutStatusChanged);

    // Cargar la versión de pubspec.yaml (no awaited — la carga es
    // rápida y no bloquea la animación). Si falla, el footer muestra
    // "v?" como fallback.
    _loadAppVersion();

    if (_splashEnabled) {
      // Caso normal: reproducir la animación de entrada. Al terminar,
      // el listener emite `SplashReady` → `_onCubitStateChanged`
      // dispara el fade-out → al terminar, navega.
      _entryController.forward();
    } else {
      // Caso "feature flag OFF": no se muestra el branding. Saltar
      // directo a `hidden` para que el widget navegue inmediatamente.
      // Usamos `WidgetsBinding.instance.addPostFrameCallback` para
      // que el navigate-after-build no cause warnings.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<SplashCubit>().markHidden();
        }
      });
    }
  }

  @override
  void dispose() {
    _entryController.removeStatusListener(_onEntryStatusChanged);
    _fadeOutController.removeStatusListener(_onFadeOutStatusChanged);
    _entryController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  void _onEntryStatusChanged(AnimationStatus status) {
    // Filtramos `completed` para evitar disparar el ready dos veces
    // (el controller también emite `dismissed` cuando se hace reverse).
    if (status != AnimationStatus.completed) return;
    if (!mounted) return;
    context.read<SplashCubit>().markReady();
  }

  void _onFadeOutStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted) return;
    context.read<SplashCubit>().markHidden();
  }

  void _onCubitStateChanged(BuildContext context, SplashState state) {
    if (!mounted) return;
    if (state is SplashReady) {
      // El listener de "ready" arranca el fade-out. Sin delay: la
      // entrada ya terminó, no hay por qué esperar.
      _fadeOutController.forward();
    } else if (state is SplashHidden) {
      _navigateAway();
    }
  }

  void _navigateAway() {
    if (_navigated) return;
    _navigated = true;
    if (!mounted) return;
    // El splash NO decide el destino. Va a `/home` y deja que el
    // redirect haga su trabajo (login si no hay sesión, unlock si
    // hay biometría, home si está autenticado).
    context.go(AppRoute.home.path);
  }

  Future<void> _loadAppVersion() async {
    try {
      final raw = await rootBundle.loadString('pubspec.yaml');
      final version = _parseVersionFromPubspec(raw);
      if (mounted) {
        setState(() => _appVersion = version);
      }
    } catch (_) {
      // Si falla, dejamos `_appVersion` en null y el footer muestra
      // "v?" como fallback. NO crasheamos el splash por esto.
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SplashCubit, SplashState>(
      // `listenWhen` evita re-builds innecesarios.
      listenWhen: (SplashState prev, SplashState curr) => prev != curr,
      listener: _onCubitStateChanged,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: AnimatedBuilder(
          animation: _fadeOutController,
          builder: (BuildContext context, Widget? child) {
            // 1.0 = totalmente visible (entrada), 0.0 = totalmente
            // invisible (fade-out terminado). El widget se queda
            // montado durante el fade-out (AC11) y se desmonta cuando
            // el router navega a la nueva ruta.
            final opacity = 1.0 - _fadeOutController.value;
            return Opacity(
              opacity: opacity,
              child: child,
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Fondo animado: partículas (8s loop) + anillos (3s loop).
              // Van DEBAJO del contenido (primeros hijos del Stack).
              const ParticlesBackground(),
              const ExpandingRings(),
              // Contenido principal (logo + texto).
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _buildLogo(),
                        const SizedBox(height: 40),
                        _buildBrandText(),
                        const SizedBox(height: 20),
                        _buildTagline(),
                      ],
                    ),
                  ),
                ),
              ),
              // Footer + progress bar (bottom).
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildFooter(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    // Si el flag está OFF, NO se renderiza el logo. El Stack ya
    // mostró un fondo vacío que se va a desvanecer.
    if (!_splashEnabled) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _entryController,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: _logoOpacity.value,
          child: Transform.rotate(
            angle: _logoRotation.value,
            child: Transform.scale(
              scale: _logoScale.value,
              child: child,
            ),
          ),
        );
      },
      child: const ZeikiLogo(size: 100),
    );
  }

  Widget _buildBrandText() {
    if (!_splashEnabled) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _entryController,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: _textOpacity.value,
          child: FractionalTranslation(
            translation: _textSlide.value,
            child: child,
          ),
        );
      },
      child: const Text(
        'ZEIKI',
        style: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.bold,
          color: AppColors.textWhite,
          letterSpacing: 8,
          shadows: <Shadow>[
            Shadow(
              color: AppColors.primaryPurple,
              blurRadius: 30,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagline() {
    if (!_splashEnabled) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _entryController,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: _textOpacity.value,
          child: child,
          // El `_textSlide` se aplica al texto "ZEIKI" pero el tagline
          // comparte el `_textOpacity` (mismo intervalo 0.3-0.8).
        );
      },
      child: const Text(
        'LOADING',
        style: TextStyle(
          fontSize: 18,
          color: Colors.white70,
          letterSpacing: 4,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    // El footer SÍ se muestra aunque el flag esté OFF (es metadata
    // útil, no es branding). Pero como en el caso OFF el splash
    // navega inmediato, el footer apenas se ve.
    final versionText = _appVersion != null ? 'v$_appVersion' : 'v?';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$versionText · Developed by Zeiki Team',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white60,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 300,
            height: 4,
            child: AnimatedBuilder(
              animation: _entryController,
              builder: (BuildContext context, Widget? child) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _progressBarWidth.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.primaryPurple,
                      AppColors.accentPurple,
                      AppColors.primaryPurple,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parsea la línea `version:` de un `pubspec.yaml`. Lanza
/// `FormatException` si no la encuentra.
///
/// **Por qué no usamos `package_info_plus` (conventions §11):**
/// agregar una dep solo para leer la versión local es desproporcionado.
/// El formato `version: X.Y.Z+N` (o `version: X.Y.Z`) es estable y
/// se parsea con una regex en 5 líneas.
String _parseVersionFromPubspec(String pubspecContent) {
  final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:\+\d+)?)\s*$',
          multiLine: true)
      .firstMatch(pubspecContent);
  if (match == null) {
    throw const FormatException(
      'No se encontró la línea `version:` en pubspec.yaml',
    );
  }
  return match.group(1)!;
}
