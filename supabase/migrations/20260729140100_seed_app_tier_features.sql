-- HDU-002: Seed inicial de `app_tier_features`.
--
-- Inserta los flags que la app necesita en su MVP. Solo `splash` por
-- ahora — el resto se agrega en HDUs futuras (no scope creep, ver
-- `specs/HDU-002-supabase-setup.md` §Fuera de scope).
--
-- Idempotente: `ON CONFLICT (feature_key, tier) DO NOTHING` permite
-- re-aplicar la migración sin duplicar filas. El `id` se deriva del
-- par (feature_key, tier) con `md5` para que el seed sea 100%
-- determinístico entre ambientes (dev / staging / prod) y el
-- `ON CONFLICT` pueda hacer match incluso si la fila original se
-- borró y se vuelve a insertar.

INSERT INTO public.app_tier_features (id, feature_key, tier, enabled)
VALUES
  -- Splash visible para todos los tiers actuales. Cuando se agregue el
  -- modelo de tiers real (ADR-010 + TierService), esto se ajusta.
  (md5('splash:free')::uuid, 'splash', 'free', true),
  (md5('splash:pro')::uuid,  'splash', 'pro',  true)
ON CONFLICT (feature_key, tier) DO NOTHING;
