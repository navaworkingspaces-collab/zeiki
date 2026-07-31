# Target Architecture — Zeiki

> **El plano maestro hacia donde va Zeiki.** Documento vivo, vigente para migraciones totales o parciales.
>
> **Última actualización:** 2026-07-29 (v2: feedback de Hugo, 5 nuevas secciones)
> **Estado del proyecto:** Fase 1 — MVP. Reescritura desde cero iniciada el 2026-07-29.

---

## Slogan

> **La arquitectura soporta las features, no las dicta.**

Este documento describe **cómo se construye cualquier feature** de Zeiki, no **qué features específicas** tendrá el producto. Si una sección dice "el feature X hace Y", está mal escrita.

---

## 📍 Dónde está Zeiki hoy

Zeiki se encuentra en la **Fase 1 (MVP)** del roadmap arquitectónico. La reescritura desde cero arrancó el 2026-07-29 con la aprobación de este documento. El código del proyecto anterior se conserva únicamente como **referencia para comprender reglas de negocio, algoritmos o integraciones** cuando resulte útil — no se arrastra su deuda técnica.

---

## 🧭 §0. Filosofía del proyecto

> **Esta sección es la fuente única de los principios filosóficos del proyecto.** Los demás documentos (`conventions.md`, `workflow.md`, `git.md`) referencian aquí, no duplican.

### NO INFERENCIA, SOLO PRUEBAS

> **Nunca digas "probablemente pasa X" o "debe ser Y" sin evidencia.** Cita el código exacto: archivo, línea, método, snippet. Si no puedes demostrarlo, márcalo como hipótesis explícita con su plan de verificación.
>
> Aplica a debugging, code review, debates técnicos, reportes a Hugo, ADRs, investigación, **todo**.

**Por qué:** la inferencia lleva a fixes incorrectos, erosiona confianza, y bloquea que las sesiones futuras verifiquen claims. Los equipos de infraestructura grandes arreglan evidencia, no hipótesis.

**Cómo se aplica:**

- **Debugging:** cada claim con `archivo:línea` y evidencia (test, log, output).
- **Code review:** "esto se rompe si X" requiere un test que lo demuestre, no una corazonada.
- **Debates técnicos:** "debemos usar Y" requiere evidencia de que resuelve un problema real, no que suena bien.
- **ADRs:** las justificaciones citan evidencia (mediciones, casos, alternativas evaluadas).
- **Reportes a Hugo:** si no puedes demostrar algo, dilo explícitamente como hipótesis.

**Cuándo SÍ se permite hipótesis:**

- Explícitamente marcada como "hipótesis a verificar:".
- Con el código/línea que la generaría.
- Con plan de verificación (qué test correr, qué log capturar).

---

---

## 🧭 Mapa del negocio

Antes de hablar de capas o de features, hay que entender **qué es Zeiki en su esencia**. Esta sección es el "corazón" del producto. Todo lo demás del documento existe para soportar este flujo.

### Core del negocio

El corazón de Zeiki no es Flutter, ni Supabase, ni BLoC. Es este flujo:

```
Usuario
  ↓
Descarga CFDIs
  ↓
Procesa CFDIs
  ↓
Clasifica CFDIs
  ↓
Calcula impuestos
  ↓
Genera información
  ↓
Ayuda al usuario a decidir
```

Si una pieza de la arquitectura no soporta alguna parte de este flujo, hay que preguntarse si la pieza es necesaria.

### Relaciones entre dominios

Los dominios no son listas aisladas. Se relacionan entre sí:

```mermaid
flowchart LR
    U(("Usuario"))

    U -->|tiene| CONF["Configuración"]
    U -->|posee| CLI["Clientes"]
    U -->|genera| FIS["Fiscal<br/>(CFDIs)"]
    U -->|consulta| REP["Reportes"]
    U -->|interactúa con| ASI["Asistencia"]
    U -->|es| IDE["Identidad"]

    FIS -.usa.-> CLI
    REP -.lee.-> FIS
    REP -.lee.-> CLI
    ASI -.lee.-> FIS
    ASI -.lee.-> REP
    CONF -.gobierna.-> U

    style U fill:#f9f,stroke:#333
```

**Lectura:**
- Un usuario **tiene** configuración, **posee** clientes, **genera** CFDIs, **consulta** reportes e **interactúa con** asistencia.
- El dominio Fiscal **usa** el dominio Clientes (una factura necesita un cliente).
- Reportes **lee** de Fiscal y de Clientes.
- Asistencia **lee** de Fiscal y de Reportes para dar recomendaciones.
- Configuración **gobierna** al usuario (preferencias, plan, notificaciones).

### Context Map (relación con sistemas externos)

Cómo los dominios se conectan con el mundo exterior:

```mermaid
flowchart TB
    subgraph EXT [Sistemas externos]
        SAT["SAT<br/>(SOAP)"]
        FAC["Facturama<br/>(REST)"]
    end

    subgraph CORE [Núcleo de Zeiki]
        FIS["Dominio<br/>Fiscal"]
    end

    subgraph SOP [Soporte]
        CLI["Dominio<br/>Clientes"]
        REP["Dominio<br/>Reportes"]
        ASI["Dominio<br/>Asistencia<br/>(LLM)"]
        CONF["Dominio<br/>Configuración"]
        IDE["Dominio<br/>Identidad"]
    end

    SAT <-->|descarga CFDI| FIS
    FAC <-->|timbrado| FIS

    FIS -.alimenta.-> REP
    CLI -.alimenta.-> FIS
    ASI -.consulta.-> REP
    IDE -.autentica.-> CONF
```

**Lectura:**
- **SAT** y **Facturama** solo hablan con el dominio Fiscal. Ningún otro dominio toca el exterior.
- Esto aísla el riesgo: si el SAT cambia su API, solo se modifica el dominio Fiscal.
- Identidad es transversal: autentica al usuario para todos los demás dominios.

---

## 1. Principios Arquitectónicos

Estos principios guían todas las decisiones técnicas. Si una decisión los viola, hay una razón explícita y documentada (ADR).

1. **Simplicidad antes que complejidad.** Si una pieza se puede resolver con 50 líneas y otra con 500, preferimos la primera mientras cubra el caso.
2. **No optimizar prematuramente.** Optimizar cuando duela, no cuando suene elegante.
3. **Domain First.** Pensar en términos de dominios del negocio, no de carpetas técnicas.
4. **Clean Architecture.** Separación clara de capas, dependencias hacia adentro.
5. **Todo cambio debe ser observable.** Si algo cambia y no se puede ver que cambió, no está terminado.
6. **Todo comportamiento importante debe ser testeable.** Si no se puede probar, no se puede mantener.
7. **Automatizar antes que documentar procesos manuales.** Si hay que hacer algo dos veces, se automatiza.
8. **Una sola fuente de verdad por concepto.** Configuraciones, constantes, catálogos: un solo lugar.

---

## 2. Atributos de Calidad

Para cada atributo, qué significa concreto para Zeiki. Los **atributos generales** se aterrizan después en **SLOs por feature** (abajo), que son medibles y accionables.

| Atributo | Qué significa para Zeiki |
|----------|--------------------------|
| **Escalabilidad** | La arquitectura soporta de 100 a 10,000 clientes activos sin reescritura. Después de 10K, se evalúan piezas nuevas con evidencia. |
| **Observabilidad** | Todo error importante debe poder localizarse en menos de 5 minutos (logs + trazas + alertas). |
| **Disponibilidad** | Si un proveedor externo (SAT, Facturama) falla, la aplicación sigue siendo utilizable para el resto. |
| **Mantenibilidad** | Un dev nuevo debe poder contribuir en menos de 1 semana gracias a documentación + tests + estructura. |
| **Testabilidad** | Todo flujo crítico está protegido por tests automatizados que fallan si se rompe. |
| **Seguridad** | Credenciales nunca en código. Datos sensibles encriptados en reposo y tránsito. Auth obligatorio en cada endpoint. |
| **Rendimiento** | Operaciones visibles al usuario (UI, cálculos, validaciones) responden en < 2s. Jobs async no bloquean la UI. |
| **Costo operativo** | Una sola persona puede operar y mantener el sistema en horario laboral normal. |

### SLOs por feature (medibles, accionables)

Los atributos anteriores son dirección. Los SLOs son lo que se **mide** para saber si vamos bien. Cada feature crítica tiene su SLO explícito.

| Feature | SLO | Cómo se mide |
|---------|-----|---------------|
| **Login (email)** | p95 < 500ms | log de `auth.sign_in_completed` con duración |
| **Login (Google)** | p95 < 1.5s (OAuth es más lento por naturaleza) | log de `auth.google_sign_in_completed` con duración |
| **Cálculo de IVA / ISR** | p99 < 100ms | log de `tax.calculation_completed` con duración |
| **Generación de factura (timbrado Facturama)** | p95 < 3s | log de `invoice.timbrado_completed` con duración |
| **Descarga SAT (job completo)** | 95% de jobs en < 7 min | log de `sat.download_completed` con duración total |
| **Dashboard (carga inicial)** | p95 < 2s | log de `dashboard.loaded` con duración |
| **Búsqueda de clientes** | p95 < 300ms | log de `clients.search_completed` con duración |
| **Disponibilidad general** | 99% mensual (excluye mantenimientos programados) | uptime monitor externo |

**Reglas:**

- Si un SLO se viola consistentemente, se abre HDU para investigar.
- Los SLOs se revisan **trimestralmente** (en cleanup de HDU).
- Un SLO que se incumple por más de 1 mes consecutivo es candidato a "se acepta el nuevo nivel" o "se invierte en arreglar".

---

## 3. Restricciones

Decisiones que se **NO** se toman hasta que la evidencia lo justifique. Evita "architecture astronautics" (complejidad gratis).

| Restricción | Hasta cuándo |
|-------------|--------------|
| No usar microservicios | Antes de 50,000 usuarios activos. |
| No usar Kafka / Event Bus | Hasta que existan múltiples consumidores de un mismo evento. |
| No agregar Redis | Hasta demostrar que Postgres solo no aguanta la carga. |
| No agregar Kubernetes | Mientras una sola instancia soporte la carga. |
| No agregar multi-tenancy | Hasta que el producto se ofrezca como white-label a otras empresas. |
| No usar GraphQL | Hasta que REST + Edge Functions no alcancen. |
| No usar ORM pesado | Mientras `supabase_flutter` + queries SQL cubran el caso. |
| No usar `setState` para lógica de negocio | Nunca. Ya está documentado como anti-patrón. |

**Regla de oro:** si alguien quiere introducir una pieza que rompa alguna restricción, escribe un ADR-XXX con evidencia (mediciones, projections, casos concretos).

---

## 4. Roadmap Arquitectónico

Dónde está Zeiki AHORA y hacia dónde va. Cada fase tiene un criterio claro de cierre.

```
Fase 1          Fase 2            Fase 3              Fase 4             Fase 5
MVP  ────────►  Observabilidad ──► Testing completo ──► Escalabilidad ───► Distribución
                                                                        masiva
```

### Fase 1 — MVP (ACTUAL)
- Arquitectura base funcionando: cliente + backend + dominios core.
- Features mínimas viables definidas en §15.
- Sin observabilidad avanzada. Sin suite de tests completa.
- Deploy manual.

**Cierre:** las features mínimas viables funcionan end-to-end y un usuario real puede completar el flujo principal.

### Fase 2 — Observabilidad
- Logs centralizados (eventos clave: login, fallo de red, job async, error externo).
- Telemetría básica (eventos de usuario describen INTENCIÓN, no features).
- Dashboard de eventos para Hugo.

**Cierre:** un error en producción se localiza en menos de 5 minutos con los logs.

### Fase 3 — Testing completo
- Unit + widget + integration + regression.
- Matriz de criticidad implementada (todo flujo crítico protegido).
- CI ejecuta la suite en cada PR.

**Cierre:** un cambio en login que rompe onboarding falla en CI antes de mergear.

### Fase 4 — Escalabilidad
- Distribución automática (Code Magic + Firebase App Distribution, sin USB).
- Rate limiting por tier (los tiers ya existen, falta el enforcement).
- Cache del dashboard.
- Optimización de queries lentas con evidencia.

**Cierre:** la app soporta 1,000 clientes activos sin intervención manual.

### Fase 5 — Distribución masiva
- Solo cuando duela (10K+ usuarios). Evaluar con evidencia:
  - Event Bus / Kafka (si hay múltiples consumidores).
  - Sharding de Postgres (si una sola instancia no aguanta).
  - Workers dedicados (si los jobs async crecen).
  - Microservicios extraídos (si una feature necesita escalar independientemente).

**Cierre:** la decisión de cada pieza nueva se toma con datos, no con suposiciones.

---

## 4.1. Evolución por escala (guía de decisiones basada en evidencia)

Este es un roadmap **numérico**, complementario al roadmap de fases de §4. Define qué decisión tomar cuando Zeiki alcanza ciertos umbrales de usuarios activos.

| Usuarios activos | Decisión |
|------------------|----------|
| **100** | No hacemos nada. La arquitectura actual sobra. |
| **1,000** | Agregar cache del dashboard (Redis o similar). Optimizar queries que ya duelan. |
| **10,000** | Separar workers (jobs async en proceso/servicio dedicado, no Edge Functions). Rate limiting por tier enforced. |
| **50,000** | Evaluar microservicios. Extraer los dominios que necesiten escalar independientemente. |
| **100,000** | Evaluar particionado de Postgres (sharding por user_id, partición por fecha, etc.). |
| **1,000,000** | (No pensado todavía. Problema de otra escala. Se aborda cuando se llegue con datos.) |

**Reglas:**
- Toda decisión se activa cuando el umbral se **alcanza y se sostiene** durante 3 meses (no se reacciona a picos).
- Antes de activar cualquier decisión, se mide: latencia, costo, tasa de error, uso de CPU/memoria.
- Si una decisión se activa y luego los usuarios bajan del umbral, se revierte.

---

## 5. Diagrama de Capas (agnóstico de features)

Zeiki sigue una arquitectura en 4 capas. La dirección de las dependencias siempre va **hacia adentro**: las capas externas dependen de las internas, nunca al revés.

```mermaid
flowchart TB
    subgraph C1 [Capa 1: Cliente]
        UI["UI / Páginas<br/>(presentación)"]
        BLOC["BLoCs<br/>(estado)"]
    end

    subgraph C2 [Capa 2: Dominio]
        UC["Casos de uso<br/>(lógica de negocio)"]
        ENT["Entidades<br/>(modelos puros)"]
    end

    subgraph C3 [Capa 3: Datos]
        REPO["Repositorios<br/>(contratos + impl)"]
        DS["Datasources<br/>(APIs, DB, storage)"]
    end

    subgraph C4 [Capa 4: Infraestructura]
        EXT["Servicios externos<br/>(SAT, Facturama)"]
        DB[("Postgres<br/>(Supabase)")]
        FNS["Edge Functions<br/>(Deno)"]
    end

    UI --> BLOC
    BLOC --> UC
    UC --> ENT
    UC --> REPO
    REPO --> DS
    DS --> DB
    DS --> FNS
    FNS --> EXT
    DS --> EXT
```

**Reglas:**

- Capa 1 NO conoce Capa 3 directamente.
- Capa 2 NO conoce Capa 1 ni Capa 3.
- Capa 3 implementa contratos de Capa 2.
- Capa 4 es intercambiable (cambiar Postgres por otra cosa no afecta las capas de arriba).

### Caso especial: dominio que solo lee de otros

Algunos dominios (ej. **Asistencia**, **Reportes**) son **cross-cutting**: leen de varios dominios pero no tienen data propia.

- **Tienen repositorios** (interfaz en `domain/`, implementación en `data/`) que apuntan a los repositorios de los otros dominios, NO a la BD directamente.
- **NO tienen data propia** en la BD.
- **NO modifican** data de otros dominios directamente. Si una recomendación lleva a una acción, la acción la dispara el dominio dueño de esa data (ej. Asistencia recomienda "subir este gasto" → Clientes recibe la orden).
- **Exponen casos de uso** que devuelven agregados (ej. "dame contexto fiscal del último mes + perfil del usuario + recomendaciones previas") en vez de CRUD.

Esto evita que Asistencia termine con su propia capa de mutación que duplica lógica de otros dominios.

---

## 6. Dominios del Negocio (agnósticos de features)

Zeiki se organiza en dominios. **Un dominio es un área del problema, no una pantalla ni un botón.** Las features se construyen DENTRO de los dominios.

| Dominio | Responsabilidad | Ejemplo de feature (no exhaustivo) |
|---------|-----------------|-----------------------------------|
| **Identidad** | Quién es el usuario, cómo se autentica, cómo se recupera la sesión. | Login, magic link, biometría. |
| **Fiscal** | Todo lo relacionado con CFDIs: descarga, timbrado, cancelaciones, firmas. | Descarga SAT, facturación, eFirma. |
| **Clientes** | Gestión de las entidades receptoras de CFDIs. | Alta de clientes, validación de RFC. |
| **Reportes** | Cálculos y vistas sobre los datos fiscales. | Dashboard, métricas, exportación. |
| **Asistencia** | Interacción con el usuario asistida por modelos. | Cálculo fiscal, recomendaciones, chat. |
| **Configuración** | Preferencias del usuario y de la app. | Perfil, planes, notificaciones. |

**Regla:** si un nuevo concepto del negocio no encaja en ningún dominio existente, se crea un dominio nuevo (no se mete a la fuerza en uno existente). Si un dominio crece demasiado, se divide.

### Ownership por dominio

Cada dominio tiene un dueño único. Aunque hoy seas tú solo, declarar el ownership evita caos cuando llegue un segundo dev.

| Dominio | Dueño | Responsabilidad | Restricción |
|---------|-------|------------------|-------------|
| **Identidad** | Hugo (Zeiki Core) | Sesión, autenticación, recuperación, biometría. | No modifica otros dominios. |
| **Fiscal** | Hugo (Zeiki Core) | CFDIs, descarga SAT, timbrado Facturama, eFirma, cancelaciones. | Único dominio que habla con SAT y Facturama. |
| **Clientes** | Hugo (Zeiki Core) | Alta, validación RFC, direcciones. | No accede a SAT ni Facturama. |
| **Reportes** | Hugo (Zeiki Core) | Cálculos, dashboard, exportación. | Solo lee de otros dominios. Nunca escribe. |
| **Asistencia** | Hugo (Zeiki Core) | LLM, recomendaciones, chat fiscal. | Solo lee. Si una recomendación lleva a una acción, la dispara el dominio dueño de esa data. |
| **Configuración** | Hugo (Zeiki Core) | Perfil, planes, preferencias, notificaciones. | Gobierna al usuario; no a otros dominios. |

**Servicios transversales (no son dominios, viven en `lib/core/`):**

- **Auth** (gestión de tokens, refresh, logout) → `lib/core/auth/`.
- **TierService** (state global de tier + feature flags) → `lib/core/tiers/`.
- **BiometricService** → `lib/core/services/`.
- **PostalCodeService** → `lib/core/services/`.
- **Logging centralizado** → `lib/core/logging/`.

**Regla:** los features (`lib/features/<dominio>/`) **importan** de `lib/core/`, pero `lib/core/` **NO importa** de `lib/features/`. Si un servicio transversal necesita lógica de un dominio, el dominio expone un caso de uso, NO se invierte la dependencia.

**Regla:** un dominio solo modifica SU data. Para escribir en otro dominio, publica un evento (cuando exista el Event Bus) o hace una llamada explícita al caso de uso del otro dominio (en MVP).

### Aclaración sobre Asistencia y mutación

Asistencia es **cross-cutting solo-lector**: lee de Reportes, Fiscal y Clientes para dar contexto al LLM. **NO escribe directamente** en ningún otro dominio.

**Si Asistencia recomienda algo que requiere mutar data** (ej. "te conviene clasificar este CFDI como deducible"):

1. Asistencia expone un `RecommendationEntity` con la sugerencia.
2. La UI muestra la sugerencia al usuario.
3. Si el usuario acepta, se dispara el caso de uso del **dominio dueño de esa data** (ej. Clientes acepta, Fiscal ejecuta).
4. Asistencia no se entera (no se suscribe al resultado).

Esto evita que Asistencia se vuelva un "dios" que muta todo.

---

## 7. Contratos entre Capas

### Cliente ↔ Edge Functions

- **Request:** JSON, validación de schema en ambos lados.
- **Response:** JSON con campos `data` (éxito) o `error` (fracaso). Nunca se mezclan.
- **Versionado:** el path incluye la versión (`/v1/...`). Breaking changes = nueva versión.
- **Auth:** siempre token en header. Funciones sin auth explícita son bug.

### Repositorios ↔ Datasources

- **Input:** entidades del dominio (no modelos del datasource).
- **Output:** entidades del dominio o `null` / excepciones tipadas.
- **Errores:** mapeados a excepciones del dominio (no se propagan errores de Supabase crudos).

### BLoCs ↔ Casos de uso

- **Input:** parámetros del evento (puros, no widgets).
- **Output:** `Future<Result<T>>` o `Stream<T>`. Nunca callbacks.
- **Side effects:** navegación y snackbars van en el `listener` del `BlocConsumer`, no en el BLoC.

---

## 8. Estrategia de Observabilidad

### Qué se loguea (mínimo)

| Evento | Nivel | Datos |
|--------|-------|-------|
| Auth (login, logout, fallo) | INFO / WARN | user_id, método, razón del fallo |
| Llamada a proveedor externo | INFO / ERROR | proveedor, endpoint, duración, status |
| Job async (inicio, fin, fallo) | INFO / ERROR | job_id, tipo, duración, error |
| Error inesperado (exception) | ERROR | stack trace, contexto mínimo |
| Cambio de plan / suscripción | INFO | user_id, plan anterior, plan nuevo |

### Dónde se almacena

- **Corto plazo (debug, 7 días):** logs de Edge Functions en Supabase Dashboard.
- **Mediano plazo (análisis, 90 días):** tabla `app_events` en Postgres con `event_type`, `payload`, `user_id`, `created_at`.
- **Largo plazo (futuro):** servicio externo dedicado si el volumen lo justifica (no antes de Fase 4).

### Logs del cliente Flutter

**Hoy (MVP):** la app cliente NO envía logs al servidor automáticamente. Se loguea local con `debugPrint` en dev, y los errores visibles al usuario se reportan vía la pantalla de soporte.

**Fase 2 (Observabilidad):** se introduce error tracking dedicado del cliente:

- **Opción preferida:** **Sentry** (estándar de facto, free tier suficiente para MVP, soporta Flutter nativo, dashboards y alertas listos).
- **Alternativa:** tabla `client_errors` propia, instrumentada manualmente (más trabajo, menos features out-of-the-box).
- **Decisión:** se documenta en ADR cuando llegue Fase 2. **TBD** — no se documenta decisión que aún no se toma.

Mientras tanto, los crashes que se quieran reportar se envían manualmente desde el dispositivo con `adb logcat` o equivalente.

### Cómo se consulta

- **Debug en vivo:** Supabase Dashboard → Edge Function logs.
- **Búsqueda de error:** SQL sobre `app_events` filtrando por `user_id`, `event_type`, rango de fechas.
- **Alertas:** reglas simples sobre `app_events` (ej. "más de 10 errores 500 en 5 min").

### Estándar de trazabilidad (agnóstico del proveedor)

Para evitar lock-in con un proveedor de logs/trazas, la instrumentación sigue el estándar **OpenTelemetry** cuando esté disponible. Si mañana se cambia de Supabase a otra cosa, los traces sobreviven.

- **Hoy:** los logs son strings con prefijos (`[sat-auto-download]`, `[auth-google-proxy]`).
- **Fase 2:** se migra a OpenTelemetry cuando se integre Sentry (o el proveedor que se elija).

---

## 9. Estrategia de Telemetría

Los eventos de telemetría describen **INTENCIÓN del usuario**, no features específicas. Esto permite cambiar la UI sin perder la métrica.

| ❌ Mal (ata a feature) | ✅ Bien (describe intención) |
|------------------------|-------------------------------|
| "click en botón_login" | "usuario inició intento de autenticación" |
| "HDU-005 terminada" | "usuario completó la configuración inicial" |
| "campo_efirma_lleno" | "usuario completó el flujo de firma" |

**Implementación:** eventos como `app_telemetry` con campos `event_name`, `user_id`, `properties` (JSON), `created_at`. Documentación de cada `event_name` en este mismo documento (no en código).

---

## 10. Estrategia de Feature Flags

Feature flags permiten desplegar código que no se activa para todos.

### Tipos

| Tipo | Propósito | Ejemplo |
|------|-----------|---------|
| **Release** | Apagar feature antes de estar lista. | "Nuevo dashboard" (off hasta que se valide). |
| **Experiment** | A/B test entre variantes. | "Versión A vs B del flujo de onboarding". |
| **Ops** | Kill switch operacional. | "Desactivar descarga SAT si el SAT está caído". |

### Regla de CD seguro: feature flag obligatorio

> **Toda feature nueva nace detrás de un feature flag** (tipo Release) y permanece oculta hasta que se valida explícitamente. Esto convierte el CD de "cualquier cambio llega a usuarios inmediatamente" a "cualquier cambio llega al servidor, pero solo lo activamos cuando estamos listos".

**Aplica a:**

- Features que tocan el flujo principal del usuario.
- Cambios visuales que afectan la primera impresión.
- Integraciones nuevas con proveedores externos.

**No aplica a:**

- Bug fixes que arreglan comportamiento roto.
- Refactors sin cambio de comportamiento.
- Cambios solo de docs.

**Cómo se ve en el spec de la HDU:**

```markdown
**Feature flag requerido:** [Release] `nuevo_dashboard`
**Plan de remoción:** tras 30 días con 100% de usuarios activos y métrica estable.
```

**Plan de remoción (deprecación):**

1. Flag al 100% por al menos 30 días.
2. Métrica estable (sin regresión).
3. Remover el flag del código y de la BD.
4. HDU de cleanup dedicada.

### Estrategia de deprecación de features

Cuando una feature se va a apagar (no solo un flag, sino la feature completa):

1. **Anuncio previo:** changelog con fecha de deprecación. Al menos 1 release de aviso antes de apagar.
2. **Migración si aplica:** si la feature se reemplaza por otra, la nueva está lista y documentada antes de apagar la vieja.
3. **Kill switch:** durante la transición, ambas features conviven detrás de un flag, para rollback rápido.
4. **Telemetría de uso:** antes de apagar, confirmar que el uso real es <5% de los usuarios activos. Si no, retrasar.
5. **Comunicación al usuario:** si la feature es visible para el usuario, notificarle en la app (banner, modal) con al menos 1 release de anticipación.
6. **Cleanup post-apagado:** remover código, tests, docs, migraciones de datos (si las hubo). HDU dedicada.

**Status:** Diferido. Aplica cuando se apague la primera feature (ej. "Descarga del día" cuando esté 100% reemplazada por la automática).

---

## 🗃️ Repos relacionados

- **`zeiki` (este repo):** código nuevo, reescritura desde cero. Único repo activo.
- **`seiki_app` (legacy, en `navaworkingspaces-collab/`):** el proyecto anterior. Se mantiene en **read-only indefinidamente** como referencia histórica. NO se borra.
  - **Para qué sirve:** consultar algoritmos validados, integraciones probadas, reglas de negocio aprendidas.
  - **Qué NO se hace:** no se commitea a `seiki_app`. No se hacen PRs. No se reabren HDUs cerradas ahí.
  - **Migración selectiva:** se traen **handoffs, lecciones y specs cerradas** que valgan la pena. NO se trae código. Procedimiento en `workflow.md` §Migración selectiva.

### Cómo se crean

- Definidos en código como enum type-safe (`AppFeature`).
- Configuración por tier + override por usuario (testing) en backend.
- Sincronización entre código y BD verificada por test.

**Status:** TBD. El test `feature_sync_test.dart` que verifica que el enum y la tabla `app_tier_features` estén sincronizados **no está escrito todavía**. Se documenta como aspiración honesta; no se afirma que existe.

**Documentación auto-generada (aspiración):**

El enum `AppFeature` debería tener un **script que genere automáticamente** `docs/feature-flags.md` desde el código. Sin este script, la documentación de qué features existen se desactualiza inevitablemente.

- **Status:** TBD. Se implementa cuando el sistema de feature flags esté en uso activo (>5 features).
- **Cómo funcionaría:** un script Deno/Python lee el enum `AppFeature`, lee la tabla `app_tier_features`, y genera un markdown con la matriz.
- **Cuándo corre:** en CI, en cada PR que toque el enum. Si el markdown generado no se commitea, el CI falla.

### Cómo se evalúan

```dart
// ✅ CORRECTO: type-safe
if (TierService.has(AppFeature.nuevoDashboard)) {
  // mostrar
}

// ❌ MAL: string suelto
if (TierService.hasFeature('nuevo_dashboard')) {
  // mostrar
}
```

### Cómo se mide el impacto

- Telemetría: cada flag tiene un evento `flag_evaluated` con `flag_name` y `result`.
- Decisión de remover un flag: cuando el 100% de los usuarios lo tiene activo y la métrica es estable.

---

## 11. Estrategia de Testing (matriz de criticidad)

**No usamos porcentajes de coverage.** El coverage es engañoso: hay proyectos con 98% de cobertura llenos de tests inútiles, y otros con 55% que prácticamente no se rompen. Lo que importa es que **todo flujo crítico esté protegido**.

### Matriz de criticidad inicial

| Componente | Criticidad | Tipo de test mínimo | Notas |
|------------|------------|---------------------|-------|
| Casos de uso fiscales (timbrado, cálculo) | **Muy alta** | Unit + integration | Si esto falla, el usuario no factura. |
| Descarga SAT | **Muy alta** | Unit (mockeando SAT) + integration | Toca sistema externo crítico. |
| Login (email, OAuth, biometric) | **Muy alta** | Unit + widget + integration | Bloquea todo lo demás. |
| Cálculos de impuestos (IVA, ISR) | **Muy alta** | Unit | Un decimal mal y el SAT rechaza. |
| Repositorios (contratos) | Alta | Unit (con mocks) | Aíslan a los BLoCs del backend. |
| BLoCs (transiciones de estado) | Alta | Unit (`bloc_test`) | Cubren la lógica de UI. |
| Edge Functions (lógica async) | Alta | Unit (Deno) | Cubren jobs largos. |
| Widgets visuales (no críticos) | Baja | Widget selectivo | Solo si la lógica no trivial está en el widget. |
| Helpers / utils | Media | Unit | Si la lógica es no trivial. |
| Migraciones SQL | Alta | Test contra DB staging | Verificar idempotencia y schema. |

### Reglas

- **TDD:** para flujos críticos, escribir el test que falla ANTES de implementar.
- **Regression:** para cada bug arreglado, un test que reproduce el bug (debe fallar antes del fix, pasar después).
- **Pipeline:** todo test debe pasar antes de mergear a `main`.

---

## 12. Estrategia de CI/CD

### Build

- **Lint:** `flutter analyze` debe pasar 0 warnings.
- **Tests:** `flutter test` debe pasar 100%.
- **Build:** `flutter build apk --debug` debe compilar sin errores.
- **Edge Functions:** `deno check` + `deno test --allow-read --allow-env` en cada función.

### Distribución

- **Code Magic** buildea automáticamente en cada push a `main`.
- **Firebase App Distribution** recibe el APK y notifica a los testers.
- **Hugo** recibe un link en su correo, lo abre en el móvil, se instala. **Sin USB.**

### Environments

- **dev:** rama `main` (auto-deploy, para testing).
- **staging:** rama `release/staging` (próximamente, para QA formal).
- **prod:** rama `release/prod` (próximamente, manual, para usuarios reales).

### Rollback

- Si un build falla en producción: git revert + push. Code Magic redespliega el anterior.
- Si un build funciona pero rompe algo: feature flag para apagar la feature sin redeploy.

---

## 12.1. Arquitectura Operacional

La arquitectura no termina cuando `flutter build` compila. También incluye cómo se **mantiene vivo** el sistema en producción.

### Backups

- **Postgres:** Supabase hace backups automáticos diarios (Point-in-Time Recovery habilitado en plan Pro).
- **Storage (archivos CFDI, eFirma):** replicación geográfica gestionada por Supabase.
- **Verificación:** un test automatizado restaura un backup a staging una vez al mes para confirmar que es recuperable.

### Rotación de secretos

- Credenciales (Supabase keys, OAuth client secrets, Facturama API key) en `assets/.env` para dev, en secretos de Supabase para prod.
- Rotación cada 6 meses o inmediatamente si hay sospecha de compromiso.
- Proceso documentado en `docs/runbooks/rotate-secrets.md` (pendiente de crear).

### Recuperación ante desastres

- **RPO (Recovery Point Objective):** máximo 24h de datos perdidos (corte del último backup).
- **RTO (Recovery Time Objective):** máximo 4h para volver a tener la app operativa.
- Plan documentado en `docs/runbooks/disaster-recovery.md` (pendiente).

### Monitoreo y alertas

- Eventos críticos (login fallido, error 500, timeout de proveedor externo) en `app_events` con nivel ERROR.
- Alertas simples: correo a Hugo si más de 10 errores 500 en 5 minutos, o si la tasa de fallo de descarga SAT supera el 20%.

### Manejo de incidentes

- Niveles: P1 (app caída), P2 (feature crítica caída), P3 (degradación).
- Tiempo de respuesta: P1 inmediato, P2 < 2h, P3 < 1 día hábil.
- Post-mortem obligatorio para P1 y P2, archivado en `docs/postmortems/`.

### Disponibilidad de proveedores externos

- **SAT:** sin SLA público. Asumir caídas frecuentes. La app debe funcionar para tareas que no requieren SAT.
- **Facturama:** depende del plan contratado. Documentar en onboarding cuál es el plan y sus límites.
- **Supabase:** SLA 99.9% en plan Pro. Caídas cortas, asumibles.

### Límites y cuotas a respetar

- **Supabase Edge Functions:** timeout 150s. Patrón async + crons para jobs largos.
- **Supabase Postgres:** tamaño de fila, número de conexiones, tamaño de base según plan.
- **Facturama:** límite de timbrado por minuto/hora según plan. Documentar en el dominio Fiscal.

### Operación por una sola persona

- Toda la operación (deploy, monitoreo, respuesta a incidentes) debe ser realizable por Hugo solo, en horario laboral.
- Si algo requiere estar 24/7 pendiente, se documenta como restricción y se busca automatizar o delegar antes de Fase 4.

---

## 13. ADRs (Architecture Decision Records)

Cada decisión grande tiene un ADR en `docs/adr/ADR-XXX-<slug>.md` con el formato: **Contexto / Decisión / Por qué / Alternativas consideradas / Trade-offs / Cuándo se revisa.**

**Índice de ADRs vigentes:**

| # | Título | Archivo | Estado |
|---|--------|---------|--------|
| 001 | Clean Architecture | [docs/adr/ADR-001-clean-architecture.md](../adr/ADR-001-clean-architecture.md) | Aceptado |
| 002 | Flutter como cliente | [docs/adr/ADR-002-flutter.md](../adr/ADR-002-flutter.md) | Aceptado |
| 003 | Supabase como backend | [docs/adr/ADR-003-supabase.md](../adr/ADR-003-supabase.md) | Aceptado |
| 004 | BLoC para state management | [docs/adr/ADR-004-bloc.md](../adr/ADR-004-bloc.md) | Aceptado |
| 005 | GetIt para DI | [docs/adr/ADR-005-getit.md](../adr/ADR-005-getit.md) | Aceptado |
| 006 | Code Magic + Firebase para CI/CD | [docs/adr/ADR-006-codemagic-firebase.md](../adr/ADR-006-codemagic-firebase.md) | Aceptado |
| 007 | Deno + TS para Edge Functions | [docs/adr/ADR-007-deno-edge-functions.md](../adr/ADR-007-deno-edge-functions.md) | Aceptado |
| 008 | Estructura de dominios | [docs/adr/ADR-008-domain-structure.md](../adr/ADR-008-domain-structure.md) | Aceptado |
| 009 | Reescritura desde cero | [docs/adr/ADR-009-rewrite-with-knowledge-reuse.md](../adr/ADR-009-rewrite-with-knowledge-reuse.md) | Aceptado |
| 010 | TierService como state global | [docs/adr/deprecated/ADR-010-tier-service.md](../adr/deprecated/ADR-010-tier-service.md) | Supersedido por ADR-011 |
| 011 | TierService registrado en GetIt | [docs/adr/ADR-011-tier-service-getit-registration.md](../adr/ADR-011-tier-service-getit-registration.md) | Aceptado |
| 012 | Router en `core/` con imports a `features/` + GoRouter en GetIt | [docs/adr/ADR-012-router-location-and-getit.md](../adr/ADR-012-router-location-and-getit.md) | Aceptado |

**Cómo se agregan nuevos ADRs:**

1. Copiar la plantilla de un ADR existente.
2. Numerar correlativamente (siguiente número disponible).
3. Discusión: si la decisión es controversial, abrir issue con `RFC:` en el título antes de escribir el ADR.
4. Commit con prefijo `docs(adr): add ADR-XXX-<slug>`.
5. Actualizar la tabla de arriba.
6. Si el ADR **reemplaza** uno anterior (decisión revertida), el ADR viejo se mueve a `docs/adr/deprecated/` con nota del reemplazo.

**Cuándo un ADR se considera deprecated:**

- La decisión ya no aplica (cambio de stack, de proveedor, de escala).
- Se creó un ADR nuevo que contradice al anterior.
- La decisión se revirtió por evidencia.

---

## 13.1. Decisiones diferidas

Cosas que **se pensaron** y se decidió **no hacer** (todavía). Esto evita que dentro de seis meses alguien pregunte "¿por qué nunca consideramos X?".

| Decisión diferida | Por qué se difirió | Cuándo se revisa | Trigger activo |
|-------------------|--------------------|--------------------|----------------|
| **Offline mode** | Aumenta complejidad de sincronización. App no es crítica offline en MVP. | Cuando el usuario lo pida o cuando haya 100+ usuarios activos. | **Revisión:** al inicio de cada Fase, en `current-state.md` se cuenta cuántos usuarios activos hay. |
| **Sincronización incremental de CFDIs** | La descarga masiva ya cubre el caso común. | Cuando la descarga completa tarde más de 1 hora por usuario. | **Trigger:** al implementar descarga para un usuario nuevo, medir duración. |
| **Push notifications** | Se puede resolver con polling en MVP. | Fase 2 (Observabilidad/Telemetría) si se justifica. | **Trigger:** al llegar a Fase 2, re-evaluar. |
| **Cache distribuido (Redis)** | Postgres + cache local cubren MVP. | Cuando lleguemos a 1,000 usuarios activos (umbral de §4.1). | **Revisión:** trimestral, contar usuarios activos. |
| **IA local (on-device)** | Requiere modelos cuantizados, batería, almacenamiento. El LLM server-side cubre MVP. | Si el costo de LLM server-side supera el beneficio. | **Trigger:** al revisar costos mensuales de LLM. |
| **Versionado de esquemas de BD** | Migraciones SQL ad-hoc bastan por ahora. | Cuando haya necesidad de rollback atómico entre versiones. | **Trigger:** al aparecer un bug de migración que requiera rollback. |
| **Multi-tenancy** | No es producto white-label. | Si se ofrece como servicio a otras empresas. | **Trigger:** al evaluar caso de negocio de white-label. |
| **App iOS** | No priorizado. Android es el target. | Cuando haya usuarios iOS demandantes. | **Trigger:** al detectar demanda en métricas de soporte. |
| **Event Bus / Kafka** | No hay múltiples consumidores todavía. | Cuando duela (umbral 50K usuarios o múltiples consumidores reales). | **Revisión:** trimestral, contar consumers reales. |
| **Microservicios** | La complejidad operativa no se justifica. | Cuando un dominio necesite escalar independientemente. | **Trigger:** al detectar que un dominio tiene latencia por carga. |
| **GraphQL** | REST + Edge Functions cubren el caso. | Si el tamaño de las respuestas REST se vuelve problema. | **Trigger:** al medir respuestas > 100KB o > 50ms serialización. |
| **Kubernetes** | Una sola instancia cubre la carga. | Cuando el costo/beneficio de orquestación supere al de VM única. | **Trigger:** al evaluar auto-scaling real. |

**Regla:** una decisión diferida no se reconsidera "porque sí". Se reconsidera cuando se cumple la condición de revisión o el trigger activo dispara.

**Proceso de revisión activa:** al inicio de cada cleanup de HDU, Mavis (o el orquestador de turno) revisa las decisiones diferidas y verifica si algún trigger se cumplió. Si sí, se abre issue o HDU nueva para abordar.

---

## 14. Anti-patrones explícitos

Lo que **NO** se hace en Zeiki, y por qué.

| Anti-patrón | Por qué se prohíbe | Reemplazo |
|-------------|---------------------|-----------|
| Lógica de negocio en widgets | Acopla UI con reglas, no se puede testear. | BLoC + casos de uso. |
| `setState` para lógica de negocio | Mezcla UI con estado que otros componentes necesitan. | BLoC para estado compartido; `setState` solo para UI puramente local. |
| Credenciales hardcoded en código | Riesgo de seguridad, fuga en commits. | Variables de entorno + secrets manager. |
| Rutas hardcoded en widgets | Acoplamiento, refactorizar duele. | `AppRoutes.<constante>`. |
| Múltiples puntos de navegación post-auth | Bugs fantasma (doble push, navegación durante loading). | Solo `SplashPage` orquesta. |
| Servicios sin interfaz abstracta | Difícil de testear, difícil de cambiar. | Interface en `domain/`, implementación en `data/`. |
| Microservicios prematuros | Complejidad operativa sin beneficio. | Monolito modular hasta 50K usuarios. |
| Event Bus / Kafka prematuro | Agrega una pieza distribuida sin consumidores reales. | Polling + crons hasta que duela. |
| Multi-tenancy innecesaria | Complejidad en cada query, en cada tabla. | Single-tenant hasta que se ofrezca white-label. |
| ORM pesado (`prisma`, `drizzle`) | Capa extra que rara vez se necesita. | `supabase_flutter` + SQL directo cuando se necesita. |
| Over-engineering ("architecture astronautics") | Resolver problemas que no tenemos. | Esperar a que el problema duela con datos. |
| Documentación al construir | El contexto se pierde, se vuelve obsoleta. | Documentar al cerrar, validado por el usuario. |
| Cobertura de tests como meta numérica | Métrica de vanidad, no de calidad. | Matriz de criticidad: flujos críticos protegidos. |

---

## 15. Features Mínimas Viables (referencia, no arquitectura)

**Esta sección NO es parte de la arquitectura.** Está aquí solo para indicar qué se va a construir PRIMERO con esta arquitectura. Las features cambian, la arquitectura no.

> **Nota:** esta lista es tentativa y se refinará en HDUs de implementación. Lo importante es que las features se construyan SOBRE los planos, no que los planos asuman features específicas.

### MVP de Fase 1

- **Identidad:** login con email + Google + biometría.
- **Fiscal:** descarga masiva del SAT + timbrado con Facturama.
- **Clientes:** alta y validación de RFC.
- **Reportes:** dashboard con IVA, ISR y totales.
- **Asistencia:** cálculo fiscal básico.
- **Configuración:** perfil del usuario, plan actual.

### No están en MVP (Fase 2 en adelante)

- Notificaciones push.
- Reportes avanzados (exportación, comparativas).
- Chat con IA.
- Multi-tenancy.
- App iOS.

---

## 📂 Documentos relacionados

- `specs/HDU-ARCH-TARGET.md` — el spec que dio origen a este documento.
- (Próximamente) `docs/workflow.md` — protocolo de desarrollo.
- (Próximamente) `docs/conventions.md` — convenciones código/commits.
- (Próximamente) `docs/current-state.md` — snapshot rápido del estado.

---

## 🗂️ Documentos pendientes (estado al 2026-07-29)

> **Esta sección es la fuente única de "qué docs faltan".** Si un documento se crea, se quita de aquí. Si se descubre que falta uno nuevo, se agrega.

| Documento | Estado | Quién lo crea | Cuándo se necesita |
|-----------|--------|---------------|---------------------|
| `docs/runbooks/rotate-secrets.md` | Pendiente | Mavis | Cuando se defina el proceso de rotación de secretos (Fase 2). |
| `docs/runbooks/disaster-recovery.md` | Pendiente | Mavis | Antes de Fase 4 (primera vez que se necesite RTO < 4h). |
| `docs/postmortems/` (directorio) | Pendiente | Cuando ocurra el primer P1/P2. | Ver `target-architecture.md §12.1`. |
| `docs/setup.md` | Pendiente | Mavis | Cuando haya un segundo dev o un setup documentado. |
| `docs/current-state.md` | Pendiente | Mavis | Al cerrar la primera HDU de la reescritura. |
| `docs/handoffs/` | Pendiente | Mavis | Al cerrar la primera HDU de la reescritura. |
| `docs/features/<nombre>.md` | Pendiente | Mavis | Al cerrar la primera feature del MVP. |
| `docs/templates/` | **Creado** | Mavis | Existe `hdu-explore.md`. Plantilla para HDUs de research. |
| `codemagic.yaml` | Pendiente | Mavis | Al configurar CI/CD (Fase 1). |
| `supabase/migrations/` (primera migración) | Pendiente | Mavis | Al implementar la primera HDU con cambio de schema. |
| `feature_sync_test.dart` | Pendiente | Mavis | Al implementar el sistema de feature flags. |
| **Doc auto-generada de feature flags** | Aspiración | Mavis | Al implementar el sistema de feature flags. |
| **Threat model (STRIDE)** | Pendiente | Mavis | Fase 2/3 (cuando se implemente el manejo de eFirma). |
| **Plan de test de integración con Supabase** | Pendiente | Mavis | Antes de la primera feature de Fiscal (descarga SAT). |
| **Plan de release con usuarios** | Pendiente | Mavis | Cuando llegue el primer usuario. |

**Cómo se usa esta lista:**

- Al inicio de cada cleanup de HDU, Mavis revisa si algún documento de la lista ya se creó. Si sí, se quita de aquí y se menciona en el spec de la HDU correspondiente.
- Si Mavis descubre un documento nuevo que falta, lo agrega aquí con `Pendiente`.

---

## 🛠️ Cómo se mantiene este documento

- **Cuándo se actualiza:** cada vez que cambia una decisión arquitectónica (nuevo ADR, nueva restricción, nueva fase completada).
- **Quién lo actualiza:** Mavis (orquestador) con aprobación de Hugo.
- **Formato de cambio:** commit con prefijo `docs(arch):`.
- **Regla:** si una sección entra en conflicto con el código, **se corrige el código**, no este documento.

---

*La arquitectura soporta las features, no las dicta. Si encuentras una sección que dice "el feature X hace Y", es un bug del documento.*
