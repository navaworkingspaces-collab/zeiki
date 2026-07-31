// Paleta de colores de marca de Zeiki (HDU-006).
//
// Migrada del legacy `seiki_app` (commit `0d18d7d`,
// `lib/app/theme/app_theme.dart:5-11`). Mismas constantes exactas, no
// se "mejoraron" porque son la identidad de marca.
//
// **Por qué existe en `lib/core/theme/` y no en `lib/app/theme/`:** el
// legacy usaba `lib/app/theme/` porque la app era monolítica. Zeiki
// tiene `lib/features/`, `lib/core/`, `lib/app/` separados (Target §6);
// la paleta de marca es `core` (cross-cutting, sin dominio).
//
// **Lo que NO está aquí (reservado del legacy):**
//   - `darkPurple` (`0xFF6d28d9`) — no se usa en el splash ni en
//     ningún screen actual. Reservado para HDU futura de design system.
//   - `backgroundDarker` (`0xFF16213e`) — idem.
//   - `accentGreen` (`Colors.green`) — para íconos de "configuración
//     SAT" del legacy, no en Zeiki todavía.
// Solo expongo lo que el splash + screens actuales necesitan, para
// forzar que cualquier color nuevo pase por aquí (conventions §10: una
// sola fuente de verdad por configuración).
import 'package:flutter/material.dart';

/// Paleta de marca de Zeiki.
class AppColors {
  const AppColors._();

  /// Púrpura principal (`#7c3aed`). Botones, logo, anillos, partículas.
  static const Color primaryPurple = Color(0xFF7c3aed);

  /// Púrpura de acento (`#a855f7`). Gradientes del logo y del progress bar.
  static const Color accentPurple = Color(0xFFa855f7);

  /// Fondo oscuro (`#1a1a2e`). Fondo del splash y `scaffoldBackgroundColor`
  /// global de la app.
  static const Color backgroundDark = Color(0xFF1a1a2e);

  /// Alias semántico para texto blanco. Coincide con el legacy
  /// (`app_theme.dart:11`).
  static const Color textWhite = Colors.white;
}
