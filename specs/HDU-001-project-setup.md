# HDU-001 — Base del proyecto Flutter (setup inicial)

**Tipo:** chore
**Prioridad:** alta
**Estado:** pendiente
**Fecha:** 2026-07-29
**Sistemas externos involucrados:** Ninguno
**Dominio(s):** Ninguno (transversal — sienta las bases para todos)

---

## Check de entendimiento (3 líneas)

- Lo que quieres: tener el proyecto Flutter corriendo, aunque la pantalla solo muestre "hola".
- Vas a saber que está bien cuando: pueda correr `flutter run` y ver la app en el celu.
- Esto NO se va a hacer: nada de login, navegación, splash ni features de producto, solo la base del proyecto.

---

## Problema / Motivación

Zeiki está en Fase 1 (MVP) y el repositorio solo contiene documentación. No existe el proyecto Flutter, no hay estructura de directorios, no hay dependencias declaradas, no hay forma de correr `flutter build` y obtener un APK. Sin esta base, ninguna HDU de feature puede arrancar.

Esta HDU es la primera de la reescritura. Su único objetivo es dejar el proyecto en pie: que compile, que pase el linter con cero warnings, y que la estructura de carpetas refleje la Target Architecture (§6) y las convenciones de ADR-001/002/003/004/005/008.

---

## Criterios de aceptación

- [ ] AC1: `flutter build apk --debug` compila sin errores ni warnings nuevos.
- [ ] AC2: `flutter analyze` pasa con 0 warnings.
- [ ] AC3: `flutter test` corre (aunque no haya tests propios del setup, el harness funciona).
- [ ] AC4: La estructura de directorios existe y refleja la arquitectura:
  - `lib/main.dart` (entry point).
  - `lib/core/` (auth, di, logging, constants, services) — carpetas creadas aunque vacías, con README breve cada una.
  - `lib/features/<dominio>/` para los 6 dominios (identidad, fiscal, clientes, reportes, asistencia, configuracion) — carpetas creadas aunque vacías.
  - `assets/.env.example` con la forma del `.env` real (sin valores sensibles).
- [ ] AC5: La app arranca y muestra un placeholder visible ("Zeiki — base del proyecto" o similar) por al menos 1 segundo, para confirmar que el ciclo de vida de Flutter funciona.
- [ ] AC6: `pubspec.yaml` declara las dependencias base de los ADRs (con versiones conservadoras):
  - `flutter_bloc` (ADR-004)
  - `get_it` (ADR-005)
  - `supabase_flutter` (ADR-003)
  - `equatable`
  - `flutter_secure_storage`
  - `flutter_dotenv`
  - `go_router` (no tiene ADR propio, se justifica en notas)
- [ ] AC7: `.gitignore` cubre al menos lo listado en `docs/git.md §10` (build artifacts, signing, env, IDE, OS).
- [ ] AC8: `analysis_options.yaml` configurado con reglas estrictas (las que vienen por defecto en `flutter_lints` + extras que se decidan en review).
- [ ] AC9: Existe un README breve en la raíz que explique cómo correr el proyecto (un solo comando).

---

## Archivos afectados

**Nuevos:**
- `pubspec.yaml`
- `analysis_options.yaml`
- `.gitignore`
- `lib/main.dart`
- `lib/core/<servicios>/` (carpetas con README breve)
- `lib/features/<dominio>/` (carpetas con README breve)
- `assets/.env.example`
- `test/widget_test.dart` (smoke test mínimo que verifica que la app arranca)
- `README.md` (raíz del repo)

**Modificados:** ninguno (el repo solo tiene docs).

**Eliminados:** ninguno.

---

## Plan técnico (pasos verificables)

1. **Crear proyecto Flutter base.** Comando: `flutter create . --org com.zeiki --project-name zeiki --platforms=android`. Verificar que genera `lib/main.dart` y compila con `flutter build apk --debug` antes de tocar nada más.
2. **Sobreescribir `.gitignore`** con el contenido de `docs/git.md §10` (más completo que el default de `flutter create`).
3. **Configurar `analysis_options.yaml`** incluyendo `package:flutter_lints/flutter.yaml` y, si se decide en review, reglas adicionales de `very_good_analysis` o `effective_dart`.
4. **Editar `pubspec.yaml`** para declarar las dependencias listadas en AC6 con versiones conservadoras (rangos caret clásicos, no latest).
5. **Crear estructura de directorios**:
   - `lib/core/{auth,di,logging,constants,services}/` con `README.md` breve en cada una explicando su responsabilidad.
   - `lib/features/{identidad,fiscal,clientes,reportes,asistencia,configuracion}/` con `README.md` breve en cada una apuntando al dominio en Target §6.
6. **Editar `lib/main.dart`** para que solo muestre el placeholder ("Zeiki — base del proyecto") y haga un `await Future.delayed` de 1 segundo antes de quedar idle. Sin splash real todavía (esa será una HDU aparte).
7. **Configurar `assets/.env.example`** con la forma de las variables de entorno que se usarán cuando se conecte Supabase (sin valores reales).
8. **Crear smoke test** en `test/widget_test.dart` que verifique que la app arranca y muestra el texto "Zeiki — base del proyecto".
9. **Crear `README.md` raíz** con: qué es Zeiki (1 línea), cómo correr (`flutter pub get && flutter run`), a dónde ir para saber más (link a `docs/architecture/target-architecture.md`).
10. **Verificar pipeline local** completo: `flutter analyze && flutter test && flutter build apk --debug`. Todo en 0.

---

## Tests a escribir (basado en matriz de criticidad)

| Componente | Criticidad | Tipo de test mínimo | Notas |
|------------|------------|---------------------|-------|
| App arranca y muestra placeholder | Baja | Widget test smoke | Confirma que el harness de Flutter funciona. No es flujo crítico aún. |
| `flutter analyze` | Alta | Linter | Política "0 warnings". |
| `flutter build apk --debug` | Alta | Build | Confirma que el toolchain está bien configurado. |

Referencia: §11 de Target Architecture (matriz de criticidad).

> **No se escriben tests unitarios de dominio** porque en esta HDU no hay dominio todavía. Se agregan en las HDUs de feature.

---

## Fuera de scope

- Login, autenticación, splash, onboarding, navegación entre pantallas.
- Configuración real de Supabase (credenciales, RLS, edge functions).
- Configuración de Code Magic / Firebase App Distribution / CI.
- Cualquier feature del MVP listada en Target §15.
- Tests de integración (llegan en Fase 3 según Target).
- iOS, web, desktop (Target es Android-first en MVP).

---

## Riesgos

- **Versiones de dependencias incompatibles entre sí.** Mitigación: usar versiones conservadoras y verificar que `flutter pub get` resuelve sin conflictos. Si hay conflicto, se documenta en este spec y se resuelve en review.
- **`go_router` no tiene ADR propio.** Mitigación: justificar en la sección de Notas por qué se incluye (es la pieza estándar de navegación en Flutter, ningún ADR la prohíbe y la necesitaremos desde la próxima HDU). Si Hugo prefiere otra cosa, se cambia.
- **Riesgo de scope creep.** Es fácil empezar a meter navegación, splash, o un login placeholder. Mitigación: la regla es que esta HDU termina cuando se cumple AC5, no antes. Lo demás es HDU nueva.
- **El placeholder de 1 segundo puede confundir.** Mitigación: documentar en el código con un comentario "este delay es solo para confirmar el ciclo de vida, no es splash real".

---

## Review checklist

- [ ] Cumple con §1-§3 de Target Architecture (principios, atributos, restricciones).
- [ ] No introduce anti-patrones (§14 de Target).
- [ ] Clean code (conventions §2: nombres, funciones chicas, comentarios del porqué).
- [ ] Security (conventions §6: secrets en `.env`, no en código; `.env` en `.gitignore`).
- [ ] Tests pasan (smoke test + pipeline local completo).
- [ ] `flutter analyze` 0 warnings.
- [ ] `flutter build apk --debug` compila.
- [ ] QA local: Hugo abre la app en un emulador/dispositivo y ve el placeholder.

---

## Notas

- **Sobre `go_router`:** la navegación en Flutter tiene 2 opciones serias — `go_router` (oficial de Flutter team) y Navigator 2.0 puro. `go_router` se mantiene activamente, tiene declarative routing, deep linking gratis, y es lo que usa la mayoría de proyectos serios. No requiere ADR formal porque no rompe ninguna restricción de §3 ni de §1. Si en alguna HDU posterior se decide otra cosa, se cambia con costo bajo.
- **Sobre las versiones:** se prefieren versiones probadas (no la última). Criterio: la última versión que haya sido estable por al menos 1 mes en pub.dev.
- **Sobre el dominio de nomenclatura de carpetas:** `features/identidad/` (español) vs `features/identity/` (inglés). El Target §6 los lista en español, por lo que se usa español. ADR-008 (estructura de dominios) lo confirma.
- **Sobre los READMEs en carpetas vacías:** son intencionales. Sirven como "este es el lugar donde vivirá X" y evitan que en la siguiente HDU haya que decidir dónde va cada cosa. Convención documentada en `conventions.md §7`.
- **Sobre el `assets/.env.example`:** no es configuración real. Es la forma que tendrá el `.env` cuando se conecte Supabase. No tiene valores, solo nombres de variables. El `.env` real va en `.gitignore` desde el día 1.
