# ADR-002: Flutter como cliente

**Estado:** Aceptado
**Fecha:** 2026-07-29

## Contexto

Zeiki necesita un cliente móvil para facturación CFDI 4.0. El target inicial es Android (México). El equipo es chico y debe mantener un solo codebase. La UI no requiere animaciones extremas ni gráficos pesados, pero sí formularios complejos, validación, manejo de estado y buena experiencia offline-friendly.

## Decisión

Toda la UI y lógica de cliente se construye en **Flutter** (Dart 3.9+).

- **State management:** BLoC (ver ADR-004).
- **DI:** GetIt (ver ADR-005).
- **HTTP nativo:** `http` + `supabase_flutter` para los edge cases.
- **Storage seguro:** `flutter_secure_storage` para credenciales.

## Por qué

- **Un solo codebase** para Android (target principal) y, si se requiere después, iOS con esfuerzo marginal.
- **Dart es un lenguaje moderno** con null safety, async/await, y buen tooling.
- **Ecosistema maduro** para lo que Zeiki necesita: formularios, validación, secure storage, BLoC.
- **Productividad del equipo:** un solo lenguaje, una sola toolchain, una sola base de conocimiento.

## Alternativas consideradas

- **React Native:** viable, pero el ecosistema de paquetes para flujos fiscales (firmas XML, validaciones CFDI) es más débil en JS que en Dart.
- **Android nativo (Kotlin):** mejor rendimiento teórico, pero duplica el trabajo si mañana se quiere iOS.
- **iOS nativo (Swift):** no aplica para el target principal.
- **Kotlin Multiplatform:** interesante, pero el equipo no tiene experiencia y el ecosistema de UI es más débil.

## Trade-offs

- **A favor:** velocidad de desarrollo, un solo codebase, ecosistema.
- **En contra:** iOS no priorizado (aceptable para el target). Renderización vs nativo (no relevante para una app de formularios). Si en el futuro se necesita UI muy específica de plataforma, se encapsula en un plugin nativo.

## Cuándo se revisa

- Se vuelve crítico soportar iOS con release simultáneo a Android.
- Se necesita UI muy específica de plataforma que Flutter no soporta bien.
- El rendimiento de animaciones o gráficos se vuelve cuello de botella real.
