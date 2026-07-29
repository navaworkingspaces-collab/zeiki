# Git, CI/CD y comandos — Zeiki

> **El "cómo" operacional:** comandos, branches, pipeline, PR. Las reglas de qué debe cumplir el código viven en `conventions.md`. El flujo de cuándo se hace cada cosa vive en `workflow.md`. Aquí solo se junta lo que cambia con el stack.
>
> **Última actualización:** 2026-07-29 (v1 — separación de conventions y workflow)

---

## 1. Branching

- `main` — siempre deployable, protegido.
- `feat/*`, `fix/*`, `refactor/*`, `chore/*` — trabajo en progreso.
- `hotfix/*` — solo para emergencias de producción.

| Tipo | Formato |
|------|---------|
| Bug fix | `fix/hdu-XXX-slug` |
| Feature | `feat/hdu-XXX-slug` |
| Refactor | `refactor/hdu-XXX-slug` |
| Chore | `chore/hdu-XXX-slug` |
| Hotfix | `hotfix/hdu-XXX-slug` |

**Comandos:**

```powershell
git checkout main
git pull origin main
git checkout -b fix/hdu-XXX-slug
```

**Regla:** nunca trabajar directo en `main`.

---

## 2. Commits

**Conventional Commits:**

```
<tipo>(<scope>): <descripción corta> [HDU-XXX]

<cuerpo opcional>

<footer>
```

**Tipos:** `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `style`, `perf`.

**Scope:** nombre de feature o área (`auth`, `invoices`, `sat`, `arch`, `deps`).

**Descripción corta:**

- Imperativo presente ("add" no "added").
- Sin punto final.
- < 72 caracteres.

**Cuerpo:** explicar **qué** y **porqué**, no **cómo**. Wrap a 72 chars.

**Footer:** `Refs: specs/HDU-XXX.md`, `BREAKING CHANGE: ...`, `Closes #123`.

**Ejemplo:**

```
fix(splash): persist onboarding completion flag [HDU-005]

SplashPage navigated to /onboarding on every launch with no session.
Now saves onboarding_completed after first view and skips if true.

- Add SharedPreferences key constant
- Set flag in OnboardingPage after user views all 4 slides
- Check flag in SplashPage before navigating
- Add unit tests for flag logic

Refs: specs/HDU-005-onboarding-flag.md
```

---

## 3. Merge

- **No fast-forward** para features (`--no-ff`) — preserva historia.
- Fast-forward OK para hotfixes.
- Eliminar rama después de merge.

```powershell
git checkout main
git pull origin main
git merge --no-ff <rama>
git push origin main
git branch -d <rama>
git push origin --delete <rama>
```

---

## 4. Pull Requests

**Título:** mismo formato que commits.

**Descripción (template):**

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

**Comando:**

```powershell
git push -u origin <rama>
gh pr create --base main --title "..." --body "..."
```

**Reviewers:**

- 1 mínimo (Hugo).
- Auto-merge OK para MVP, code review estricto para producción.

---

## 5. Pipeline local

> **Regla:** el pipeline local debe correr **TODOS** los tipos de tests del repo, no solo los de la HDU en turno. Esto evita que un test roto en otra pieza pase desapercibido.

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

---

## 6. CI/CD

### Build automático

- Code Magic buildea en cada push a `main`.
- Firebase App Distribution recibe el APK.
- Hugo recibe link por correo → instalar en móvil sin USB.

### Environments

- **dev:** rama `main` (auto-deploy, para testing).
- **staging:** rama `release/staging` (próximamente, para QA formal).
- **prod:** rama `release/prod` (próximamente, manual, para usuarios reales).

### Rollback

- Si un build falla en producción: `git revert` + push. Code Magic redespliega el anterior.
- Si un build funciona pero rompe algo: feature flag para apagar la feature sin redeploy.

---

## 7. Configuración de Git

### `.gitignore` estándar

```gitignore
# Build artifacts
.dart_tool/
build/
*.apk
*.aab

# Environment
assets/.env
*.env.local

# IDE
.idea/
.vscode/

# OS
.DS_Store
Thumbs.db

# Misc
*.log
coverage/
```

### Mensaje de commit firmado (opcional)

Si el repo lo requiere, configurar GPG:

```powershell
git config --global user.signingkey <KEY_ID>
git commit -S -m "..."
```

---

*Mantener este archivo actualizado. Si un comando cambia, este archivo cambia. Si la convención de qué se commitea cambia, ese cambio va en `conventions.md` o `workflow.md`, no aquí.*
