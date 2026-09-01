-- JWT helpers (PostgREST cookbook / pgcrypto). Secrets never leave app_private.

CREATE OR REPLACE FUNCTION app_private.url_encode(data bytea)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT translate(encode(data, 'base64'), E'+/=\n', '-_');
$$;

CREATE OR REPLACE FUNCTION app_private.algorithm_sign(signables text, secret text, algorithm text)
RETURNS bytea
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN algorithm = 'HS256' THEN hmac(signables, secret, 'sha256')
    WHEN algorithm = 'HS384' THEN hmac(signables, secret, 'sha384')
    WHEN algorithm = 'HS512' THEN hmac(signables, secret, 'sha512')
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION app_private.sign(payload json, secret text, algorithm text DEFAULT 'HS256')
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  WITH header AS (
    SELECT app_private.url_encode(convert_to('{"alg":"' || algorithm || '","typ":"JWT"}', 'utf8')) AS data
  ),
  payload_enc AS (
    SELECT app_private.url_encode(convert_to(payload::text, 'utf8')) AS data
  ),
  signables AS (
    SELECT header.data || '.' || payload_enc.data AS data FROM header, payload_enc
  )
  SELECT signables.data || '.' ||
         app_private.url_encode(app_private.algorithm_sign(signables.data, secret, algorithm))
  FROM signables;
$$;

CREATE OR REPLACE FUNCTION app_private.jwt_secret()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT value FROM app_private.config WHERE key = 'jwt_secret';
$$;

CREATE OR REPLACE FUNCTION app_private.jwt_audience()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT value FROM app_private.config WHERE key = 'jwt_audience';
$$;

CREATE OR REPLACE FUNCTION app.current_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('request.jwt.claims', true)::json ->> 'sub', '')::uuid;
$$;

CREATE OR REPLACE FUNCTION app.current_app_role()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(current_setting('request.jwt.claims', true)::json ->> 'app_role', '');
$$;

CREATE OR REPLACE FUNCTION app_private.require_user_id()
RETURNS uuid
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  uid uuid;
BEGIN
  uid := app.current_user_id();
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  RETURN uid;
END;
$$;

CREATE OR REPLACE FUNCTION app.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_updated BEFORE UPDATE ON app.users
  FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();
CREATE TRIGGER trg_countries_updated BEFORE UPDATE ON app.countries
  FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();
CREATE TRIGGER trg_regions_updated BEFORE UPDATE ON app.regions
  FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();
CREATE TRIGGER trg_providers_updated BEFORE UPDATE ON app.esim_providers
  FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();
CREATE TRIGGER trg_plans_updated BEFORE UPDATE ON app.esim_plans
  FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();
CREATE TRIGGER trg_orders_updated BEFORE UPDATE ON app.orders
  FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();
CREATE TRIGGER trg_payments_updated BEFORE UPDATE ON app.payments
  FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();
CREATE TRIGGER trg_user_esims_updated BEFORE UPDATE ON app.user_esims
  FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();
