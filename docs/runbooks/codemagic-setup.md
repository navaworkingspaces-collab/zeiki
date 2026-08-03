# Runbook — Setup de Code Magic para Zeiki (follow-up #18)

> **Procedimiento único para activar el CI/CD de Zeiki.** Este runbook es el "cómo" (operativo). La decisión de usar Code Magic está en `docs/adr/ADR-006-codemagic-firebase.md`. La configuración vive en `codemagic.yaml` (raíz del repo).

**Última actualización:** 2026-08-03 (setup inicial, housekeeping follow-up #18).

---

## 🎯 Qué hace este CI

**Por ahora (este runbook):** corre `flutter analyze` + `flutter test` en cada push a `main` y en cada PR. **NO** hace build de APK, **NO** deploya a Firebase, **NO** corre integration tests. Es el mínimo viable de verificación automatizada.

**Para qué sirve:** en cada PR, antes de mergear, Code Magic corre los tests y te dice si pasaste o rompiste algo. Tú (o quien revise) no tiene que correr los tests localmente.

**Lo que falta para el #18 completo** (sale en HDU futura):
- Build de APK debug/release.
- Deploy a Firebase App Distribution (para Hugo instalar sin USB).
- Integration tests con `adb` (back nativo, rotación, deep links).
- Cobertura de tests (coverage report).
- Notificaciones (Slack, email) en caso de fallo.

---

## 🛠️ Setup paso a paso

### Pre-requisitos

- Cuenta en [codemagic.io](https://codemagic.io) (plan gratis, login con GitHub).
- Repo `navaworkingspaces-collab/zeiki` con acceso de admin.
- El archivo `codemagic.yaml` ya está commiteado a `main` (PR #16, este runbook).

### Paso 1 — Crear la app en Code Magic

1. Entra a [codemagic.io](https://codemagic.io).
2. Click **"Add application"**.
3. Selecciona el repo `navaworkingspaces-collab/zeiki`.
4. Tipo de proyecto: **Flutter App**.
5. Click **"Finish"**. Code Magic detecta automáticamente el `codemagic.yaml` de la raíz.

### Paso 2 — Activar el workflow `test`

1. En el dashboard de la app, ve a **"Workflows"**.
2. Deberías ver `test` (definido en `codemagic.yaml`).
3. Click en él → **"Start new build"**.
4. Selecciona rama: **`main`**.
5. Click **"Start build"**.

### Paso 3 — Verificar que el build pasa

El build tarda 5-8 minutos la primera vez (instala Flutter, baja deps, corre tests).

**Si pasa:** ✅ todo bien. El setup está completo. Cada push a `main` y cada PR van a correr automáticamente.

**Si falla:**
- Mira los logs en Code Magic.
- Si es error de `flutter pub get`: revisa que el `assets/.env` (gitignored) no se haya colado en el lockfile. NO debe.
- Si es error de `flutter analyze`: corrige los warnings.
- Si es error de tests: corre `flutter test` localmente, arregla, push.

### Paso 4 — Probar con un PR de prueba

1. Crea una rama `test/ci-setup` con cualquier cambio trivial (ej. un comment en `codemagic.yaml`).
2. Push + abrir PR.
3. Code Magic debe correr el workflow automáticamente.
4. Verifica que aparece el check ✅ en el PR.

### Paso 5 — Configurar el badge (opcional)

Code Magic provee un badge para el README. URL del badge:

```markdown
![Code Magic](https://api.codemagic.io/svg/v1/build/<api-token>/<workflow-id>)
```

Reemplaza `<api-token>` y `<workflow-id>` con los valores del dashboard. Pega en el `README.md` raíz.

---

## 🔐 Secrets (para扩展 futuros)

Este workflow **NO** usa secrets. Cuando se agregue el workflow de deploy a Firebase, se necesitarán:

| Secreto | Dónde se obtiene | Cómo se inyecta en Code Magic |
|---------|------------------|-------------------------------|
| `GOOGLE_OAUTH_CLIENT_SECRET` | Google Cloud Console → Credentials | App → Environment variables |
| `FIREBASE_APP_DISTRIBUTION_TOKEN` | Firebase Console → Project Settings → Service Accounts | Idem |
| `CODEMAGIC_FIREBASE_SERVICE_ACCOUNT` (JSON) | Firebase Console → Service Accounts → Generate new private key | Idem (pegar el JSON completo) |
| Android keystore (`*.keystore` o `*.jks`) | Hugo lo genera con `keytool` (o se reutiliza el de debug) | App → Code signing → Upload file |

**Importante:** los secrets NUNCA van en `codemagic.yaml`. Solo en el dashboard de Code Magic, en "Environment variables" o "Code signing" (runbook `docs/runbooks/secrets.md`).

---

## 🚨 Troubleshooting

### Build falla con "Flutter not found"

- El environment está mal configurado. En el YAML debe decir `flutter: stable`. Verifica.
- Si persiste, fijar versión exacta: `flutter: 3.38.3` (la que usa el proyecto).

### Build falla con "Permission denied" en `git clone`

- El repo es privado y Code Magic no tiene acceso. Verifica que授权 en GitHub.
- Solución: Code Magic → App → Settings → "Source" → re-autorizar el repo.

### Tests pasan local pero fallan en Code Magic

- Probable: los tests dependen de un archivo o config que está en `.gitignore` (ej. `assets/.env`).
- Solución: usar fakes en los tests o mover la config a una variable de entorno inyectada por Code Magic.

### Build tarda más de 15 min (timeout)

- El `max_build_duration: 15` es muy bajo para tu proyecto. Subir a `30` o `45`.
- Si los tests son lentos, revisar `pubspec.yaml` y ver si hay deps que se pueden cachear.

### Code Magic no detecta `codemagic.yaml`

- Verifica que el archivo está en la **raíz** del repo, no en una subcarpeta.
- Verifica que el YAML no tiene errores de sintaxis (Code Magic lo loguea).
- Si usas GitHub, verifica que la integración está授权ada.

---

## 📚 Referencias

- `docs/adr/ADR-006-codemagic-firebase.md` — decisión de usar Code Magic.
- `docs/runbooks/secrets.md` — gestión de secrets (general, no específico de Code Magic).
- `codemagic.yaml` — el archivo de config (raíz del repo).
- https://docs.codemagic.io/yaml-quick-start/ — docs oficiales de Code Magic YAML.
- https://docs.codemagic.io/flutter-configuration/flutter-projects/ — config específica para Flutter.
