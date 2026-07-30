# HDU-004 — Navegación con go_router

**Tipo:** feature
**Prioridad:** alta
**Estado:** pendiente
**Fecha:** 2026-07-30
**Sistemas externos involucrados:** ninguno
**Dominio(s):** transversal (afecta el arranque de la app y la navegación entre pantallas)

---

## Check de entendimiento (3 líneas)

- Lo que quieres: que la app pueda brincar entre pantallas con un mapa de rutas (go_router).
- Vas a saber que está bien cuando: haya 4 placeholders (splash, onboarding, login, home) que muestren su nombre, pueda navegar entre ellos con botones y con deep links, y la app no se rompa al rotar ni al dar atrás.
- Esto NO se va a hacer: el contenido real de cada pantalla ni la decisión de a dónde ir según flags o auth (eso es HDU-005 y HDU-006).

---

## Problema / Motivación

HDU-001 dejó la app con un `MaterialApp` que solo muestra un placeholder estático. HDU-002 y HDU-003 agregaron inicialización de Supabase y el sistema de feature flags, pero **la navegación no existe**: no hay forma de saltar entre pantallas, no hay deep links, no hay back stack real.

Esta HDU es la base que necesitan HDU-005 (auth: necesita redirigir a `/login` si no hay sesión) y HDU-006 (splash nuevo: necesita redirigir según el feature flag y el estado de auth). Sin un router, esas HDUs no pueden decidir "a dónde voy después".

Analogía: es como construir los pasillos del centro comercial con letreros que dicen "aquí va la zapatería, aquí la cafetería". Las tiendas reales (HDU-005, 006) llegan después — solo cambian el contenido de cada local, no el mapa de pasillos.

---

## Criterios de aceptación

- [ ] **AC1:** `lib/core/router/app_router.dart` declara un `GoRouter` con 4 rutas: `/splash`, `/onboarding`, `/login`, `/home`. La ruta inicial es `/splash`.
- [ ] **AC2:** Las 4 pantallas existen como placeholders en `lib/core/router/screens/` (carpeta nueva, temporal — se migra a `lib/features/<dominio>/` cuando cada pantalla tenga contenido real en HDUs futuras). Cada placeholder muestra su nombre en grande en el centro.
- [ ] **AC3:** Cada placeholder tiene al menos 2 botones para brincar a otras rutas (ej. "Ir a login" + "Ir a home"). Tocar un botón navega a esa ruta sin crashear.
- [ ] **AC4:** `lib/main.dart` reemplaza el `MaterialApp` actual por uno con `routerConfig: appRouter`. El placeholder estático `_PlaceholderPage` se elimina.
- [ ] **AC5:** Deep links funcionan: abrir `zeiki://login` desde fuera (ej. `adb shell am start -W -a android.intent.action.VIEW -d "zeiki://login"`) abre la pantalla de login en la app.
- [ ] **AC6:** El botón de "atrás" del Android pop el route stack normalmente. Si estoy en `/login` y vine de `/splash`, atrás me lleva a `/splash`. Si estoy en `/splash` (ruta inicial), atrás cierra la app (no se rompe).
- [ ] **AC7:** Al rotar el celular, la pantalla actual se preserva (no me regresa a `/splash` ni se pierde el estado). `go_router` tiene state restoration built-in en 14.x; verificar que esté habilitado.
- [ ] **AC8:** `test/core/router/app_router_test.dart` cubre con unit tests: cada ruta resuelve a su placeholder correcto, ruta inicial es `/splash`, deep link `zeiki://login` resuelve a `/login`.
- [ ] **AC9:** `integration_test/router_test.dart` cubre con integration tests en Xiaomi: tap un botón navega, deep link abre la ruta correcta, back button pop correctamente, rotación preserva el estado.
- [ ] **AC10:** `AndroidManifest.xml` declara el intent filter para `zeiki://` (scheme + host opcional). Sin esto, los deep links no funcionan aunque go_router esté bien configurado.
- [ ] **AC11:** `flutter analyze` 0 warnings, `flutter test` pasa, `flutter test integration_test/` (en Xiaomi) pasa, `flutter build apk --debug` compila. Pipeline local completo.
- [ ] **AC12:** El `Future.delayed(1s)` de HDU-001 en `main.dart` se elimina (era residuo del placeholder). Sin él, la app no espera 1 segundo artificial antes de mostrar la primera pantalla.

---

## Archivos afectados

**Nuevos:**

- `lib/core/router/app_router.dart` — `GoRouter` config con las 4 rutas.
- `lib/core/router/screens/splash_placeholder.dart` — placeholder de splash (texto "Splash" + 2 botones).
- `lib/core/router/screens/onboarding_placeholder.dart` — placeholder de onboarding.
- `lib/core/router/screens/login_placeholder.dart` — placeholder de login.
- `lib/core/router/screens/home_placeholder.dart` — placeholder de home.
- `test/core/router/app_router_test.dart` — unit tests de resolución de rutas y deep links.
- `integration_test/router_test.dart` — integration tests de navegación end-to-end.

**Modificados:**

- `lib/main.dart` — usar `MaterialApp.router(routerConfig: appRouter)`, eliminar `_PlaceholderPage` y el `Future.delayed(1s)`.
- `android/app/src/main/AndroidManifest.xml` — agregar intent filter para `zeiki://<ruta>`.
- `pubspec.yaml` — verificar que `go_router: ^14.2.7` y `app_links: ^7.0.0` estén declarados (probablemente ya están; si no, agregarlos). `app_links` es la pieza que conecta deep links al router en go_router 14.x.
- `docs/current-state.md` — actualizar cuando se mergee (cleanup).
- `.mavis/hdu.md` (local, en `.gitignore`) — registrar la HDU-004 cerrada.

**Eliminados:**

- `lib/main.dart::_PlaceholderPage` (clase privada, ya no se usa).
- El `Future.delayed(const Duration(seconds: 1))` de `main()` (residuo HDU-001).

---

## Plan técnico (pasos verificables)

1. **Crear `lib/core/router/screens/<4 placeholders>.dart`** — cada uno un `StatelessWidget` con un `Scaffold` que muestra el nombre en grande y 2 botones (`ElevatedButton`) que llaman a `context.go('/ruta')`. Sin estado, sin lógica.
2. **Crear `lib/core/router/app_router.dart`** — declarar `final appRouter = GoRouter(initialLocation: '/splash', routes: [...])` con las 4 rutas. Exportar también `AppRoute` enum (opcional, para que el código use `AppRoute.login.path` en vez de strings sueltos — conventions §1).
3. **Modificar `lib/main.dart`** — cambiar `MaterialApp` por `MaterialApp.router(routerConfig: appRouter)`, eliminar `_PlaceholderPage` y el `Future.delayed(1s)`. Importar el router.
4. **Modificar `android/app/src/main/AndroidManifest.xml`** — agregar dentro de `<activity ...>`:
   ```xml
   <intent-filter android:autoVerify="false">
     <action android:name="android.intent.action.VIEW" />
     <category android:name="android.intent.category.DEFAULT" />
     <category android:name="android.intent.category.BROWSABLE" />
     <data android:scheme="zeiki" />
   </intent-filter>
   ```
5. **Verificar `pubspec.yaml`** — `go_router: ^14.2.7` y `app_links: ^7.0.0` declarados. Si falta `app_links`, agregarlo.
6. **Tests:**
   - `test/core/router/app_router_test.dart` — unit tests con `appRouter.configuration.findMatch(route: '/login')` para verificar resolución, y un test de deep link `zeiki://login → /login`.
   - `integration_test/router_test.dart` — integration test que arranca la app, tap "Ir a login", verifica que la pantalla cambió, prueba deep link con `adb shell am start -W ...`.
7. **Pipeline local:** `flutter analyze`, `flutter test`, `flutter test integration_test/`, `flutter build apk --debug`. Todo verde.

---

## Notas / Decisiones explícitas

- **Placeholders viven en `lib/core/router/screens/` temporalmente.** Cuando HDU-005 implemente el login real, se mueve `login_screen.dart` a `lib/features/identidad/screens/` y se actualiza el import en `app_router.dart`. Mismo patrón para splash (HDU-006 → `lib/features/identidad/screens/` o donde quede), home (todavía sin dominio claro). Esta carpeta NO se queda permanente: es andamiaje de esta HDU.
- **No uso `ShellRoute` ni rutas anidadas todavía.** Con 4 pantallas planas no aporta. Si en HDU futura aparece un bottom nav bar, se refactoriza a `StatefulShellRoute` (es la decisión correcta en su momento, no ahora — workflow §"Quema la deuda cuando la veas" + conventions §"No anticipes").
- **No uso `redirect` ni guards en el router todavía.** La decisión "¿a dónde voy según flags o auth?" es de HDU-005/006. Esta HDU solo deja el mapa de rutas. Agregar `redirect` aquí sería scope creep.
- **`app_links` es la pieza de deep links.** go_router 14.x lo necesita para que los intent filters del Android se traduzcan en rutas del router. Si no está declarado, se agrega.
- **State restoration (rotación)** viene built-in en go_router 14.x vía `restorationScopeId`. Verificar que esté habilitado; si no, agregarlo (es 1 línea).
- **El `Future.delayed(1s)` de HDU-001 muere aquí.** Era para confirmar el ciclo de vida, ya cumplió su propósito.
- **El test de deep link en integration_test** asume Xiaomi con `adb` accesible. Si no, se documenta como test manual en `docs/runbooks/` o se mueve a widget test con `TestWidgetsFlutterBinding`.

---

## Fuera de scope

- El contenido real de cada pantalla (formularios de login, gráficos del home, etc.).
- La decisión de a dónde ir según el `TierService` (eso es HDU-006).
- La decisión de a dónde ir según el estado de auth (eso es HDU-005).
- Transiciones animadas custom entre rutas (go_router trae las default de Material; si se quieren custom, sale en HDU aparte).
- `ShellRoute` / bottom nav bar / drawer (no hay contenido todavía que justifique la complejidad).
- Tests de performance / carga de rutas (no aplica al scope de esta HDU).
- Migrar los placeholders a `lib/features/` (eso pasa naturalmente cuando cada feature llegue a su HDU).

---

## Riesgos

- **`app_links` requiere configuración adicional en iOS** (no aplica a Android-only MVP, pero hay que recordar cuando se agregue iOS).
- **Deep links con `zeiki://` no son App Links verificados** (no hay `assetlinks.json` ni HTTPS). Esto significa que el SO muestra un "abrir con" picker si hay otra app que declare el mismo scheme. Para MVP está bien; cuando se quiera abrir directo sin picker, se migra a `https://zeiki.app/...` con App Links. Fuera de scope de esta HDU.
- **State restoration depende de que cada `Widget` sea restaurable.** Los placeholders son StatelessWidget simples, no debería haber problema. Si aparece un widget con estado en HDU futura, hay que verificar que sobrevive la rotación.

---

## Sistemas externos involucrados

- Ninguno. go_router es local al cliente. Los deep links usan el sistema operativo Android (intent filters) pero no un servicio externo.
