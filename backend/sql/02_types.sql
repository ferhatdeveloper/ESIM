CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS app_private;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role' AND typnamespace = 'app'::regnamespace) THEN
    CREATE TYPE app.user_role AS ENUM ('customer', 'admin');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'currency_code' AND typnamespace = 'app'::regnamespace) THEN
    CREATE TYPE app.currency_code AS ENUM ('USD', 'EUR', 'TRY', 'IQD');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'balance_unit' AND typnamespace = 'app'::regnamespace) THEN
    CREATE TYPE app.balance_unit AS ENUM ('MB');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'esim_status' AND typnamespace = 'app'::regnamespace) THEN
    CREATE TYPE app.esim_status AS ENUM (
      'pending', 'provisioning', 'ready', 'active', 'depleted', 'expired', 'cancelled', 'failed'
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status' AND typnamespace = 'app'::regnamespace) THEN
    CREATE TYPE app.order_status AS ENUM (
      'pending_payment', 'paid', 'provisioning', 'completed', 'failed', 'cancelled', 'refunded'
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status' AND typnamespace = 'app'::regnamespace) THEN
    CREATE TYPE app.payment_status AS ENUM (
      'pending', 'authorized', 'captured', 'failed', 'refunded', 'cancelled'
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_provider' AND typnamespace = 'app'::regnamespace) THEN
    CREATE TYPE app.payment_provider AS ENUM ('mock');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_type' AND typnamespace = 'app'::regnamespace) THEN
    CREATE TYPE app.notification_type AS ENUM (
      'purchase_successful',
      'esim_ready',
      'esim_activated',
      'low_balance',
      'esim_expiring',
      'payment_failed',
      'provisioning_failed'
    );
  END IF;
END
$$;

DROP TYPE IF EXISTS public.auth_session CASCADE;
CREATE TYPE public.auth_session AS (
  access_token text,
  refresh_token text,
  token_type text,
  expires_in integer,
  user_id uuid,
  email text,
  full_name text,
  locale text,
  preferred_currency text,
  app_role text
);

DROP TYPE IF EXISTS public.checkout_quote CASCADE;
CREATE TYPE public.checkout_quote AS (
  order_id uuid,
  plan_id uuid,
  destination text,
  plan_name text,
  data_amount_mb integer,
  validity_days integer,
  currency text,
  subtotal numeric,
  tax numeric,
  fees numeric,
  total numeric,
  payment_mode text
);

DROP TYPE IF EXISTS public.purchase_result CASCADE;
CREATE TYPE public.purchase_result AS (
  order_id uuid,
  order_status text,
  payment_status text,
  esim_id uuid,
  esim_status text,
  is_mock_provisioning boolean,
  message text
);
