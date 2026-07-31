// Anillos concéntricos expansivos para el splash (HDU-006, AC6).
//
// Migrado del legacy `seiki_app@0d18d7d/lib/features/splash/presentation/
// widgets/expanding_rings.dart` sin cambios de comportamiento. 3 anillos
// púrpura semi-transparentes se expanden desde el centro en un loop
// de 3 segundos, con delays escalonados (i × 0.333) para crear el
// efecto de "ondas concéntricas".
//
// **Independiente del controller principal del splash:** este widget
// maneja su propio `AnimationController(duration: 3s)..repeat()`.
// El `opacity` aparece en 0-20% y se desvanece en 20-100% para que el
// "ring" no se sienta cortado al final del ciclo.
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ExpandingRings extends StatefulWidget {
  const ExpandingRings({super.key});

  @override
  State<ExpandingRings> createState() => _ExpandingRingsState();
}

class _ExpandingRingsState extends State<ExpandingRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          painter: _ExpandingRingsPainter(animationValue: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ExpandingRingsPainter extends CustomPainter {
  _ExpandingRingsPainter({required this.animationValue});

  final double animationValue;

  static const int _ringCount = 3;
  static const double _initialRadius = 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // El "tamaño máximo" del canvas se mide por el ancho (típicamente
    // menor que la altura en portrait); se multiplica por 1.5 para que
    // los anillos se expandan más allá del viewport antes de fade-out.
    final maxRadius = size.width * 1.5;

    for (int i = 0; i < _ringCount; i++) {
      // Delay escalonado: 0, 0.333, 0.666 del ciclo total.
      final ringProgress = (animationValue + i * 0.333) % 1.0;
      final currentRadius = _calculateRadius(ringProgress, maxRadius);
      final opacity = _calculateRingOpacity(ringProgress);
      if (opacity <= 0) continue;

      final paint = Paint()
        ..color = AppColors.primaryPurple.withAlpha((opacity * 255).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, currentRadius, paint);
    }
  }

  double _calculateRadius(double progress, double maxSize) {
    return _initialRadius + (progress * (maxSize - _initialRadius));
  }

  /// Fade-in en los primeros 20%, fade-out en el 80% restante.
  double _calculateRingOpacity(double progress) {
    if (progress < 0.2) return progress / 0.2;
    return 1.0 - ((progress - 0.2) / 0.8);
  }

  @override
  bool shouldRepaint(_ExpandingRingsPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
