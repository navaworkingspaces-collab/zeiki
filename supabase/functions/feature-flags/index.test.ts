// HDU-002: Test de la edge function `feature-flags`.
//
// Mockeamos el cliente de Supabase con un stub mínimo: solo necesita
// devolver `data` con la forma esperada por `handleFeatureFlags`. No se
// usa `mockito` ni nada externo — siguiendo conventions §3, un stub es
// suficiente cuando solo necesitamos "que la dependencia devuelva algo".
//
// Importa desde `handler.ts` (no `index.ts`) para que el test no
// cargue el `Deno.serve(...)` que abre un puerto real.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  handleFeatureFlags,
  type FeatureFlagsClient,
  type TierFeatureRow,
} from "./handler.ts";

function makeStubClient(rows: TierFeatureRow[]): FeatureFlagsClient {
  return {
    from: (_table) => ({
      select: async (_cols) => ({ data: rows, error: null }),
    }),
  };
}

Deno.test(
  "handleFeatureFlags returns one entry per feature_key with true value",
  async () => {
    const client = makeStubClient([
      { feature_key: "splash", enabled: true },
      { feature_key: "splash", enabled: true },
    ]);
    const result = await handleFeatureFlags(client);
    assertEquals(result, { flags: { splash: true } });
  },
);

Deno.test(
  "handleFeatureFlags returns false when all rows for a feature are disabled",
  async () => {
    const client = makeStubClient([
      { feature_key: "splash", enabled: false },
    ]);
    const result = await handleFeatureFlags(client);
    assertEquals(result, { flags: { splash: false } });
  },
);

Deno.test(
  "handleFeatureFlags returns true if at least one row per feature is enabled",
  async () => {
    const client = makeStubClient([
      { feature_key: "splash", enabled: false },
      { feature_key: "splash", enabled: true },
    ]);
    const result = await handleFeatureFlags(client);
    assertEquals(result, { flags: { splash: true } });
  },
);

Deno.test(
  "handleFeatureFlags aggregates multiple distinct feature_keys",
  async () => {
    const client = makeStubClient([
      { feature_key: "splash", enabled: true },
      { feature_key: "exportar_reportes", enabled: false },
    ]);
    const result = await handleFeatureFlags(client);
    assertEquals(result, {
      flags: { splash: true, exportar_reportes: false },
    });
  },
);

Deno.test(
  "handleFeatureFlags returns empty flags when the table has no rows",
  async () => {
    const client = makeStubClient([]);
    const result = await handleFeatureFlags(client);
    assertEquals(result, { flags: {} });
  },
);

Deno.test(
  "handleFeatureFlags throws when the client returns an error",
  async () => {
    const client: FeatureFlagsClient = {
      from: (_table) => ({
        select: async (_cols) => ({
          data: null,
          error: { message: "connection refused" },
        }),
      }),
    };
    let thrown: Error | null = null;
    try {
      await handleFeatureFlags(client);
    } catch (e) {
      thrown = e as Error;
    }
    if (thrown === null) {
      throw new Error("expected handleFeatureFlags to throw");
    }
    assertEquals(
      thrown.message,
      "Failed to read feature flags: connection refused",
    );
  },
);
