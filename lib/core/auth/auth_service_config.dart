// Configuración transversal de los servicios de auth de Zeiki (HDU-005b).
//
// Centraliza valores que se referencian desde varios lugares
// (inactivity monitor, tests). Vive en `core/` porque auth es
// cross-cutting (Target §6).
//
// **Por qué `class` y no un `const` global suelto:** para que tests
// puedan inyectar configs custom (ej. `inactivityTimeout` corto para
// probar el timer sin esperar 5 minutos) sin tocar archivos globales.
// La convención es `const AuthServiceConfig() = defaults` en runtime.
class AuthServiceConfig {
  const AuthServiceConfig({
    this.inactivityTimeout = const Duration(minutes: 5),
  });

  /// Tiempo sin interacción del usuario antes del auto-logout.
  /// Default 5 min — matchea comportamiento de bancos y apps de
  /// facturación (Target §10). Si en uso real 5 min es muy agresivo,
  /// se sube a 15 (spec HDU-005b §Fuera de scope: "Ajustar el timer
  /// de inactividad desde la UI" queda para HDU futura de settings).
  final Duration inactivityTimeout;
}
