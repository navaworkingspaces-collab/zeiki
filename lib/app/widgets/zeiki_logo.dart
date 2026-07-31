// Logo "Z" de Zeiki dibujado con `CustomPaint` (HDU-006, AC4).
//
// Migrado del legacy `seiki_app@0d18d7d/lib/app/widgets/zeiki_logo.dart`
// con UN cambio intencional:
//
//   - ❌ Eliminado el parámetro `withGlow` (era **banda muerta** en el
//     legacy: declarado y recibido por el painter pero nunca consultado
//     en `paint()`). El glow del splash viene de los `BoxShadow` del
//     `Container` exterior (legacy `splash_page.dart:246-262`), no del
//     widget. Lo que el splash renderiza lo decide el splash, no el logo.
//
// **Geometría:** una "Z" estilizada formada por un polígono principal
// (11 vértices) más 2 triángulos de highlight blanco al 30% opacity. El
// gradiente es `accentPurple` (top-left) → `primaryPurple` (bottom-right),
// mismo que el HTML original del que viene el branding.
//
// **Sin assets:** el logo es código, no SVG/PNG. Esto es deuda técnica
// documentada (HDU-EXPLORE-001 hallazgo sorpresa #1, riesgo #2 de la
// spec de HDU-006). Migrar a SVG sale en HDU-EXPLORE futura.
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Logo "Z" de Zeiki. Se dibuja con `CustomPaint`, no usa assets.
class ZeikiLogo extends StatelessWidget {
  const ZeikiLogo({super.key, this.size = 200});

  /// Tamaño del lado del cuadrado donde se dibuja el logo. Default 200
  /// (escala base de las coordenadas del legacy).
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ZeikiLogoPainter(),
    );
  }
}

class _ZeikiLogoPainter extends CustomPainter {
  const _ZeikiLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200;

    // Gradiente exacto del HTML (top-left → bottom-right).
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const <Color>[
        AppColors.accentPurple,
        AppColors.primaryPurple,
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.fill;

    // Polígono principal: la "Z" estilizada.
    final mainPath = Path();
    mainPath.moveTo(50 * scale, 40 * scale);
    mainPath.lineTo(150 * scale, 40 * scale);
    mainPath.lineTo(160 * scale, 55 * scale);
    mainPath.lineTo(90 * scale, 55 * scale);
    mainPath.lineTo(160 * scale, 145 * scale);
    mainPath.lineTo(160 * scale, 160 * scale);
    mainPath.lineTo(40 * scale, 160 * scale);
    mainPath.lineTo(40 * scale, 145 * scale);
    mainPath.lineTo(130 * scale, 145 * scale);
    mainPath.lineTo(40 * scale, 55 * scale);
    mainPath.lineTo(40 * scale, 40 * scale);
    mainPath.close();
    canvas.drawPath(mainPath, paint);

    // Brillos blancos al 30% opacity (76/255).
    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha(76)
      ..style = PaintingStyle.fill;

    // Triángulo superior.
    final topHighlight = Path();
    topHighlight.moveTo(150 * scale, 40 * scale);
    topHighlight.lineTo(160 * scale, 55 * scale);
    topHighlight.lineTo(90 * scale, 55 * scale);
    topHighlight.lineTo(80 * scale, 40 * scale);
    topHighlight.close();
    canvas.drawPath(topHighlight, highlightPaint);

    // Triángulo inferior.
    final bottomHighlight = Path();
    bottomHighlight.moveTo(160 * scale, 145 * scale);
    bottomHighlight.lineTo(160 * scale, 160 * scale);
    bottomHighlight.lineTo(40 * scale, 160 * scale);
    bottomHighlight.lineTo(50 * scale, 145 * scale);
    bottomHighlight.close();
    canvas.drawPath(bottomHighlight, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
