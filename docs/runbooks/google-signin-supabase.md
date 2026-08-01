# Runbook — Configurar Google Sign-In en Supabase + Google Cloud Console

> **Cuándo se necesita:** antes de mergear la HDU-005, el botón
> "Continuar con Google" debe funcionar en runtime. Sin esta
> configuración, el popup del SO abre pero el `signInWithIdToken`
> falla con error 400/401.
>
> **Quién lo hace:** Hugo (configuración externa al repo).
> Implementer documenta y referencia.
>
> **Status:** Pendiente de configurar para mergear HDU-005.

## Resumen de lo que se hace

Google Sign-In en Supabase requiere **tres configs externas**:

1. **Google Cloud Console** — crear OAuth client (Android).
2. **Firebase** — registrar el SHA-1 del cert de debug.
3. **Supabase dashboard** — activar Google como provider y pegar
   las credenciales.

Sin las tres, el flujo no funciona.

---

## Paso 1 — Google Cloud Console

### 1.1 Crear OAuth Client (Android)

1. Ir a https://console.cloud.google.com/
2. Proyecto: `zeiki` (o crear uno si no existe).
3. Menú → **APIs & Services** → **Credentials**.
4. **Create Credentials** → **OAuth client ID**.
5. Application type: **Android**.
6. Package name: `app.zeiki.mobile` (verificar en
   `android/app/build.gradle` → `applicationId`).
7. SHA-1 certificate fingerprint: ver Paso 2.
8. **Create**. Aparece el Client ID (anotar — se usa en Paso 3).

### 1.2 Crear OAuth Client (Web) — opcional pero recomendado

Para que el flow funcione también desde web (futuro), crear otro
OAuth client de tipo **Web application**. Esto da un `client_id` y
`client_secret` que se pegan en Supabase.

---

## Paso 2 — SHA-1 del certificado de debug

### Android Studio (más fácil)

1. Abrir el panel **Gradle** (View → Tool Windows → Gradle).
2. Navegar a `app > Tasks > android > signingReport`.
3. Doble click. Aparece el SHA-1 en la consola.
4. Copiar el **SHA-1** (no el SHA-256).

### Línea de comandos (PowerShell)

```powershell
cd "C:\Users\Pc\Documents\Seiki\zeiki\android"
.\gradlew signingReport
```

Buscar la línea:
```
Variant: debug
Config: debug
Store: C:\Users\Pc\.android\debug.keystore
Alias: androiddebugkey
MD5: ...
SHA1: AA:BB:CC:DD:EE:FF:...   ← ESTE
SHA-256: ...
```

**Para release (futuro):** cuando se configure CI/CD, también se
necesita el SHA-1 del cert de release. Por ahora solo el de debug.

---

## Paso 3 — Supabase Dashboard

1. Ir a https://supabase.com/dashboard/project/iocbqjzmoneulydmeavr
2. Menú → **Authentication** → **Providers**.
3. Buscar **Google** en la lista y hacer click.
4. Toggle **Enable Sign in with Google** a ON.
5. Pegar:
   - **Client ID (for OAuth flow):** el del Paso 1.1 (Android).
   - **Client Secret:** el del OAuth client **Web** del Paso 1.2
     (sí, Supabase pide el secret del Web client aunque la app
     sea Android — el `signInWithIdToken` valida en el servidor).
6. **Authorized Client IDs:** el Client ID del Paso 1.1 (Android).
7. **Save**.

### Verificar

```powershell
curl -X POST "https://iocbqjzmoneulydmeavr.supabase.co/auth/v1/token?grant_type=id_token" `
  -H "Content-Type: application/json" `
  -d '{"provider":"google","id_token":"<token-de-prueba>"}'
```

Si devuelve `{"access_token": "...", "user": {...}}` → config OK.
Si devuelve 400 → revisar el Client ID / Secret.

---

## Paso 4 — Verificar en la app

```powershell
flutter run
```

En el Xiaomi:
1. Tocar "Continuar con Google" en register o login.
2. Debe aparecer el popup del SO con la cuenta Google.
3. Confirmar → debe navegar a /home.

Si el popup no aparece o falla:
- Revisar que el SHA-1 en Google Cloud Console coincida con el
  del cert de debug (Paso 2).
- Revisar que el `applicationId` en `android/app/build.gradle`
  coincida con el del OAuth client.
- Revisar que el package name en Firebase/AndroidManifest coincida.

---

## Troubleshooting

| Síntoma | Causa probable | Fix |
|---------|----------------|-----|
| Popup no aparece | Falta SHA-1 en Google Cloud Console | Paso 2 |
| Popup aparece, falla al confirmar | Client ID mal pegado en Supabase | Paso 3, verificar Client ID |
| `ApiException: 10` | `google-services.json` falta o está mal | (HDU futura: agregar Firebase) |
| `PlatformException(sign_in_failed)` | SHA-1 no coincide | Regenerar SHA-1 con `signingReport` |
| Pantalla blanca tras popup | Supabase devuelve 400 — secret inválido | Paso 3, verificar Client Secret |
| **Chooser NO aparece** en signIns subsecuentes (después del primero) | **Comportamiento normal** de `google_sign_in` + Google Play Services. Después del primer signIn exitoso, Play Services "recuerda" la cuenta para este app y la usa directo, sin chooser. UX optimizado, NO es bug. | Solo necesitas el chooser para QA/debug si quieres cambiar de cuenta. Opciones: (a) agregar `await googleSignIn.signOut()` antes del `signIn()` (debug only, NO commitear); (b) `adb shell pm clear com.google.android.gms` (limpia cache de Play Services, fuerte); (c) desinstalar + reinstalar la app. El `AuthService.signOut()` actual solo desloguea de Supabase, no de Google — son sistemas independientes. |

---

## Documentos relacionados

- [HDU-005 spec](../../specs/HDU-005-auth-basico.md) — flujo de auth
  completo (incluye la decisión de scope simplificado: ambos métodos
  en login, no auto-detección).
- [ADR-009](../adr/ADR-009-rewrite-with-knowledge-reuse.md) — la
  reescritura desde cero.
- [secrets.md](./secrets.md) — gestión de secretos (rotación, .env).

---

## Cuando se agregue CI/CD (Fase 2)

El cert de release tendrá su propio SHA-1. Se agrega:
- Al OAuth client de Google Cloud Console (otro `package name` o
  se permite múltiples SHA-1 en el mismo client).
- En Supabase (no requiere cambio — el provider es único).

Por ahora (MVP) solo se necesita el SHA-1 de debug.
