# Runbook — Activar/desactivar el feature flag `AppFeature.splash`

> **Procedimiento único para activar o desactivar el splash de Zeiki desde el dashboard de Supabase.** Este runbook es la acción de Hugo que NO puede hacer el implementer. La app se conecta al flag en cold start vía la edge function `feature-flags` (HDU-002) y el `TierService` (HDU-003).

**Última actualización:** 2026-07-31 (creado en HDU-006).

---

## 🎯 Propósito

El splash de Zeiki (`AppFeature.splash`) es el primer feature detrás de flag del producto. Por defecto está **OFF** en el seed inicial (HDU-002). Este runbook documenta cómo activarlo para que los usuarios vean el splash, y cómo desactivarlo si se decide quitar.

**Cuándo se activa:** cuando se quiere hacer rollout gradual del splash (ej. 10% de usuarios primero, luego 100%). O cuando se quiere validar el branding en producción antes de quitar el flag.

**Cuándo se desactiva:** si el splash causa problemas en producción (ej. ANR en Android de gama baja) y se decide quitar temporalmente.

---

## 📍 Dónde vive el flag

| Capa | Dónde | Quién lo edita |
|------|-------|----------------|
| **Cliente (Flutter)** | `lib/core/tiers/app_feature.dart` (enum `AppFeature.splash`) | Implementer (commit) |
| **Backend (Supabase)** | Tabla `app_tier_features`, columna `is_enabled` | Hugo (dashboard) |
| **Edge function** | `feature-flags` (HDU-002) lee la tabla y devuelve el JSON | Deploy-time (ya hecho) |
| **Cliente consulta** | `TierService.has(AppFeature.splash)` | (runtime, automático) |

**El enum y la BD deben coincidir.** El integration test `feature_sync_test.dart` (HDU-002) valida que cada valor del enum tenga al menos una fila en `app_tier_features`. Si agregas un feature nuevo al enum sin agregarlo al seed, el test falla.

---

## 🔄 Procedimiento para activar el flag

### Paso 1: Identificar el feature y el tier

El flag `AppFeature.splash` se puede activar:

- **Por tier (recomendado):** activarlo solo para `tier = 'pro'` (early adopters), luego expandir.
- **Para todos los tiers (rollout masivo):** activarlo para `tier = 'free'` y `tier = 'pro'`.

El seed inicial tiene las dos filas con `is_enabled = false`. El test `feature_sync_test.dart` las valida.

### Paso 2: Conectarse al dashboard de Supabase

1. Ir a https://supabase.com/dashboard/project/iocbqjzmoneulydmeavr/editor
2. Login con la cuenta de Hugo (NO compartir credenciales por chat — ver `docs/runbooks/secrets.md`).
3. En el menú izquierdo, abrir **Table Editor** → tabla `app_tier_features`.

### Paso 3: Editar las filas

Para **activar el splash para todos los usuarios:**

1. Filtrar la tabla por `feature_key = 'splash'`.
2. Para cada fila (free + pro), cambiar `is_enabled` de `false` a `true`.
3. **Save** (Supabase auto-guarda al cambiar el checkbox).

Para **activar solo para `pro`:**

1. Solo editar la fila donde `tier = 'pro'`.
2. La fila de `tier = 'free'` queda en `false`.

### Paso 4: Verificar que la edge function devuelve el cambio

La edge function `feature-flags` cachea la respuesta por 1 minuto. Para verificar inmediatamente:

1. En el dashboard, ir a **Edge Functions** → `feature-flags`.
2. Click en **Invoke** → el body de la respuesta debe mostrar `"splash": true` (o `false`, según el caso).
3. Si el body todavía muestra el valor viejo, esperar 1 minuto (TTL del cache) y volver a invocar.

### Paso 5: Verificar en la app

1. **Cold start** la app en un device físico (NO funciona en `flutter run` con cache de Dart caliente — debe ser cold start del APK).
2. La animación de entrada del splash debe verse (2500ms de scale/rotation/opacity del logo).
3. Después del fade-out (250ms), el redirect decide a dónde ir.
4. **Si el splash no se ve:** la cache del `TierService` en el cliente puede tener el valor viejo. Cold start de nuevo (force-stop + relaunch, no solo background).

---

## 🔄 Procedimiento para desactivar el flag

1. Conectarse al dashboard (Paso 2 de arriba).
2. Filtrar por `feature_key = 'splash'`.
3. Para cada fila que esté en `true`, cambiar a `false`.
4. Esperar 1 minuto (TTL del cache de la edge function).
5. Cold start de la app. El splash se auto-navega sin renderizar el branding.

---

## 🧪 Cómo correr el integration test (Xiaomi)

El integration test `integration_test/splash_flow_test.dart` cubre los dos casos (flag ON/OFF) en device real.

**Pre-requisitos:**

1. **Activación previa del flag** en el dashboard (Paso 3 de arriba) — para el caso "flag ON".
2. **Device Xiaomi conectado** (2203129G, Android 14 API 34).
3. **APK debug instalado** (`flutter install -d 2203129G`).
4. **Sesión de Supabase limpia** en el device (signOut previo, si aplica).

**Comandos:**

```powershell
# Caso 1: flag ON
flutter test integration_test/splash_flow_test.dart -d 2203129G

# Caso 2: flag OFF (apagar el flag en el dashboard antes)
flutter test integration_test/splash_flow_test.dart -d 2203129G
```

**Lo que verifica el test:**

- **Flag ON:** el splash renderiza "ZEIKI" + "LOADING", espera 2800ms (entrada + fade-out), el redirect manda a /login (sin sesión).
- **Flag OFF:** el splash NO renderiza el branding, salta al destino del redirect.

**Limitaciones:**

- El integration test **no automatiza el cambio del flag en Supabase**. Hugo tiene que hacerlo desde el dashboard entre los dos casos.
- El timing de la animación de entrada (~2500ms) está hardcodeado en el test. Si se cambia la duración en `splash_screen.dart`, hay que actualizar el test.
- La verificación visual del branding (que se vea bonito, que el logo esté bien renderizado) la hace Hugo en QA local con el APK.

---

## 🚨 Troubleshooting

### El splash no se muestra aunque el flag está ON

**Causa más probable:** cache del `TierService` o de la edge function desactualizado.

**Pasos:**

1. Esperar 1 minuto (TTL del cache de la edge function).
2. Force-stop la app en el device (Settings → Apps → Zeiki → Force Stop).
3. Re-launch la app (cold start).
4. Si sigue sin verse, verificar en el dashboard que la fila esté en `is_enabled = true`.

### El splash se muestra aunque el flag está OFF

**Causa más probable:** el cache del `TierService` (en memoria del cliente) tenía `true` antes de que se desactivara el flag.

**Pasos:**

1. Force-stop la app (cierra el proceso → pierde el cache).
2. Re-launch (cold start).
3. Si sigue, esperar 1 minuto para que el cache de la edge function expire.

### La edge function devuelve error 500

**Causa probable:** problema de Supabase (caída, mantenimiento).

**Pasos:**

1. Verificar status en https://status.supabase.com/
2. Si Supabase está caído, esperar a que se recupere. La app sigue funcionando con el cache anterior (fail-safe AC4 de HDU-003).
3. Si persiste, ver logs de la edge function en el dashboard: **Edge Functions** → `feature-flags` → **Logs**.

### El integration test falla con "timeout"

**Causa probable:** la animación de entrada tarda más de los 2800ms que el test espera.

**Pasos:**

1. Revisar `lib/features/identidad/screens/splash_screen.dart` → `_entryController.duration`.
2. Si la duración cambió, actualizar el `pump(const Duration(milliseconds: 2800))` en el integration test.

---

## 📋 Checklist antes del rollout a producción

- [ ] El feature flag está en `is_enabled = true` para el tier objetivo (free / pro / ambos).
- [ ] Se corrió el integration test en Xiaomi con el flag activado (caso ON).
- [ ] Se verificó el splash manualmente en el Xiaomi: branding se ve, animaciones corren, fade-out antes del redirect.
- [ ] Se verificó el caso "flag OFF" en el Xiaomi: NO se ve el splash, redirect funciona.
- [ ] Se actualizó `docs/current-state.md` con la fecha de activación.
- [ ] Se notificó al equipo de QA.

---

## 🔗 Referencias

- `lib/core/tiers/app_feature.dart` — enum `AppFeature.splash`.
- `lib/core/tiers/tier_service.dart` — `TierService.has(AppFeature)` (consulta el cache).
- `lib/features/identidad/screens/splash_screen.dart` — widget que consulta el flag.
- `specs/HDU-006-splash-nuevo.md` — spec de la HDU (decisión de producto).
- `specs/HDU-002-supabase-setup.md` — setup de la tabla `app_tier_features`.
- `specs/HDU-003-feature-flag-system.md` — setup del `TierService`.
- `docs/runbooks/secrets.md` — política de secretos (NO compartir credenciales de Supabase por chat).
