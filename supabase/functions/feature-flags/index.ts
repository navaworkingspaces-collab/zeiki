// HDU-002: Edge function `feature-flags` — entry point.
//
// Devuelve los flags activos en formato `{ "flags": { <key>: <bool> } }`.
// Los flags son datos del PRODUCTO, no del usuario, por eso no requiere
// JWT (se deploya con `--no-verify-jwt`).
//
// La lógica vive en `handler.ts` para que los tests de Deno no
// intenten arrancar el `Deno.serve()` al cargar este módulo.

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import { handleFeatureFlags } from "./handler.ts";

Deno.serve(async () => {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !serviceRoleKey) {
    return new Response(
      JSON.stringify({
        error:
          "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in function env",
      }),
      {
        status: 500,
        headers: { "content-type": "application/json" },
      },
    );
  }

  // El service_role bypasea RLS — necesario para que la edge function
  // pueda leer siempre la tabla, independientemente del cliente que
  // invoque. Los flags son datos del producto, no del usuario.
  const client: SupabaseClient = createClient(url, serviceRoleKey);

  try {
    const body = await handleFeatureFlags(client);
    return new Response(JSON.stringify(body), {
      headers: { "content-type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: `feature-flags failed: ${message}` }),
      {
        status: 500,
        headers: { "content-type": "application/json" },
      },
    );
  }
});
