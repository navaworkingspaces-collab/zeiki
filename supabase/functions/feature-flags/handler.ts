// HDU-002: Lógica de la edge function `feature-flags` (sin entry point).
//
// Se separa del `index.ts` para que los tests de Deno puedan importar
// la lógica sin que se intente arrancar `Deno.serve()` al cargar el
// módulo (que requiere `--allow-net`). Es el patrón estándar de
// Supabase Edge Functions: handler en un archivo, entry point en otro.

export interface TierFeatureRow {
  feature_key: string;
  enabled: boolean;
}

export interface FeatureFlagsQueryResult {
  data: TierFeatureRow[] | null;
  error: { message: string } | null;
}

/**
 * `SupabaseClient.from().select()` retorna un `PostgrestFilterBuilder`
 * (thenable, no `Promise` completa — le faltan `catch`/`finally`). La
 * interfaz acepta cualquier `PromiseLike` para que el cliente real
 * (Supabase) y los stubs del test sean intercambiables.
 */
export interface FeatureFlagsClient {
  from(table: "app_tier_features"): {
    select(cols: string): PromiseLike<FeatureFlagsQueryResult>;
  };
}

export interface FeatureFlagsResponse {
  flags: Record<string, boolean>;
}

/**
 * Lee los flags desde la tabla y los agrega a un mapa por `feature_key`.
 *
 * Lógica de agregación: si el mismo `feature_key` aparece en varios
 * tiers, el flag es `true` si AL MENOS un tier lo tiene habilitado. En
 * MVP solo hay un tier efectivo por cliente; cuando el modelo de tiers
 * real (ADR-010 + TierService) exista, el cliente refina la respuesta
 * filtrando por su tier.
 */
export async function handleFeatureFlags(
  client: FeatureFlagsClient,
): Promise<FeatureFlagsResponse> {
  const { data, error } = await client
    .from("app_tier_features")
    .select("feature_key, enabled");

  if (error) {
    throw new Error(`Failed to read feature flags: ${error.message}`);
  }

  const flags: Record<string, boolean> = {};
  for (const row of data ?? []) {
    // Si el flag ya existía, conserva `true` si alguna fila lo era
    // (lógica OR sobre todos los tiers).
    flags[row.feature_key] = Boolean(flags[row.feature_key]) || row.enabled;
  }

  return { flags };
}
