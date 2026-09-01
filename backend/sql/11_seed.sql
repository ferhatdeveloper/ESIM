INSERT INTO app_private.config (key, value) VALUES
  ('jwt_secret', 'dev-only-change-me-use-32-plus-chars!!'),
  ('jwt_audience', 'esim-app')
ON CONFLICT (key) DO NOTHING;

INSERT INTO app.app_settings (key, value, is_public) VALUES
  ('environment', 'development', true),
  ('tax_rate', '0.00', true),
  ('fee_rate', '0.00', true),
  ('default_currency', 'USD', true),
  ('supported_currencies', 'USD,EUR,TRY,IQD', true),
  ('supported_locales', 'en,tr,ar', true),
  ('low_balance_ratio', '0.15', false),
  ('payment_provider', 'mock', true),
  ('esim_provider', 'mock', true)
ON CONFLICT (key) DO NOTHING;

INSERT INTO app.esim_providers (id, code, name, is_mock, is_active)
VALUES ('11111111-1111-1111-1111-111111111111', 'mock', 'Mock eSIM Provider', true, true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO app.countries (iso2, iso3, name_en, name_tr, name_ar, flag_emoji, is_popular, sort_order) VALUES
  ('TR', 'TUR', 'Turkey', 'Türkiye', 'تركيا', '🇹🇷', true, 10),
  ('AE', 'ARE', 'United Arab Emirates', 'Birleşik Arap Emirlikleri', 'الإمارات', '🇦🇪', true, 20),
  ('IQ', 'IRQ', 'Iraq', 'Irak', 'العراق', '🇮🇶', true, 30),
  ('SA', 'SAU', 'Saudi Arabia', 'Suudi Arabistan', 'السعودية', '🇸🇦', true, 40),
  ('US', 'USA', 'United States', 'Amerika Birleşik Devletleri', 'الولايات المتحدة', '🇺🇸', true, 50),
  ('GB', 'GBR', 'United Kingdom', 'Birleşik Krallık', 'المملكة المتحدة', '🇬🇧', true, 60),
  ('DE', 'DEU', 'Germany', 'Almanya', 'ألمانيا', '🇩🇪', true, 70),
  ('FR', 'FRA', 'France', 'Fransa', 'فرنسا', '🇫🇷', true, 80),
  ('IT', 'ITA', 'Italy', 'İtalya', 'إيطاليا', '🇮🇹', true, 90),
  ('ES', 'ESP', 'Spain', 'İspanya', 'إسبانيا', '🇪🇸', false, 100),
  ('JP', 'JPN', 'Japan', 'Japonya', 'اليابان', '🇯🇵', true, 110),
  ('TH', 'THA', 'Thailand', 'Tayland', 'تايلاند', '🇹🇭', false, 120)
ON CONFLICT (iso2) DO NOTHING;

INSERT INTO app.regions (slug, name_en, name_tr, name_ar, is_popular, sort_order) VALUES
  ('europe', 'Europe', 'Avrupa', 'أوروبا', true, 10),
  ('middle-east', 'Middle East', 'Orta Doğu', 'الشرق الأوسط', true, 20),
  ('asia', 'Asia', 'Asya', 'آسيا', true, 30),
  ('global', 'Global', 'Küresel', 'عالمي', false, 40)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO app.country_regions (country_id, region_id)
SELECT c.id, r.id
FROM app.countries c
JOIN app.regions r ON
  (r.slug = 'europe' AND c.iso2 IN ('GB', 'DE', 'FR', 'IT', 'ES'))
  OR (r.slug = 'middle-east' AND c.iso2 IN ('AE', 'IQ', 'SA', 'TR'))
  OR (r.slug = 'asia' AND c.iso2 IN ('JP', 'TH', 'TR'))
ON CONFLICT DO NOTHING;

DO $$
DECLARE
  mock_id uuid := '11111111-1111-1111-1111-111111111111';
  rec RECORD;
  plan_id uuid;
  amounts int[];
  days int[];
  usd numeric[];
  i int;
BEGIN
  amounts := ARRAY[1024, 3072, 10240];
  days := ARRAY[7, 15, 30];
  usd := ARRAY[4.90, 9.90, 19.90];

  FOR rec IN SELECT * FROM app.countries LOOP
    FOR i IN 1..3 LOOP
      plan_id := NULL;
      INSERT INTO app.esim_plans (
        country_id, provider_id, provider_product_id,
        name_en, name_tr, name_ar,
        data_amount_mb, validity_days, is_featured, sort_order
      ) VALUES (
        rec.id, mock_id, rec.iso2 || '-' || amounts[i] || '-' || days[i],
        rec.name_en || ' – ' || (amounts[i] / 1024) || ' GB – ' || days[i] || ' Days',
        rec.name_tr || ' – ' || (amounts[i] / 1024) || ' GB – ' || days[i] || ' Gün',
        rec.name_ar || ' – ' || (amounts[i] / 1024) || ' غيغابايت – ' || days[i] || ' يوم',
        amounts[i], days[i], i = 3 AND rec.is_popular, i * 10
      )
      ON CONFLICT (provider_id, provider_product_id) DO NOTHING
      RETURNING id INTO plan_id;

      IF plan_id IS NULL THEN
        SELECT id INTO plan_id FROM app.esim_plans
        WHERE provider_id = mock_id AND provider_product_id = rec.iso2 || '-' || amounts[i] || '-' || days[i];
      END IF;

      INSERT INTO app.plan_prices (plan_id, currency, amount) VALUES
        (plan_id, 'USD', usd[i]),
        (plan_id, 'EUR', round(usd[i] * 0.92, 2)),
        (plan_id, 'TRY', round(usd[i] * 34, 2)),
        (plan_id, 'IQD', round(usd[i] * 1310, 0))
      ON CONFLICT (plan_id, currency) DO NOTHING;
    END LOOP;
  END LOOP;

  INSERT INTO app.esim_plans (
    region_id, provider_id, provider_product_id,
    name_en, name_tr, name_ar, data_amount_mb, validity_days, is_featured, sort_order
  )
  SELECT r.id, mock_id, upper(r.slug) || '-10240-30',
         r.name_en || ' – 10 GB – 30 Days',
         r.name_tr || ' – 10 GB – 30 Gün',
         r.name_ar || ' – 10 غيغابايت – 30 يوم',
         10240, 30, true, 5
  FROM app.regions r
  ON CONFLICT (provider_id, provider_product_id) DO NOTHING;

  INSERT INTO app.plan_prices (plan_id, currency, amount)
  SELECT p.id, c.currency, c.amount
  FROM app.esim_plans p
  CROSS JOIN (VALUES
    ('USD'::app.currency_code, 29.90),
    ('EUR'::app.currency_code, 27.50),
    ('TRY'::app.currency_code, 1015.00),
    ('IQD'::app.currency_code, 39170.00)
  ) AS c(currency, amount)
  WHERE p.region_id IS NOT NULL
  ON CONFLICT (plan_id, currency) DO NOTHING;
END
$$;

INSERT INTO app.users (id, email, password_hash, full_name, locale, preferred_currency, app_role, email_verified)
VALUES
  (
    '22222222-2222-2222-2222-222222222222',
    'demo@esim.app',
    crypt('Demo12345!', gen_salt('bf', 10)),
    'Demo Traveler',
    'en',
    'USD',
    'customer',
    true
  ),
  (
    '33333333-3333-3333-3333-333333333333',
    'admin@esim.app',
    crypt('Admin12345!', gen_salt('bf', 10)),
    'Platform Admin',
    'en',
    'USD',
    'admin',
    true
  )
ON CONFLICT (email) DO NOTHING;
