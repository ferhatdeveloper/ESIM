CREATE TABLE app.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email citext NOT NULL UNIQUE,
  password_hash text NOT NULL,
  full_name text NOT NULL CHECK (char_length(full_name) BETWEEN 1 AND 120),
  phone text,
  locale text NOT NULL DEFAULT 'en' CHECK (locale IN ('en', 'tr', 'ar')),
  preferred_currency app.currency_code NOT NULL DEFAULT 'USD',
  app_role app.user_role NOT NULL DEFAULT 'customer',
  email_verified boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE app.refresh_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.password_reset_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.countries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  iso2 char(2) NOT NULL UNIQUE,
  iso3 char(3) NOT NULL UNIQUE,
  name_en text NOT NULL,
  name_tr text NOT NULL,
  name_ar text NOT NULL,
  flag_emoji text NOT NULL,
  is_popular boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.regions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name_en text NOT NULL,
  name_tr text NOT NULL,
  name_ar text NOT NULL,
  is_popular boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.country_regions (
  country_id uuid NOT NULL REFERENCES app.countries(id) ON DELETE CASCADE,
  region_id uuid NOT NULL REFERENCES app.regions(id) ON DELETE CASCADE,
  PRIMARY KEY (country_id, region_id)
);

CREATE TABLE app.esim_providers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  is_mock boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app_private.provider_secrets (
  provider_id uuid PRIMARY KEY REFERENCES app.esim_providers(id) ON DELETE CASCADE,
  api_key_encrypted text,
  api_secret_encrypted text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.esim_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  country_id uuid REFERENCES app.countries(id),
  region_id uuid REFERENCES app.regions(id),
  provider_id uuid NOT NULL REFERENCES app.esim_providers(id),
  provider_product_id text NOT NULL,
  name_en text NOT NULL,
  name_tr text NOT NULL,
  name_ar text NOT NULL,
  data_amount_mb integer NOT NULL CHECK (data_amount_mb > 0),
  validity_days integer NOT NULL CHECK (validity_days > 0),
  is_active boolean NOT NULL DEFAULT true,
  is_featured boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (country_id IS NOT NULL OR region_id IS NOT NULL),
  UNIQUE (provider_id, provider_product_id)
);

CREATE TABLE app.plan_prices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES app.esim_plans(id) ON DELETE CASCADE,
  currency app.currency_code NOT NULL,
  amount numeric(12, 2) NOT NULL CHECK (amount > 0),
  UNIQUE (plan_id, currency)
);

CREATE TABLE app.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app.users(id),
  status app.order_status NOT NULL DEFAULT 'pending_payment',
  currency app.currency_code NOT NULL,
  subtotal numeric(12, 2) NOT NULL CHECK (subtotal >= 0),
  tax numeric(12, 2) NOT NULL DEFAULT 0 CHECK (tax >= 0),
  fees numeric(12, 2) NOT NULL DEFAULT 0 CHECK (fees >= 0),
  total numeric(12, 2) NOT NULL CHECK (total >= 0),
  idempotency_key text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key)
);

CREATE TABLE app.order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL UNIQUE REFERENCES app.orders(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES app.esim_plans(id),
  quantity integer NOT NULL DEFAULT 1 CHECK (quantity = 1),
  unit_price numeric(12, 2) NOT NULL CHECK (unit_price >= 0),
  currency app.currency_code NOT NULL
);

CREATE TABLE app.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL UNIQUE REFERENCES app.orders(id) ON DELETE CASCADE,
  provider app.payment_provider NOT NULL DEFAULT 'mock',
  status app.payment_status NOT NULL DEFAULT 'pending',
  amount numeric(12, 2) NOT NULL CHECK (amount >= 0),
  currency app.currency_code NOT NULL,
  provider_payment_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.payment_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id uuid NOT NULL REFERENCES app.payments(id) ON DELETE CASCADE,
  txn_type text NOT NULL,
  status text NOT NULL,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.user_esims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app.users(id),
  order_id uuid NOT NULL UNIQUE REFERENCES app.orders(id),
  plan_id uuid NOT NULL REFERENCES app.esim_plans(id),
  provider_id uuid NOT NULL REFERENCES app.esim_providers(id),
  iccid text UNIQUE,
  smdp_address text,
  activation_code text,
  confirmation_code text,
  original_balance numeric(12, 2) NOT NULL CHECK (original_balance >= 0),
  remaining_balance numeric(12, 2) NOT NULL CHECK (remaining_balance >= 0),
  balance_unit app.balance_unit NOT NULL DEFAULT 'MB',
  status app.esim_status NOT NULL DEFAULT 'pending',
  activated_at timestamptz,
  expires_at timestamptz,
  is_mock boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (remaining_balance <= original_balance)
);

CREATE TABLE app.esim_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  esim_id uuid NOT NULL REFERENCES app.user_esims(id) ON DELETE CASCADE,
  usage_amount numeric(12, 2) NOT NULL CHECK (usage_amount > 0),
  balance_before numeric(12, 2) NOT NULL,
  balance_after numeric(12, 2) NOT NULL,
  source text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  type app.notification_type NOT NULL,
  title_en text NOT NULL,
  title_tr text NOT NULL,
  title_ar text NOT NULL,
  body_en text NOT NULL,
  body_tr text NOT NULL,
  body_ar text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.app_settings (
  key text PRIMARY KEY,
  value text NOT NULL,
  is_public boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app_private.config (
  key text PRIMARY KEY,
  value text NOT NULL
);

CREATE INDEX idx_refresh_tokens_user ON app.refresh_tokens (user_id);
CREATE INDEX idx_orders_user_created ON app.orders (user_id, created_at DESC);
CREATE INDEX idx_user_esims_user_status ON app.user_esims (user_id, status);
CREATE INDEX idx_esim_usage_esim_created ON app.esim_usage (esim_id, created_at DESC);
CREATE INDEX idx_notifications_user_created ON app.notifications (user_id, created_at DESC);
CREATE INDEX idx_plans_country_active ON app.esim_plans (country_id, is_active);
CREATE INDEX idx_plans_region_active ON app.esim_plans (region_id, is_active);
CREATE INDEX idx_countries_popular ON app.countries (is_popular, sort_order) WHERE is_active;
