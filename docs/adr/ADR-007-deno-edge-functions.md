# ADR-007: Deno + TypeScript para Edge Functions

**Estado:** Aceptado
**Fecha:** 2026-07-29

## Contexto

Zeiki necesita ejecutar lógica server-side sin servidor dedicado: descarga masiva de CFDIs del SAT (jobs async que pueden tardar minutos), validación de eFirma antes de subirla, integraciones con Facturama para timbrado, webhooks de OAuth para Google.

## Decisión

**Deno** (runtime) + **TypeScript** (lenguaje) para todas las Edge Functions de Supabase.

- **Direct URL imports** para Deno 2.x (no `import_map.json` separado — no auto-load).
- **`@ts-nocheck`** con comentario explicativo (mismo patrón que la función de descarga SAT).
- **Validación de inputs** al inicio de cada función.
- **Logs estructurados** con prefijos (`[sat-auto-download]`, `[auth-google-proxy]`).
- **Secretos** vía `Deno.env.get()`.
- **Errores** con códigos HTTP apropiados.
- **Tests smoke** con `deno test` (al menos verifica que las funciones clave estén presentes).

## Por qué

- **TypeScript:** mismo lenguaje conceptual que Dart, tipado fuerte, ecosistema maduro.
- **Deno:** runtime simple, sin `node_modules`, sin package manager separado, permisos explícitos por ejecución.
- **Edge de Supabase:** deploy con un comando, escala automático, integrado con el resto del backend.
- **Sin servidor dedicado:** no hay VM que mantener, no hay SO que parchar.

## Alternativas consideradas

- **Node.js + TypeScript:** viable, pero Deno es más simple (sin `package.json` ni `node_modules`).
- **Python:** viable, pero el ecosistema TypeScript es más maduro para integraciones HTTP/XML.
- **Dart en el servidor:** posible (con `dart:io`), pero el ecosistema de paquetes para SAT/Facturama es más débil.
- **Lambda / Cloud Functions:** más control, más operacional, no justificado para el tamaño actual.

## Trade-offs

- **A favor:** simple, sin infra, TypeScript estándar.
- **En contra:** **tope de 150 segundos por invocación** en Supabase Edge Functions. Esto es una restricción real que ya nos pegó (HDU-MANUAL-005). El patrón de mitigación es async + checkpoints + crons subsiguientes. NO se cambia la decisión; se adapta el patrón de uso.

## Cuándo se revisa

- Se necesita workers con tiempo ilimitado (jobs que tardan horas). Ahí se migra a un servicio dedicado (Fase 4 o 5 de la Target Architecture).
- Supabase discontinúa Edge Functions o sube los topes de forma incompatible.
- La complejidad de las funciones crece al punto de necesitar orquestación (Event Bus, que está diferido).

## Convenciones (referencia: `docs/conventions.md` y `docs/git.md §6`)

- Tests con `deno test --allow-read --allow-env` (flags obligatorios documentados en HDU-037).
- TypeScript estricto, sin `any` salvo justificación.
- Validación de inputs con Zod o equivalente.
- Errores tipados (no strings sueltos).
