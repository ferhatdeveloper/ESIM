CREATE OR REPLACE VIEW public.countries AS
SELECT id, iso2, iso3, name_en, name_tr, name_ar, flag_emoji, is_popular, sort_order
FROM app.countries
WHERE is_active;

CREATE OR REPLACE VIEW public.regions AS
SELECT id, slug, name_en, name_tr, name_ar, is_popular, sort_order
FROM app.regions
WHERE is_active;

CREATE OR REPLACE VIEW public.country_regions AS
SELECT cr.country_id, cr.region_id
FROM app.country_regions cr
JOIN app.countries c ON c.id = cr.country_id AND c.is_active
JOIN app.regions r ON r.id = cr.region_id AND r.is_active;

CREATE OR REPLACE VIEW public.marketplace_plans AS
SELECT
  p.id,
  p.country_id,
  p.region_id,
  c.iso2 AS country_iso2,
  c.name_en AS country_name_en,
  c.name_tr AS country_name_tr,
  c.name_ar AS country_name_ar,
  c.flag_emoji,
  r.slug AS region_slug,
  r.name_en AS region_name_en,
  r.name_tr AS region_name_tr,
  r.name_ar AS region_name_ar,
  p.name_en,
  p.name_tr,
  p.name_ar,
  p.data_amount_mb,
  p.validity_days,
  p.is_featured,
  p.sort_order,
  COALESCE(
    (
      SELECT jsonb_agg(jsonb_build_object('currency', pp.currency, 'amount', pp.amount) ORDER BY pp.currency)
      FROM app.plan_prices pp
      WHERE pp.plan_id = p.id
    ),
    '[]'::jsonb
  ) AS prices
FROM app.esim_plans p
LEFT JOIN app.countries c ON c.id = p.country_id
LEFT JOIN app.regions r ON r.id = p.region_id
WHERE p.is_active;

CREATE OR REPLACE VIEW public.me AS
SELECT
  u.id,
  u.email,
  u.full_name,
  u.phone,
  u.locale,
  u.preferred_currency,
  u.app_role,
  u.created_at
FROM app.users u
WHERE u.id = app.current_user_id()
  AND u.deleted_at IS NULL;

CREATE OR REPLACE VIEW public.my_orders AS
SELECT
  o.id,
  o.status,
  o.currency,
  o.subtotal,
  o.tax,
  o.fees,
  o.total,
  o.created_at,
  i.plan_id,
  p.name_en AS plan_name_en,
  p.name_tr AS plan_name_tr,
  p.name_ar AS plan_name_ar,
  p.data_amount_mb,
  p.validity_days,
  c.name_en AS destination_en,
  c.name_tr AS destination_tr,
  c.name_ar AS destination_ar,
  c.flag_emoji,
  pay.status AS payment_status,
  pay.provider AS payment_provider,
  e.id AS esim_id,
  e.status AS esim_status
FROM app.orders o
JOIN app.order_items i ON i.order_id = o.id
JOIN app.esim_plans p ON p.id = i.plan_id
LEFT JOIN app.countries c ON c.id = p.country_id
LEFT JOIN app.payments pay ON pay.order_id = o.id
LEFT JOIN app.user_esims e ON e.order_id = o.id
WHERE o.user_id = app.current_user_id();

CREATE OR REPLACE VIEW public.my_esims AS
SELECT
  e.id,
  e.order_id,
  e.plan_id,
  e.status,
  e.original_balance,
  e.remaining_balance,
  e.balance_unit,
  e.activated_at,
  e.expires_at,
  e.is_mock,
  e.created_at,
  p.data_amount_mb,
  p.validity_days,
  p.name_en AS plan_name_en,
  p.name_tr AS plan_name_tr,
  p.name_ar AS plan_name_ar,
  COALESCE(c.name_en, r.name_en) AS destination_en,
  COALESCE(c.name_tr, r.name_tr) AS destination_tr,
  COALESCE(c.name_ar, r.name_ar) AS destination_ar,
  c.flag_emoji,
  c.iso2 AS country_iso2,
  CASE
    WHEN e.status IN ('ready', 'active') THEN e.iccid
    ELSE NULL
  END AS iccid,
  CASE
    WHEN e.status IN ('ready', 'active') THEN e.smdp_address
    ELSE NULL
  END AS smdp_address,
  CASE
    WHEN e.status IN ('ready', 'active') THEN e.activation_code
    ELSE NULL
  END AS activation_code,
  CASE
    WHEN e.status IN ('ready', 'active') THEN e.confirmation_code
    ELSE NULL
  END AS confirmation_code
FROM app.user_esims e
JOIN app.esim_plans p ON p.id = e.plan_id
LEFT JOIN app.countries c ON c.id = p.country_id
LEFT JOIN app.regions r ON r.id = p.region_id
WHERE e.user_id = app.current_user_id();

CREATE OR REPLACE VIEW public.my_esim_usage AS
SELECT u.id, u.esim_id, u.usage_amount, u.balance_before, u.balance_after, u.source, u.created_at
FROM app.esim_usage u
JOIN app.user_esims e ON e.id = u.esim_id
WHERE e.user_id = app.current_user_id();

CREATE OR REPLACE VIEW public.my_notifications AS
SELECT
  n.id,
  n.type,
  n.title_en,
  n.title_tr,
  n.title_ar,
  n.body_en,
  n.body_tr,
  n.body_ar,
  n.payload,
  n.is_read,
  n.created_at
FROM app.notifications n
WHERE n.user_id = app.current_user_id();

CREATE OR REPLACE VIEW public.public_settings AS
SELECT key, value
FROM app.app_settings
WHERE is_public;
