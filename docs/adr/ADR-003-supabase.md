# ADR-003: Supabase como backend

**Estado:** Aceptado
**Fecha:** 2026-07-29

## Contexto

Zeiki necesita autenticación, base de datos relacional, almacenamiento de archivos (XMLs CFDI, eFirma) y funciones serverless para lógica async (descarga SAT, timbrado). El equipo es chico y debe minimizar la superficie operacional.

## Decisión

**Supabase** para todo el backend:

- **Auth** (email, OAuth Google, magic link).
- **Postgres** para datos relacionales.
- **Storage** para XMLs, eFirma, avatares.
- **Edge Functions** (Deno) para lógica serverless (ver ADR-007).
- **Realtime** (cuando se necesite, ej. estado de descarga SAT en vivo).

## Por qué

- **Postgres gestionado + Auth incluido + Edge Functions:** reduce infra a operar. Una sola plataforma, una sola factura, una sola consola.
- **Postgres estándar:** no es un dialecto propietario. Si hay que migrar, las queries son portables.
- **Row Level Security (RLS):** políticas de seguridad declarativas a nivel de fila, no en código de aplicación.
- **Edge Functions con Deno:** TypeScript estándar, deploy simple, sin servidor que mantener.

## Alternativas consideradas

- **AWS (RDS + Cognito + Lambda + S3):** más control, mucho más operacional. Equipo de 1 persona no lo sostiene.
- **Firebase (Firestore + Auth + Functions):** NoSQL en el core. Zeiki necesita queries relacionales complejas (cruces entre CFDI, clientes, períodos). Firestore es limitante ahí.
- **Backend custom en Node/Python:** más control, más responsabilidad operativa, más superficie de bug.
- **Postgres + Auth0 + Vercel:** combinación viable, pero suma 3 vendors y 3 consolas.

## Trade-offs

- **A favor:** menos infra que mantener, RLS, Postgres estándar.
- **En contra:** vendor lock-in (mitigado por Postgres estándar). Tope de 150s en Edge Functions (mitigado con async pattern + crons). Costos escalan con el plan.

## Cuándo se revisa

- Los costos escalan de forma no lineal con el crecimiento de usuarios.
- Se necesita infra on-premise (regulación, cliente enterprise, etc.).
- Algún componente crítico de Supabase se vuelve inestable o se discontinúa.
