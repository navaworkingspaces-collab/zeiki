-- HDU-002 (fix): GRANTs de Postgres para app_tier_features.
--
-- Las policies de RLS están bien (anon/authenticated pueden SELECT,
-- service_role puede ALL), pero faltaban los GRANTs a nivel de tabla.
-- Sin GRANT, ni siquiera el role service_role puede acceder, aunque
-- RLS diga que sí. Esto es un issue comun en Supabase cuando se
-- desactiva 'Automatically expose new tables' en el setup.
--
-- Idempotente: GRANT es idempotente en Postgres (no falla si ya existe).

-- ===== GRANTs a nivel de tabla =====
GRANT SELECT ON public.app_tier_features TO anon;
GRANT SELECT ON public.app_tier_features TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_tier_features TO service_role;

-- ===== GRANTs a nivel de schema =====
-- (Para que los roles puedan USAGE del schema 'public' que ya tienen
-- por default en Supabase, pero por si acaso)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
