# Runbook — Gestión de secretos de Zeiki

> **Procedimiento único para guardar, rotar y responder a incidentes con credenciales del proyecto.** Este documento es operativo (el "cómo"). Las reglas de qué NO hacer están en `docs/conventions.md §6`. Las reglas de qué SÍ documentar están en `docs/conventions.md §10`.

**Última actualización:** 2026-07-31 (agregada sección "Inyección de variables en build (CI)", housekeeping bundle #4 follow-up #4).

---

## 🎯 Propósito

Evitar fugas de credenciales y tener un procedimiento claro cuando ocurra una. La política de Zeiki es: **ningún secreto en código, en chat, en screenshots, ni en logs**. Si un secreto pasa por cualquiera de esos canales, se considera comprometido y se rota.

---

## 📍 Dónde se guardan los secretos

Cada capa de secretos tiene su lugar. NO se mezclan.

| Capa | Uso | Dónde vive | Quién tiene acceso |
|------|-----|-----------|-------------------|
| **Secretos del cliente (Flutter)** | Almacenamiento seguro de credenciales del USUARIO (eFirma, etc.) en el dispositivo. | `flutter_secure_storage` (Keychain iOS / EncryptedSharedPreferences Android). | El usuario de la app, solo en su dispositivo. |
| **Config de entorno del cliente** | `SUPABASE_URL` y `SUPABASE_ANON_KEY` (públicos, no son secretos). | `assets/.env` (en `.gitignore`) para dev. En CI: variables de build inyectadas con `--dart-define-from-file`. | El equipo de dev. |
| **Secretos del backend (Supabase)** | Credenciales de la BD, service_role key, secrets de edge functions. | Supabase Dashboard → Settings → API / Database. Rotación: cada 6 meses o ante sospecha de compromiso. | El owner del proyecto (Hugo). |
| **Secretos de CI/CD (Code Magic)** | Credenciales para buildear y desplegar. | Code Magic → Environment Variables. Rotación: cada 6 meses. | Hugo. |

### Inyección de variables en build (CI)

**Contexto (housekeeping bundle #4, follow-up #4):** las variables de entorno del cliente (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID`) tienen dos modos de inyección, según el ambiente:

| Ambiente | Cómo se inyectan | Comando |
|----------|------------------|---------|
| **Dev local** | Como asset `assets/.env` (cargado por `flutter_dotenv` en runtime). El archivo está en `.gitignore`. | `flutter run` (lee `assets/.env` automáticamente). |
| **CI / build de release** | Como `--dart-define` en el comando de build. **El archivo `.env` NO se incluye como asset en builds de release** porque podría quedar desempaquetado en el APK. | `flutter build apk --release --dart-define-from-file=ci.env` |

**Formato del archivo para CI:** el archivo `ci.env` (que vive solo en Code Magic, NUNCA en el repo) tiene **exactamente la misma forma** que `assets/.env.example`:

```bash
SUPABASE_URL=https://<project-id>.supabase.co
SUPABASE_ANON_KEY=<anon-key-publica>
GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
APP_ENV=staging
DEBUG_LOGS=false
```

**Cómo funciona `--dart-define-from-file`:** Flutter compila cada `String.fromEnvironment('SUPABASE_URL')` (o el equivalente con `dotenv`) con el valor del archivo pasado. El archivo se lee en build time, no se incluye en el binario. **El binario resultante contiene los valores literales en el código compilado** (como si fueran `const`), pero NO el archivo de origen. Esto es seguro para `SUPABASE_URL` y `SUPABASE_ANON_KEY` (son públicos) y para `GOOGLE_WEB_CLIENT_ID` (también público).

**Para qué sirve `--dart-define` (vs `--dart-define-from-file`):** el primero es para 1-2 variables (`flutter build apk --dart-define=KEY=value`). El segundo es para muchas. En CI siempre usamos el segundo.

**Antipatrón a evitar:** incluir `assets/.env` como `flutter.assets:` en `pubspec.yaml` Y en builds de release. Si el `.env` está como asset, queda desempaquetado en el APK y se puede leer con `unzip`. En cambio, con `--dart-define`, los valores quedan como literales compilados dentro del binario (más seguro aunque el trade-off es que cualquier variable que pusiste queda en el binario para siempre, hasta que recompiles).

**Reglas duras:**

- **NUNCA** un secreto se commitea al repo. `.gitignore` excluye `assets/.env`, `*.env.local`, `*.env.production`, `key.properties`, `*.keystore`, `*.jks`.
- **NUNCA** un secreto se pasa por chat (ni mensaje directo), por email, por screenshot, ni por voz. **Cualquier secreto que pase por chat se asume comprometido y se rota.**
- **NUNCA** se hace log de un secreto. `debugPrint`, `print`, `console.log` — NUNCA con passwords, tokens, RFCs completos, eFirma. Ni en dev. Ni en producción.
- **SIEMPRE** que un secreto se comparte con otra persona, el canal es: **password manager compartido** (1Password, Bitwarden) o **secret manager** (Supabase, AWS Secrets Manager, etc.). El chat NO es un secret manager.

---

## 🗂️ Inventario de secretos del proyecto

Esta lista es **referencial**. NO contiene los valores reales — solo qué secretos existen y dónde están.

### Cliente (Flutter)

| Secreto | ¿Es secreto? | Dónde se declara | Notas |
|---------|--------------|------------------|-------|
| `SUPABASE_URL` | ❌ No (público) | `assets/.env` | Va en el APK desempaquetado. Es público por diseño. |
| `SUPABASE_ANON_KEY` | ❌ No (público) | `assets/.env` | Idem. **Nunca** la `service_role_key` en el cliente. |
| `SUPABASE_DB_PASSWORD` | ✅ Secreto | NO en cliente. Solo en Supabase Dashboard. | El cliente nunca se conecta directo a Postgres, solo a la API REST. |
| `SUPABASE_SERVICE_ROLE_KEY` | ✅ Secreto (CRÍTICO) | NO en cliente. Solo en edge functions. | Si esto se filtra, se rota INMEDIATAMENTE — bypasea toda RLS. |
| `eFirma password` (del usuario) | ✅ Secreto (por usuario) | `flutter_secure_storage` en el dispositivo del usuario. | Nunca se envía a ningún servidor. |
| Credenciales de magic link | ❌ No (one-time) | Email del usuario. | El token expira en minutos. |

### Backend (Supabase)

| Secreto | Dónde vive | Quién lo rota |
|---------|-----------|--------------|
| `SUPABASE_DB_PASSWORD` | Supabase Dashboard → Database → Connection string. | Hugo. |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Dashboard → API → service_role. | Hugo. |
| Secrets de edge functions | `supabase secrets set KEY=value` por CLI. | Hugo. |
| `JWT_SECRET` (de GoTrue) | Supabase Dashboard → API → JWT Secret. | Hugo (solo si se cambia, invalida todas las sesiones). |

### CI/CD (Code Magic)

| Secreto | Notas |
|---------|-------|
| `GOOGLE_OAUTH_CLIENT_ID` | Público, va en `google-services.json` (que se commitea). |
| `GOOGLE_OAUTH_CLIENT_SECRET` | Secreto. **Nunca** va al APK — solo en Code Magic, solo lo usa el proxy server-side. |
| `FIREBASE_APP_DISTRIBUTION_TOKEN` | Secreto. Code Magic → Firebase. |
| `CODEMAGIC_FIREBASE_SERVICE_ACCOUNT` | Secreto. Code Magic → Firebase service account. |

---

## 🔄 Procedimiento de rotación

**Cuándo rotar un secreto:**

- **Cada 6 meses** (calendar reminder).
- **Inmediatamente** si se sospecha compromiso: pasó por chat, se commiteó por error, se vio en screenshot, se filtró en logs, se expuso en endpoint público.
- **Inmediatamente** si un dev con acceso se va del proyecto.
- **Cuando se cambia el stack o el proveedor** (ej. migrar de Supabase a otro).

**Cómo rotar `SUPABASE_DB_PASSWORD`:**

1. Supabase Dashboard → Project Settings → Database.
2. "Reset database password" → generar nueva.
3. Apuntarla en password manager (1Password/Bitwarden).
4. Actualizar conexiones activas (Code Magic, edge functions, dev local).
5. Verificar que la app sigue funcionando (test de health check en staging).
6. Documentar la rotación: `docs/handoffs/YYYY-MM-DD-secret-rotation.md` con qué se rotó, cuándo, por qué.

**Cómo rotar `SUPABASE_SERVICE_ROLE_KEY`:**

1. Supabase Dashboard → API → "Generate new service_role key" (esto invalida la anterior).
2. Actualizar la key en edge functions: `supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<nueva>`.
3. Re-deploy de las edge functions.
4. Verificar.
5. Documentar en handoffs.

**Cómo rotar credenciales de CI/CD (Code Magic):**

1. Code Magic → Application → Environment Variables.
2. Editar la variable, pegar el nuevo valor.
3. Trigger un rebuild de prueba.
4. Documentar.

---

## 🚨 Qué hacer si un secreto se filtra

**Si un secreto aparece en:**

- Chat (cualquier canal, incluido mensaje directo).
- Email.
- Screenshot o foto de pantalla.
- Log (debug o producción).
- Commit (aunque sea revertido después).
- Post público (redes, blog, foro).
- Endpoint accesible sin auth.
- Backup no cifrado.

**Acción inmediata (en orden):**

1. **Rotar el secreto AHORA.** No esperes al final del día, no "lo vemos mañana". Ahora.
2. **Revisar logs** para ver si alguien (humano o bot) accedió al secreto entre la fuga y la rotación.
3. **Revisar acceso**: si era `service_role_key`, ver si hubo queries sospechosas en la BD (logs de Supabase).
4. **Documentar el incidente**: `docs/postmortems/YYYY-MM-DD-secret-leak-<servicio>.md` con causa raíz, qué se rotó, qué se mitigó, qué se cambia para que no vuelva a pasar.
5. **Si es P1 o P2** (comprometió datos de usuarios), notificar a Hugo inmediatamente.

**Si el secreto es la `service_role_key`:** esto es P1. Se rota INMEDIATAMENTE y se hace auditoría de las queries en las últimas 24h.

**Si el secreto es un `JWT_SECRET`:** se rota + invalida TODAS las sesiones de usuarios (todos tienen que volver a loguearse). Esto es disruptivo pero necesario.

---

## 📚 Lo que NO se hace (anti-patrones)

- ❌ "Lo guardo en un `.env.example` con valores de ejemplo" — no, los valores van en el `.env` real (en `.gitignore`). El `.example` solo tiene la forma.
- ❌ "Lo paso por chat privado, no pasa nada" — sí pasa, los chats se respaldan, se sincronizan, se filtran. Asume compromiso.
- ❌ "Lo guardo en notas del celu" — mismo problema que arriba. Password manager.
- ❌ "Lo pongo en el código con un comentario que diga 'borrar antes de commitear'" — no. Ni un minuto. NUNCA.
- ❌ "Lo hardcodeo porque es dev, no importa" — importa. Las credenciales de dev son tan reales como las de prod y dan acceso al mismo backend.

---

## 📋 Checklist antes de hacer commit / push

Antes de cualquier `git commit` o `git push`, verificar:

- [ ] `git diff` revisado — no hay valores que parezcan keys, passwords, tokens.
- [ ] `git status` — no hay archivos `.env`, `key.properties`, `*.keystore`, `*.jks` listos para commitear.
- [ ] Si edité un `*.example`, confirmé que NO tiene valores reales.
- [ ] Si agregué un log nuevo, confirmé que NO loguea secretos.

**Si falla cualquier check:** para. Borra. Vuelve a verificar. Después commit.

---

## 🔗 Referencias

- `docs/conventions.md §6` — Seguridad (qué se hace, no cómo).
- `docs/conventions.md §10` — Configuración (capas de secretos).
- `docs/git.md §7` — Secret management end-to-end (proceso).
- `docs/architecture/target-architecture.md §12.1` — Rotación de secretos y RTO/RPO.
- `docs/architecture/target-architecture.md §13.1` — Decisión diferida sobre rotación automatizada.
- `docs/templates/handoff.md` — plantilla para documentar handoffs de rotación.
