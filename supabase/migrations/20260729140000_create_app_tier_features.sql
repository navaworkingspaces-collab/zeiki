-- HDU-002: Schema de la tabla `app_tier_features` + RLS.
--
-- Esta tabla guarda la configuración de feature flags por tier (plan) del
-- producto. Es la fuente de verdad del backend para lo que el cliente ve
-- como `TierService.has(AppFeature.x)`. Los flags son datos del PRODUCTO
-- (no del usuario), por eso `anon` y `authenticated` pueden leerlos.
-- Solo `service_role` puede escribir (cambios de flags los hace un
-- operador o un job de Supabase, no el cliente).
--
-- Idempotente: `IF NOT EXISTS` en CREATE, `DROP POLICY IF EXISTS` antes
-- de crear. Re-aplicable sin errores (conventions §12).

-- ===== Tabla =====
CREATE TABLE IF NOT EXISTS public.app_tier_features (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_key text        NOT NULL,
  tier        text        NOT NULL,
  enabled     boolean     NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT app_tier_features_feature_key_tier_key UNIQUE (feature_key, tier)
);

-- ===== Índices =====
-- El cliente suele consultar por `feature_key` (para resolver un flag
-- concreto del enum AppFeature) y por `(feature_key, tier)` (cuando hay
-- tiers distintos por usuario; hoy todos leen el mismo, pero el índice
-- cubre la consulta típica y la constraint UNIQUE).
CREATE INDEX IF NOT EXISTS app_tier_features_feature_key_idx
  ON public.app_tier_features (feature_key);

-- updated_at se actualiza en cada UPDATE. Trigger dedicado para no
-- obligar al cliente a recordar setearlo.
CREATE OR REPLACE FUNCTION public.app_tier_features_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS app_tier_features_updated_at ON public.app_tier_features;
CREATE TRIGGER app_tier_features_updated_at
  BEFORE UPDATE ON public.app_tier_features
  FOR EACH ROW
  EXECUTE FUNCTION public.app_tier_features_set_updated_at();

-- ===== RLS =====
-- Habilitar RLS. Sin políticas, nadie puede leer ni escribir — es el
-- default seguro de Postgres cuando RLS está activo.
ALTER TABLE public.app_tier_features ENABLE ROW LEVEL SECURITY;

-- Política de SELECT: cualquier cliente autenticado o anónimo puede
-- leer los flags. Los flags son datos del producto, no del usuario.
DROP POLICY IF EXISTS app_tier_features_select_anon_authenticated ON public.app_tier_features;
CREATE POLICY app_tier_features_select_anon_authenticated
  ON public.app_tier_features
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Política de ALL (INSERT/UPDATE/DELETE): solo el service_role puede
-- modificar. El cliente jamás escribe acá; los cambios los hace un
-- operador desde el panel o un job de Supabase.
DROP POLICY IF EXISTS app_tier_features_all_service_role ON public.app_tier_features;
CREATE POLICY app_tier_features_all_service_role
  ON public.app_tier_features
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
