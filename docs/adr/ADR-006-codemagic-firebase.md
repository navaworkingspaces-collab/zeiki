# ADR-006: Code Magic + Firebase App Distribution para CI/CD

**Estado:** Aceptado
**Fecha:** 2026-07-29

## Contexto

Hoy, cada cambio en Zeiki requiere que Hugo conecte su móvil Xiaomi por USB y corra `flutter run` localmente. Eso es fricción innecesaria, consume tiempo de QA, y rompe la cadencia de iteración. El equipo es de 1 persona, no se justifica un setup de CI/CD empresarial, pero tampoco se puede seguir con deploys manuales.

## Decisión

**Code Magic** (CI/CD móvil) + **Firebase App Distribution** (distribución a testers):

- Code Magic buildea automáticamente en cada push a `main`.
- El APK generado se sube a Firebase App Distribution.
- Hugo recibe un link en su correo, abre en el móvil, instala. Sin USB, sin comandos locales.

**Para producción** (cuando llegue): se evaluará Google Play Console (Android) o App Store Connect (iOS si se decide soportar).

## Por qué

- **Code Magic:** integración nativa con Flutter, UI visual para configurar pipelines, plan gratis suficiente para 1 dev. No requiere aprender YAML de GitHub Actions desde el día 1.
- **Firebase App Distribution:** free, soporta testers individuales o por grupo, instalación con un tap. Es el camino más corto entre "código en main" y "APK en el móvil".
- **Migración futura posible:** si Code Magic se queda corto, migrar a GitHub Actions + Fastlane es viable (los principios de pipeline siguen aplicando).

## Alternativas consideradas

- **GitHub Actions + Fastlane:** más control, más YAML, más mantenimiento inicial. Mejor para equipos grandes.
- **Bitrise:** alternativa a Code Magic, similar en capacidad. Code Magic tiene mejor DX para Flutter.
- **Manual (USB + `flutter run`):** lo que hacemos hoy. Fricción innecesaria.
- **Play Console internal testing:** requiere release signing, más overhead. Firebase App Distribution es más liviano.

## Trade-offs

- **A favor:** deploy sin USB, automático, gratis para empezar.
- **En contra:** dependencia de dos servicios externos. La filosofía del proyecto es "reproducible desde cero", así que el setup de Code Magic debe estar documentado y versionado (no "la config está en mi cuenta").

## Cuándo se revisa

- Code Magic cambia precios o se discontinúa.
- Se necesita soporte de iOS con release real.
- El equipo crece y necesita control más fino de pipelines por rama.
- Se llega al punto de releases públicos (Google Play / App Store).

## Configuración reproducible

- El setup de Code Magic vive en `codemagic.yaml` en la raíz del repo, no en la UI del servicio.
- Los secrets (Supabase keys, Google OAuth client secrets, etc.) se inyectan desde variables de entorno de Code Magic, no en el YAML.
- El keystore de Android se sube como archivo binario a Code Magic, **nunca** se commitea al repo.
