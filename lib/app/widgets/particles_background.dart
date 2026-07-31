// Fondo de partículas animadas para el splash (HDU-006, AC6).
//
// Migrado del legacy `seiki_app@0d18d7d/lib/features/splash/presentation/
// widgets/particles_background.dart` con limpieza menor:
//
//   - `Random()` reemplazado por una instancia única de `dart:math` para
//     no recrearla en cada partícula (era funcional pero ineficiente).
//   - Comentarios migrados a `// ✅ ...`风格的 "por qué" (conventions §2).
//   - `pow` de `dart:math` (no `import 'dart:math'` implícito).
//
// **Comportamiento:** 50 partículas púrpura semi-transparentes que
// flotan hacia arriba en un loop de 8 segundos. Cada partícula tiene
// `delay` y `duration` aleatorios para que el patrón se vea orgánico
// (no sincronizado). El `opacity` aparece en 0-10%, mantiene 10-90%,
// desaparece 90-100% para un fade in/out suave.
//
// **Independiente del controller principal del splash:** este widget
// maneja su propio `AnimationController(duration: 8s)..repeat()`. La
// entrada del splash (2500ms) y este loop (8s) NO se sincronizan
// intencionalmente — son piezas de UI independientes.
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ParticlesBackground extends StatefulWidget {
  const ParticlesBackground({super.key});

  @override
  State<ParticlesBackground> createState() => _ParticlesBackgroundState();
}

class _ParticlesBackgroundState extends State<ParticlesBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<Particle> _particles = <Particle>[];

  static const int particleCount = 50;
  static const Duration _loopDuration = Duration(seconds: 8);
  static final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeParticles();
    _controller = AnimationController(
      duration: _loopDuration,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initializeParticles() {
    for (int i = 0; i < particleCount; i++) {
      _particles.add(
        Particle(
          offset: Offset(
            _randomDouble(0.0, 1.0),
            _randomDouble(0.0, 1.0),
          ),
          delay: _randomDouble(0.0, _loopDuration.inSeconds.toDouble()),
          duration: _randomDouble(6.0, 10.0),
        ),
      );
    }
  }

  double _randomDouble(double min, double max) {
    return (_random.nextDouble() * (max - min)) + min;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          painter: _ParticlesPainter(
            particles: _particles,
            animationValue: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class Particle {
  const Particle({
    required this.offset,
    required this.delay,
    required this.duration,
  });

  /// Posición X/Y como fracción (0.0–1.0) del tamaño del canvas.
  final Offset offset;

  /// Retraso antes de que la partícula empiece a moverse. En segundos.
  final double delay;

  /// Duración del ciclo de la partícula. En segundos.
  final double duration;
}

class _ParticlesPainter extends CustomPainter {
  _ParticlesPainter({
    required this.particles,
    required this.animationValue,
  });

  final List<Particle> particles;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = AppColors.primaryPurple.withAlpha(153);

    for (final Particle particle in particles) {
      // Calcula el progreso del ciclo individual, considerando el delay
      // aleatorio de la partícula. Se mantiene en [0.0, 1.0] con `clamp`
      // defensivo para `delay > duration` (caso raro pero posible).
      final rawProgress =
          (animationValue * 8.0 + particle.delay) % particle.duration /
              particle.duration;
      final progress = _easeInOutCubic(rawProgress.clamp(0.0, 1.0));

      final currentX = particle.offset.dx * size.width;
      // Movimiento vertical hacia arriba; se sale por arriba (factor 1.2).
      final currentY =
          size.height - (progress * size.height * 1.2);
      final currentOffset = Offset(currentX, currentY);

      final opacity = _calculateOpacity(progress);
      final paint = Paint()
        ..color = baseColor.withAlpha((opacity * 255).toInt())
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentOffset, 2.0, paint);
    }
  }

  /// Fade-in en los primeros 10%, fade-out en los últimos 10%.
  double _calculateOpacity(double progress) {
    if (progress < 0.1) return progress / 0.1;
    if (progress > 0.9) return (1.0 - progress) / 0.1;
    return 1.0;
  }

  double _easeInOutCubic(double x) {
    return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2;
  }

  @override
  bool shouldRepaint(_ParticlesPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
