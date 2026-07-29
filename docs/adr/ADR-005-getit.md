# ADR-005: GetIt para dependency injection

**Estado:** Aceptado
**Fecha:** 2026-07-29

## Contexto

Zeiki tiene servicios que se usan en múltiples features (auth, datasources de Supabase, integraciones con SAT, calculadores fiscales). Esos servicios deben ser instanciados una vez y compartirse. Los repositorios se construyen con sus dependencias (datasources, otros repositorios) sin que el código de UI sepa cómo.

## Decisión

**`get_it`** (registrado como `sl` en `core/di/injection_container.dart`) para dependency injection.

- **Singleton** (`registerLazySingleton`) para servicios, repositorios, use cases.
- **Factory** (`registerFactory`) para BLoCs (nueva instancia por uso).
- **Orden:** Supabase se inicializa primero, después se registran los singletons, después los factories.
- **Una sola entry point** (`init()`) que registra todo. `main.dart` llama `init()` después de Supabase.

## Por qué

- **Service locator simple:** sin `BuildContext` ni `InheritedWidget` en el código de UI.
- **Testeable:** los `sl<T>()` se pueden sobrescribir en tests con `sl.reset()`.
- **Estándar en Flutter:** muchos paquetes de la comunidad lo usan.
- **Sin anotaciones ni code generation:** explícito en `init()`, fácil de leer.

## Alternativas consideradas

- **Inyección por constructor puro:** más "puro" pero requiere pasar dependencias por todos los `BuildContext`, complica el árbol de widgets.
- **Provider / Riverpod como DI:** funciona, pero acopla DI con state management.
- **`injectable` (code generation):** declarativo, pero genera código que debe regenerarse. Más fricción que beneficio.
- **Manual (sin DI):** cada feature construye sus dependencias. Repetición, difícil de cambiar implementaciones en tests.

## Trade-offs

- **A favor:** simple, testeable, sin code generation.
- **En contra:** service locator es un patrón "menos puro" que DI por constructor. El riesgo de "DI oculta" se mitiga con disciplina (registros explícitos en `init()`).

## Excepciones documentadas

- **`TierService`** NO se registra en `sl` porque es state global cross-cutting (mismo patrón que `AuthStateChangeNotifier`). Sigue el principio de "state global va aparte, dependencia inyectable va en GetIt".
- **`AuthBloc` y otros BLoCs de lifecycle de app** se registran como factory para que cada `BlocProvider` cree su propia instancia.

## Cuándo se revisa

- La base de código crece tanto que el archivo `injection_container.dart` se vuelve inmanejable (> 500 líneas). Ahí se divide por dominio.
- Se necesita DI scoped (vive solo durante una pantalla). GetIt no lo soporta bien; se migra a `provider` o se encapsula manualmente.
