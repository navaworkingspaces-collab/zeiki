# Git, CI/CD y comandos — Zeiki

> **El "cómo" operacional:** comandos, branches, pipeline, PR. Las reglas de qué debe cumplir el código viven en `conventions.md`. El flujo de cuándo se hace cada cosa vive en `workflow.md`. Aquí solo se junta lo que cambia con el stack.
>
> **Última actualización:** 2026-07-29 (v2 — principios, conflictos, versionado, flaky tests, reproducibilidad, rollback)

---

## 🧭 Principios de Git

> **Por qué existen las reglas de esta sección.** Si entiendes el porqué, las reglas se vuelven obvias.

- **Git registra historia, no respaldos.** La historia debe poder leerse meses después y entenderse.
- **Un commit representa un cambio lógico.** Si un commit mezcla refactor + feature + fix, hay que dividirlo.
- **El historial debe poder leerse.** Commits con mensajes vagos (`fix stuff`, `wip`) son deuda.
- **Si un cambio no puede describirse en una oración, probablemente son dos commits.**
- **La rama `main` siempre es deployable.** Lo que llega a main se asume listo para producción.
- **El rollback debe ser más rápido que el fix.** Si revertir un cambio toma más que arreglarlo, hay un problema de proceso.
- **Todo build debe ser reproducible desde cero.** No se depende de archivos locales, SDKs instalados a mano, ni configuraciones personales. Si un dev nuevo no puede buildear, el build está roto.

---

## 1. Branching

### Cuándo crear una rama

Crear rama nueva cuando:

- ✅ Empieza una HDU.
- ✅ Empieza un bug independiente (no atado a la HDU en curso).
- ✅ Se hará un experimento que puede no llegar a producción.
- ✅ Se trabajará más de unos minutos (incluso un cambio pequeño, si toca más de un archivo).

**Evitar:**

- ❌ Mezclar dos HDUs en la misma rama (rompe la trazabilidad).
- ❌ Trabajar directo en `main`.
- ❌ Ramas "wip" o "prueba" que sobreviven más de un día sin nombre claro.

### Convención de nombres

| Tipo | Formato |
|------|---------|
| Bug fix | `fix/hdu-XXX-slug` |
| Feature | `feat/hdu-XXX-slug` |
| Refactor | `refactor/hdu-XXX-slug` |
| Chore | `chore/hdu-XXX-slug` |
| Hotfix | `hotfix/hdu-XXX-slug` |

### Branching vs Trunk-based

> **Decisión:** Zeiki usa **branching por feature**, NO trunk-based con feature flags puros. Aquí el porqué.

**Por qué branching:**

- Equipo de 1 persona, pero el modelo escala a 3-5 devs sin cambio de workflow.
- Aislamiento de cambios: una HDU no afecta a otra hasta que se mergea.
- Code review más limpio: se revisa un cambio cohesivo, no un stream de commits.
- Compatible con el workflow de 12 pasos (cada paso encaja con una rama).

**Por qué NO trunk-based (aún):**

- Trunk-based asume deploys muy frecuentes con feature flags maduros. Zeiki tiene feature flags pero la cadencia de release no es diaria.
- Sin tests de integración rápidos, trunk-based rompe cosas en main. La matriz de criticidad cubre, pero el test infra no está listo.
- Para 1 dev con cadencia de cambio baja, branching es más simple y suficiente.

**Cuándo se reconsidera:**

- El equipo crece a 3+ devs haciendo PRs concurrentes al mismo feature.
- La cadencia de release sube a diaria (necesita trunk + flags maduros).
- Aparece dolor real con conflictos de merge frecuentes.

### Comandos

```powershell
git checkout main
git pull origin main
git checkout -b fix/hdu-XXX-slug
```

---

## 2. Commits

### Formato (Conventional Commits)

```
<tipo>(<scope>): <descripción corta> [HDU-XXX]

<intención y motivo>

<footer>
```

**Tipos:** `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `style`, `perf`.

**Scope:** nombre de feature o área (`auth`, `invoices`, `sat`, `arch`, `deps`).

### Descripción corta

- Imperativo presente ("add" no "added").
- Sin punto final.
- < 72 caracteres.

### Cuerpo: intención y motivo

> **Explicar la intención del cambio y el motivo, no el "qué"** (ese ya está en el diff). El "cómo" se queda en el código; el cuerpo del commit explica **por qué** se hizo.

❌ **Mal** (repite el diff):

```
qué: Add cache.
```

✅ **Bien** (explica intención y motivo):

```
motivo: Avoid calling SAT twice because downloads are
rate limited and we hit the 429 too often.
```

### Footer

- `Refs: specs/HDU-XXX.md`
- `BREAKING CHANGE: <descripción>`
- `Closes #123`

### Ejemplo

```
fix(splash): persist onboarding completion flag [HDU-005]

SplashPage navigated to /onboarding on every launch with no
session. Goal: respect the user's first-time choice across
restarts.

- Add SharedPreferences key constant
- Set flag in OnboardingPage after user views all 4 slides
- Check flag in SplashPage before navigating
- Add unit tests for flag logic

Refs: specs/HDU-005-onboarding-flag.md
```

---

## 3. Merge

### Pre-condiciones (antes de hacer merge)

Antes de hacer `git merge` a `main`:

- [ ] La rama está actualizada con `main` (rebase o merge de main, sin conflictos pendientes).
- [ ] El pipeline pasó en la rama (no "en mi compu sí pasa").
- [ ] El review terminó (3 gates: clean code, security, architecture).
- [ ] El spec está actualizado con la checklist firmada.

Si alguna pre-condición falla, NO se mergea. Se resuelve primero.

### Comandos

- **No fast-forward** para features (`--no-ff`) — preserva historia.
- Fast-forward OK para hotfixes.

```powershell
git checkout main
git pull origin main
git merge --no-ff <rama>
git push origin main
git branch -d <rama>
git push origin --delete <rama>
```

---

## 4. Conflictos de merge

> **Regla:** los conflictos se resuelven entendiendo ambos lados, no aceptando "current" o "incoming" a ciegas.

### Procedimiento

1. **Entender ambos cambios.** Abrir los dos lados, leer el contexto, preguntar si no se entiende.
2. **Nunca aceptar "Current" o "Incoming" sin revisar.** Cada lado tiene una intención que el otro no conoce.
3. **Resolver preservando la intención de ambos.** Si los dos lados cambiaron lo mismo, fusionar las dos intenciones. Si contradicen, hablar con el autor.
4. **Ejecutar el pipeline después del merge.** Un conflicto resuelto puede romper tests que antes pasaban.
5. **Si el conflicto es grande, pedir revisión extra.** No se mergea solo porque "se ve bien".

### Anti-patrones

- ❌ Aceptar todos los cambios "Incoming" para "ganar tiempo".
- ❌ Aceptar todos los "Current" porque "mío funciona".
- ❌ Resolver con un editor que no muestra ambos lados.
- ❌ Mergear sin correr tests después.

---

## 5. Pull Requests

### Título

Mismo formato que commits: `<tipo>(<scope>): <descripción> [HDU-XXX]`.

### Descripción (template)

```markdown
## Resumen
<1-3 bullets>

## Check de entendimiento
- Lo que quieres: …
- Vas a saber que está bien cuando: …
- Esto NO se va a hacer: …

## Spec
Ver: [specs/HDU-XXX-slug.md](specs/HDU-XXX-slug.md)

## Cambios
- Bullet list

## Riesgos
¿Qué podría romper este cambio?
- <Riesgo 1> — mitigación: <cómo>
- <Riesgo 2> — mitigación: <cómo>

## Checklist de review
- [ ] Tests rojos → verdes documentado
- [ ] Clean code review pasó
- [ ] Security review pasó
- [ ] Architecture review pasó (cumple Target Architecture)
- [ ] `flutter analyze` sin warnings nuevos
- [ ] `flutter test` pasa
- [ ] `flutter build apk --debug` compila
- [ ] Deno tests pasan (si toca edge functions)
- [ ] QA local verificó criterios de aceptación

## Screenshots / Logs
<si aplica>
```

### Reviewers

- 1 mínimo (Hugo).
- Auto-merge OK para MVP, code review estricto para producción.

### Comando

```powershell
git push -u origin <rama>
gh pr create --base main --title "..." --body "..."
```

---

## 6. Pipeline local

> **Regla:** el pipeline local debe correr **TODOS** los tipos de tests del repo, no solo los de la HDU en turno.

### Flutter (cliente)

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

### Deno (edge functions) — TODAS

```powershell
foreach ($fn in Get-ChildItem "supabase/functions") {
  Push-Location $fn
  deno check index.ts
  deno test --allow-read --allow-env
  Pop-Location
}
```

**Flags obligatorios (HDU-037):**

- `--allow-read` → para tests que leen `index.ts` como texto.
- `--allow-env` → para tests que mockean variables de entorno.

Ambos flags son seguros globalmente: los tests que no los necesitan los ignoran.

### Si hay migraciones SQL nuevas

- Aplicar a staging o DB local.
- Verificar idempotencia (`IF NOT EXISTS` en CREATE).

**Criterio de pipeline:** TODO pasa 0 errores. Si falla algo, NO se commitea.

### Tests flaky

> **Si un test falla de forma intermitente (flaky), se corrige o se deshabilita temporalmente con issue asociado. Nunca se ignora.**

- **Flaky crónico:** el test se corrige. Investigar race condition, timing, dependencia de orden.
- **Flaky conocido (mitigación temporal):** se marca con `@skip` o `xfail` y se crea un issue con fecha para corregirlo.
- **Flaky ignorado:** está prohibido. Si "a veces falla" sin acción, es deuda que se va a acumular.

**Detección:** si un test falla en CI pero pasa en local, o si pasa solo el 80% de las veces, es flaky.

---

## 7. CI/CD

### Filosofía

> **Todo build debe ser reproducible desde cero.** No depender de archivos locales, SDKs instalados manualmente, ni configuraciones personales.

Si un dev nuevo no puede clonar el repo y buildear con un solo comando, el build está roto. Documentar setup en `docs/setup.md` y automatizarlo en CI.

### Build automático

- Code Magic buildea en cada push a `main`.
- Firebase App Distribution recibe el APK.
- Hugo recibe link por correo → instalar en móvil sin USB.

### Environments

- **dev:** rama `main` (auto-deploy, para testing).
- **staging:** rama `release/staging` (próximamente, para QA formal).
- **prod:** rama `release/prod` (próximamente, manual, para usuarios reales).

### Secrets

- En Code Magic / GitHub Secrets, nunca en código.
- Rotación documentada en `docs/runbooks/rotate-secrets.md` (pendiente).
- Cada secreto tiene un dueño y fecha de expiración.

### Secret management end-to-end (proceso)

El flujo completo de un secreto (Supabase anon key, Google OAuth client secret, etc.) sigue estos pasos:

1. **Desarrollo local:** secreto va en `assets/.env` (en `.gitignore`).
2. **CI build:** Code Magic lee el secreto desde su panel de Secrets, lo inyecta como variable de entorno al build.
3. **APK firmado:** el secreto se "hornea" en el APK. **CUIDADO:** el `google-services.json` con OAuth client_id es público una vez desempaquetado, así que el **client_secret NUNCA va al APK** — solo el `client_id` público.
4. **Cliente (móvil):** los secretos del usuario (eFirma password, etc.) se guardan en `flutter_secure_storage` (Keychain iOS / EncryptedSharedPreferences Android).
5. **Servidor (Edge Functions):** los secretos se leen con `Deno.env.get()`, nunca en código. Code Magic los pasa al deploy.
6. **Rotación:** cada 6 meses o ante sospecha de compromiso. Procedimiento en `docs/runbooks/rotate-secrets.md` (pendiente).

**Caso especial: Google OAuth client_secret.** El `client_secret` se valida en el **servidor** (Edge Function proxy), no en el cliente. El cliente solo conoce el `client_id` público. Por eso existe `auth-google-proxy` (ver ADR-007 — el proxy de Google OAuth que bypassea el bug de GoTrue).

**Status:** TBD. `docs/runbooks/rotate-secrets.md` aún no está escrito. Se documenta en Fase 2.

### Deploy de Edge Functions

Las Edge Functions se deployan con **Supabase CLI** (no con Code Magic, que solo buildea la app):

- **Manual local:** `supabase functions deploy <nombre>` desde la línea de comandos.
- **Automático en CI:** Code Magic corre `supabase functions deploy` después del build de la app si hay cambios en `supabase/functions/`.
- **Secrets de la función:** se configuran con `supabase secrets set KEY=value` (queda en Supabase, no en el repo).

**Status:** TBD. El `codemagic.yaml` aún no incluye el paso de deploy de functions.

---

## 8. Rollback

> **El rollback debe ser más rápido que el fix.** Si revertir un cambio toma más que arreglarlo, hay un problema de proceso.

### Procedimiento estándar

```powershell
git checkout main
git pull origin main
git revert <commit-o-pr>
git push origin main
```

Code Magic redespliega el anterior automáticamente.

### Cuando un feature flag es mejor que un revert

- **Revert:** cuando el cambio rompió algo que antes funcionaba.
- **Feature flag off:** cuando la feature nueva causa problemas pero el resto del cambio es válido.
- **Revert + fix forward:** cuando el cambio es estructural y necesita una nueva HDU para arreglarse bien.

### Post-mortem

- Para cualquier rollback que afecta usuarios, post-mortem en `docs/postmortems/YYYY-MM-DD-<slug>.md`.
- Causa raíz, no solo el síntoma.

---

## 9. Versionado

> **Seguimos Semantic Versioning** (`MAJOR.MINOR.PATCH`).

| Cambio | Tipo | Ejemplo |
|--------|------|---------|
| Incompatible con versión anterior | `MAJOR` | 1.x.x → 2.0.0 |
| Nueva feature compatible | `MINOR` | 1.3.x → 1.4.0 |
| Bug fix compatible | `PATCH` | 1.3.2 → 1.3.3 |

### Tags

```powershell
git tag -a v1.4.0 -m "Release 1.4.0: feature X"
git push origin v1.4.0
```

### Pre-release

- `-alpha.N`, `-beta.N`, `-rc.N` para versiones que no van a producción.
- Ejemplo: `v2.0.0-beta.3`.

### Hoy vs mañana

- Hoy el proyecto no tiene releases (es dev activo). Las reglas de versionado se aplican **cuando empiecen los releases**.
- Si nunca se llega a esa fase, la sección queda como referencia para cuando toque.

### Versionado cruzado (app + Edge Functions + BD)

Cuando se llegue a releases, un "release" de Zeiki coordina **tres componentes**:

- **App (Flutter):** tag `v1.4.0` en git.
- **Edge Functions (Deno):** tag en el mismo commit, identificable por convención (`edge-functions: v1.4.0` en metadata).
- **Migraciones SQL:** referenciadas en el tag con su timestamp (ej. "incluye migración `20260801_120000_add-x.sql`").

**Convención propuesta** (a aplicar cuando haya releases):

- Tag de git incluye los tres: `[app v1.4.0] [edge v1.4.0] [migrations: 20260801]`.
- Si uno no cambia, se omite (ej. solo app: `[app v1.4.0]`).
- La spec de la HDU que se releasea debe declarar los tres componentes.

**Status:** TBD. Se define formalmente cuando se hagan los primeros 5 releases.

---

## 10. Configuración de Git

### `.gitignore` estándar

```gitignore
# Build artifacts
.dart_tool/
build/
*.apk
*.aab
*.ipa
*.dSYM.zip
*.dSYM

# Coverage
coverage/
coverage_html/
*.lcov

# Android signing (CRÍTICO)
*.keystore
*.jks
key.properties

# Environment
assets/.env
*.env.local
*.env.production

# IDE
.idea/
.vscode/
*.iml
*.swp

# OS
.DS_Store
Thumbs.db
desktop.ini

# Misc
*.log
*.pid
*.seed
*.pid.lock
```

> ⚠️ **Regla absoluta:** los archivos de firma de Android (`*.keystore`, `*.jks`, `key.properties`) **nunca** se commitean. Si se commitean por error, se rotan de inmediato (la firma está comprometida).

### Mensaje de commit firmado (opcional)

Si el repo lo requiere, configurar GPG:

```powershell
git config --global user.signingkey <KEY_ID>
git commit -S -m "..."
```

---

*Mantener este archivo actualizado. Si un comando cambia, este archivo cambia. Si la convención de qué se commitea cambia, ese cambio va en `conventions.md` o `workflow.md`, no aquí.*
