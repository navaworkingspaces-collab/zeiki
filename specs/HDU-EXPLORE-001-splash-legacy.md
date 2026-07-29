# HDU-EXPLORE-001 — Exploración del splash legacy (seiki_app)

**Tipo:** chore (research)
**Prioridad:** alta
**Estado:** pendiente
**Fecha:** 2026-07-29
**Sistema externo a explorar:** código legacy en `navaworkingspaces-collab/seiki_app` (read-only, en `C:\Users\Pc\...` o donde Hugo lo tenga clonado localmente).
**HDU de implementación que depende de esto:** HDU-002 (splash nuevo de Zeiki con arquitectura actual).

---

## Check de entendimiento (3 líneas)

- Lo que quieres: ir a ver cómo estaba hecho el splash legacy.
- Vas a saber que está bien cuando: podamos replicarlo acá sin fricción con la arquitectura nueva y los protocolos actuales.
- Esto NO se va a hacer: no se van a migrar las rutas legacy que decidían cuándo se mostraba o no el splash.

---

## Contexto

La HDU-002 va a ser el splash nuevo de Zeiki. La idea base es migrar el splash del proyecto legacy (`seiki_app`) — su look & feel (identidad de marca) y su comportamiento general. Pero el splash legacy tenía un bug conocido: se cortaba antes de terminar su tiempo previsto (Hugo reportó: "si el splash duraba 5s, se cortaba a los 3s").

**Lo que esta exploración debe resolver:**

1. Dónde está el código del splash legacy (archivos, paths).
2. Cómo se ve (identidad de marca: logo, colores, tipografía, animaciones).
3. Cuál es su lógica de cuándo aparece y cuándo desaparece (timer, future, init, feature flag).
4. **Por qué se cortaba** (la causa raíz del bug — esto es crítico para no replicarlo).
5. Qué assets (imágenes, fuentes, etc.) necesita.
6. Qué se migra tal cual, qué se descarta, qué se mejora.

**Por qué es importante hacerla ANTES de implementar:**

- Migrar el bug del cortado sería peor que empezar de cero.
- La identidad de marca es un asset que vale la pena reusar (no re-diseñar).
- Entender la causa raíz del bug guía la arquitectura del splash nuevo (BLoC, go_router, animación, etc.).
- Sin esto, la HDU-002 sería implementar a ciegas.

---

## Pregunta(s) a responder

Cada pregunta debe responderse con evidencia (archivo:línea, screenshot, log, o cita del código).

### Bloque A — Ubicación y estructura

- **A1.** ¿En qué archivo(s) está definido el splash legacy? (path completo en el repo legacy).
- **A2.** ¿Es un widget standalone (`SplashPage`, `SplashScreen`) o parte de `main.dart`?
- **A3.** ¿Hay tests asociados al splash en el legacy? Si sí, ¿qué cubren?

### Bloque B — Identidad de marca (look & feel)

- **B1.** ¿Qué logo se muestra? (path al asset, formato, dimensiones).
- **B2.** ¿Qué colores usa? (paleta exacta: primary, background, accent).
- **B3.** ¿Qué tipografía? (fuente, weight, tamaño).
- **B4.** ¿Hay animaciones? (fade-in, scale, slide, custom). ¿Con qué duración?
- **B5.** ¿Hay un layout específico (logo centrado, texto debajo, fondo, gradiente)?
- **B6.** ¿Hay elementos condicionales al estado (online/offline, dark/light mode)?

### Bloque C — Comportamiento (cuándo aparece y desaparece)

- **C1.** ¿Cómo se dispara la navegación DESDE el splash? (Navigator.pushReplacement, getIt, callback, stream).
- **C2.** ¿Hay un tiempo mínimo visible (ej. 1.5s)? ¿Cómo se implementa (Timer, Future.delayed, Stopwatch)?
- **C3.** ¿Hay un tiempo máximo visible (timeout)? ¿Cuál?
- **C4.** ¿El splash espera a que algo termine de cargar (auth, init, config)? ¿A qué?
- **C5.** ¿Tiene feature flag? (gating por tier, por usuario, por entorno).
- **C6.** ¿Cómo decide a dónde ir después? (¿login si no hay sesión? ¿home si la hay?).

### Bloque D — El bug del cortado (causa raíz)

- **D1.** ¿Hay alguna lógica que cancele la navegación prematuramente? (dispose, initState hot reload, stream cerrado antes de tiempo).
- **D2.** ¿El `Timer` o `Future.delayed` se limpia antes de completarse? (`.cancel()` llamado desde otro lugar).
- **D3.** ¿Hay un `AnimationController` que se interrumpe al cambiar de widget?
- **D4.** ¿Hay un `Navigator.pushReplacement` que se llama dos veces (doble push)?
- **D5.** ¿El bug se reproduce con `flutter run --debug`? ¿Solo en `--release`? ¿Solo en ciertos devices?
- **D6.** ¿Hay issues/tickets/reportes en el legacy sobre este bug? (git log, comentarios en el código, handoffs).

### Bloque E — Assets y dependencias externas

- **E1.** ¿Qué assets de imagen se usan? (paths en `assets/` del legacy).
- **E2.** ¿Qué fuentes personalizadas se cargan? (paths, declaración en `pubspec.yaml`).
- **E3.** ¿Hay algún paquete externo que el splash use? (lottie, rive, flutter_animate, etc.).

---

## Hipótesis inicial

> Esto se valida o refuta en los hallazgos. NO se afirma como verdad antes de explorar.

- **H1:** El splash legacy es una `StatelessWidget` o `StatefulWidget` simple en `lib/screens/splash/` o `lib/pages/splash.dart`.
- **H2:** Usa `Timer` o `Future.delayed` para controlar el tiempo visible.
- **H3:** La causa del bug del cortado es una de estas (orden de probabilidad):
  1. Un `initState` que llama `Navigator.pushReplacement` antes de que la animación de entrada termine.
  2. Un `Timer` que se sobreescribe o se cancela prematuramente.
  3. Un `AnimationController` con `vsync` que se interrumpe al cambiar de widget tree.
- **H4:** La identidad de marca está centralizada en assets (`assets/images/logo.png`, `assets/fonts/`) + un archivo de tema (`lib/theme/` o `lib/styles/`).
- **H5:** No hay feature flag — el splash aparece siempre.

---

## Plan de experimentación

Pasos concretos para responder las preguntas. Cada paso debe ser ejecutable.

1. **Localizar el repo legacy.** Hugo indica el path local donde está clonado `seiki_app`. Si no está clonado, el orquestador puede ayudar a clonarlo (read-only, no se commitea nada).
2. **Buscar el código del splash.** Comandos:
   - `grep -rn "Splash" --include="*.dart"` en el legacy.
   - `grep -rn "splash" --include="*.dart"` (case-insensitive).
   - Revisar `lib/main.dart` para ver cómo se inicia.
3. **Leer el/los archivo(s) del splash.** Identificar:
   - Estructura del widget.
   - Lógica de `initState` (qué hace al iniciar).
   - Lógica del timer / future / animation.
   - Lógica de navegación de salida.
4. **Identificar la causa del bug.** Releer el código buscando:
   - `dispose()` que cancela algo antes de tiempo.
   - `Timer` sin `cancel()`.
   - `AnimationController` con duración incorrecta.
   - `Navigator.pushReplacement` llamado en lugar equivocado.
   - Cualquier `await` que complete antes de lo previsto.
5. **Revisar assets y tema.** Buscar:
   - `assets/images/` para logos.
   - `pubspec.yaml` sección `flutter.assets` y `flutter.fonts`.
   - Archivos de tema (`theme.dart`, `colors.dart`, `styles.dart`).
6. **Revisar git log del legacy** en el splash:
   - `git log --all --oneline -- <path_al_splash>` — ver historia.
   - Buscar commits con "fix", "splash", "corta" — bugs previos.
7. **Revisar handoffs del legacy** si existen (workflow §Migración selectiva). Pueden documentar el bug ya analizado.

**Importante:** el legacy es read-only. NO se commitea nada ahí. NO se modifican archivos. Solo lectura.

---

## Hallazgos

> Resultado de la experimentación. Se llena al FINAL, no durante.

- **A1:** (path al archivo del splash).
- **A2:** (tipo de widget, ubicación).
- **A3:** (existencia de tests y qué cubren).
- **B1-B6:** (detalles de identidad de marca).
- **C1-C6:** (detalles de comportamiento).
- **D1-D6:** (causa raíz del bug del cortado).
- **E1-E3:** (assets y dependencias).
- **Hallazgo sorpresa:** (cualquier cosa descubierta que no preguntamos pero es relevante).

---

## Conclusiones y recomendaciones

- ¿La hipótesis inicial (H1-H5) era correcta? Sí/No/Parcial — explicar.
- **Qué se migra tal cual:** (lista concreta — assets, animaciones, copy).
- **Qué se descarta:** (lista concreta — el bug del cortado, lógica obsoleta, dependencias innecesarias).
- **Qué se mejora:** (lista concreta — usar go_router, BLoC, feature flags según Target).
- **¿Qué cambia en el spec de la HDU-002 gracias a esta exploración?** (input directo para el spec).
- **¿Hay riesgo nuevo descubierto?** (describir).
- **¿Se requiere otra HDU-EXPLORE antes de implementar?** (a veces una exploración abre más preguntas — por ejemplo, si la identidad de marca requiere decisiones de diseño adicionales).

---

## Evidencia

- Capturas, logs, screenshots, citas de código con `archivo:línea`.
- Cada pieza de evidencia con timestamp y condiciones (qué versión del legacy, qué commit).
- Si se clona el legacy: registrar el commit exacto del que se leyó.

---

## Referencias

- Repo legacy: `https://github.com/navaworkingspaces-collab/seiki_app` (read-only).
- `docs/adr/ADR-009-rewrite-with-knowledge-reuse.md` (procedimiento de reutilización de conocimiento del legacy).
- `docs/workflow.md` §Migración selectiva.
- `docs/architecture/target-architecture.md` §10 (feature flags, contexto para HDU-002).
- Cualquier handoff o spec cerrada del legacy que documente reglas de marca o decisiones de UX.
