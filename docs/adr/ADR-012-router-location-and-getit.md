# ADR-012: Router en `lib/core/router/` con imports a `lib/features/` + GoRouter en GetIt

**Estado:** Aceptado
**Fecha:** 2026-07-31
**Reemplaza a:** ninguno (decisión A del review de HDU-004 + excepción documentada aquí por primera vez)
**Relacionado con:** [ADR-005](ADR-005-getit.md) (GetIt para DI), [ADR-010 (deprecated)](deprecated/ADR-010-tier-service.md) y [ADR-011](ADR-011-tier-service-getit-registration.md) (precedente de documentar excepciones arquitectónicas)

## Contexto

Durante el code review de HDU-005 (commit `b88968a` del review de HDU-004, propuesta de Hugo), el `zeiki-reviewer` detectó que `lib/core/router/app_router.dart` importa directamente las pantallas reales desde `lib/features/identidad/screens/`:

```dart
// lib/core/router/app_router.dart (líneas 25-27)
import '../../features/identidad/screens/home_screen.dart';
import '../../features/identidad/screens/login_screen.dart';
import '../../features/identidad/screens/register_screen.dart';
```

Esto viola la regla arquitectónica del proyecto (Target §6 y Target §5): **"core NO importa de features"**. En HDU-004 esto no era un problema porque el router importaba sus propios placeholders de `lib/core/router/screens/` (mismo directorio). En HDU-005, al migrar las pantallas a `lib/features/identidad/`, se introdujo la violación.

Adicionalmente, durante la misma HDU-004 el `zeiki-reviewer` ya había marcado como **bloqueante de decisión** la **Decisión A**: mover el `appRouter` a GetIt como singleton lazy para que el `redirect` del router pueda consultar `AuthService` limpiamente. Esa decisión se ejecutó en HDU-005 pero **no se formalizó en un ADR**. La estructura de `app_router.dart` ahora es:

```dart
GoRouter buildAppRouter({required AuthServiceGetter authServiceGetter}) { ... }
```

Y el `appRouter` ya no es una variable global mutable: se registra en `lib/core/di/service_locator.dart` como singleton lazy.

Hugo eligió la opción C del review (formalizar la excepción con un ADR) en vez de mover el router o invertir la dependencia, por las siguientes razones:
- Mover el router a `lib/app/router/` o `lib/presentation/` (opción A) es un refactor más grande que se justifica mejor en Fase 2 cuando haya más features, no en HDU-005 que ya es la HDU más grande del proyecto.
- Invertir la dependencia con factories en GetIt (opción B) añade complejidad (factory patterns) que no compensa para el MVP de 4 rutas.
- Crear el ADR (opción C) es 5 minutos, merge rápido, y queda documentado para futuros devs.

## Decisión

Se formalizan **dos decisiones** en un solo ADR (porque son del mismo dominio y se refuerzan mutuamente):

### 1. `appRouter` se registra en GetIt como singleton lazy

**`lib/core/di/service_locator.dart`:**
```dart
if (!getIt.isRegistered<GoRouter>()) {
  getIt.registerLazySingleton<GoRouter>(
    () => buildAppRouter(authServiceGetter: () => getIt<AuthService>()),
  );
}
```

**`lib/main.dart`** consume el router desde GetIt:
```dart
runApp(ZeikiApp(router: getIt<GoRouter>()));
```

El `ZeikiApp` ya no es `const`; recibe `router` como parámetro obligatorio. Los features también lo consumen vía `getIt<GoRouter>()` cuando lo necesitan.

### 2. Excepción documentada: `lib/core/router/app_router.dart` importa de `lib/features/`

**`lib/core/router/app_router.dart` importa las pantallas reales** desde `lib/features/identidad/screens/`:

```dart
// Excepción documentada en ADR-012. Aplica solo al router (composición
// de UI). Ver §"Por qué" para la racionalización completa.
import '../../features/identidad/screens/home_screen.dart';
import '../../features/identidad/screens/login_screen.dart';
import '../../features/identidad/screens/register_screen.dart';
```

**Ningún otro archivo en `lib/core/` puede importar de `lib/features/`.** Esta excepción es exclusiva del router.

## Por qué

### Por qué `appRouter` en GetIt (Decisión 1)

- **Consistencia con el resto de servicios transversales:** `AuthService`, `TierService`, `GoogleSignInHandler` ya están en GetIt. Excluir al router del mismo patrón generaba fricción (los tests tenían que importarlo desde un archivo concreto en vez de usar `getIt`).
- **Testabilidad mejorada:** los tests reemplazan singletons en GetIt con fakes. Si el router no estuviera en GetIt, los tests no podrían simular "router con AuthService fake" limpiamente. La firma `buildAppRouter({required AuthServiceGetter})` permite pasar un getter que consulta GetIt en runtime, no una instancia capturada.
- **Reactividad sin trucos:** cuando llegue HDU-005b (biometría con `authStateChanges`), conectar el stream al `GoRouter.refreshListenable` es trivial si el router vive en GetIt. Sin GetIt, requiere un global estático o un event bus.
- **Orden de inicialización explícito:** el `service_locator` centraliza el orden (`AuthService` se registra antes que `GoRouter`, que depende de él). El `main.dart` solo llama `setupServiceLocator()` y consume desde ahí.

### Por qué la excepción `core → features` solo en el router (Decisión 2)

- **El router ES composición de UI, no un servicio transversal.** A pesar de vivir en `lib/core/`, su trabajo es conectar URLs con pantallas. Eso requiere conocer las pantallas concretas.
- **Invertir la dependencia (factories en GetIt) añade complejidad innecesaria para 4 rutas:** el `router` tendría que resolver `getIt<HomeScreenFactory>()` y `getIt<LoginScreenFactory>()` en cada navegación, donde cada factory construye un widget con sus props. Es más código, más indirección, y mismo resultado.
- **Mover el router a `lib/app/router/` o `lib/presentation/`** es la opción más limpia arquitectónicamente, pero el costo del refactor (mover 4 archivos + actualizar imports en tests) no compensa hoy. Sale en Fase 2 cuando haya más de 8-10 features y el refactor toque más archivos.
- **El router es el ÚNICO archivo en `core/` que conoce features.** Verificado: `lib/core/auth/`, `lib/core/tiers/`, `lib/core/supabase/`, `lib/core/constants/`, `lib/core/di/`, `lib/core/logging/`, `lib/core/services/` NO importan de `lib/features/`. Solo el router. La violación está **acotada a un archivo**.

## Alternativas consideradas

### Para Decisión 1 (router a GetIt)

- **Singleton global mutable (lo que estaba en HDU-004).** Funciona para 4 rutas, pero rompe la consistencia y bloquea el patrón de "tests con fakes en GetIt".
- **Provider / Riverpod solo para el router.** Acopla la decisión a un paquete de state management. GetIt ya está en uso (ADR-005), sería una dependencia extra innecesaria.
- **Factory en cada `MaterialApp.router`.** Crea un router nuevo cada vez. Imposible compartir estado entre navegaciones. Descartado.

### Para Decisión 2 (excepción `core → features`)

- **Mover el router a `lib/app/router/` o `lib/presentation/`.** Opción arquitectónicamente más limpia. Diferida a Fase 2 (cuando haya 8-10+ features y el refactor toque más archivos, justificando el costo).
- **Invertir la dependencia con factories en GetIt** (`getIt<HomeScreenFactory>()`). Pragmáticamente funciona, pero añade boilerplate (factory classes) sin ganancia clara para 4 rutas. Diferida a Fase 2 si el número de pantallas crece.
- **Crear una capa intermedia `lib/app/` o `lib/presentation/` que contenga router + pantallas de identidad.** Conceptualmente más limpio que la opción 1, pero mueve la decisión de "qué es transversal" a una nueva discusión arquitectónica. Hoy no compensa.

## Trade-offs

- **A favor:**
  - Consistencia: router sigue el mismo patrón que `AuthService`, `TierService`, `GoogleSignInHandler`.
  - Testabilidad: tests pueden reemplazar el router con fakes limpios.
  - Documentación explícita: la excepción `core → features` está por escrito, no es un slip.
  - Cero código nuevo: solo se documenta una decisión que ya se ejecutó.
- **En contra:**
  - Una excepción a Target §6 sigue siendo una excepción. Si en el futuro un dev junior lee el código sin leer este ADR, puede pensar "esto está mal, lo arreglo" y romper algo.
  - El router en `core/` es semánticamente confuso: parece un servicio transversal, pero es composición de UI. La **carpeta** miente sobre el contenido. La solución limpia (mover a `lib/app/`) está diferida.

## Cuándo se revisa

- El equipo decide mover a Fase 2 (cuando haya 8-10+ features).
- Aparece un segundo caso de un archivo en `core/` que necesita importar de `features/` (señal de que la excepción debe ampliarse o eliminarse).
- El número de rutas crece más allá de 15-20 y el router se vuelve difícil de mantener (considerar GoRouter's `StatefulShellRoute` o dividir en múltiples routers por dominio).
- Se quiere usar `go_router.refreshListenable` con un stream reactivo (HDU-005b / HDU-006) y la firma actual del getter se queda corta.

## Cuándo NO se revisa

- Pequeños cambios en la firma de `buildAppRouter` (ej. agregar un nuevo parámetro con default). No requiere re-ADR.
- Cambios en las pantallas reales (migración de placeholders a reales, en futuras HDUs). La excepción cubre **cualquier** pantalla real que el router importe, no solo las actuales.

## Sincronización con código

- **Verificación:** `grep -r "import.*features" lib/core/` debe devolver SOLO los imports del router (`app_router.dart`). El conteo exacto puede variar según las pantallas reales que se hayan migrado — la regla es que **todos** los imports `lib/core/ → lib/features/` deben vivir en `app_router.dart`, no en otros archivos de `lib/core/`. Si aparecen en otros archivos, se rompió la excepción. (A 2026-07-31, HDU-006: 6 imports — `splash_cubit.dart`, `home_screen.dart`, `login_screen.dart`, `register_screen.dart`, `splash_screen.dart`, `unlock_screen.dart` — todos en `app_router.dart`.)
- **Lint custom (futuro):** se podría agregar una regla de `flutter_lints` o un script CI que verifique que `lib/core/` solo importa de `lib/core/` y de paquetes externos, excluyendo el router. Sale en HDU futura de CI/CD.

## Documentos relacionados

- `lib/core/router/app_router.dart` — el archivo con la excepción.
- `lib/core/di/service_locator.dart` — registro del router en GetIt.
- `lib/main.dart` — consumo del router desde GetIt.
- [HDU-004 spec](../specs/HDU-004-go-router.md) §"Decisión A" — la decisión original.
- [HDU-005 spec](../specs/HDU-005-auth-basico.md) §"Decisión arquitectónica" — la formalización en el spec.
- [ADR-005](ADR-005-getit.md) — GetIt para DI (precedente del patrón).
- [ADR-010 (deprecated)](deprecated/ADR-010-tier-service.md) + [ADR-011](ADR-011-tier-service-getit-registration.md) — precedente de formalizar excepciones arquitectónicas con un ADR de supersede.
- [Target §5](../architecture/target-architecture.md#5) (capas) y [Target §6](../architecture/target-architecture.md#6) (dominios) — las reglas que este ADR explícitamente exceptúa para el router.
