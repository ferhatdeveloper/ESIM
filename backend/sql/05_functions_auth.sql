CREATE OR REPLACE FUNCTION app_private.hash_password(plain text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT crypt(plain, gen_salt('bf', 10));
$$;

CREATE OR REPLACE FUNCTION app_private.verify_password(plain text, stored_hash text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT stored_hash = crypt(plain, stored_hash);
$$;

CREATE OR REPLACE FUNCTION app_private.notify(
  p_user_id uuid,
  p_type app.notification_type,
  p_title_en text, p_title_tr text, p_title_ar text,
  p_body_en text, p_body_tr text, p_body_ar text,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE sql
AS $$
  INSERT INTO app.notifications (
    user_id, type, title_en, title_tr, title_ar, body_en, body_tr, body_ar, payload
  ) VALUES (
    p_user_id, p_type, p_title_en, p_title_tr, p_title_ar, p_body_en, p_body_tr, p_body_ar, p_payload
  );
$$;

CREATE OR REPLACE FUNCTION app_private.issue_session(p_user app.users)
RETURNS public.auth_session
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, app_private, public
AS $$
DECLARE
  access text;
  refresh_raw text;
  expires_in integer := 900;
  session public.auth_session;
  pg_role text;
BEGIN
  IF p_user.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Account disabled' USING ERRCODE = '28000';
  END IF;

  pg_role := CASE WHEN p_user.app_role = 'admin' THEN 'admin' ELSE 'authenticated' END;

  access := app_private.sign(
    json_build_object(
      'role', pg_role,
      'app_role', p_user.app_role::text,
      'sub', p_user.id::text,
      'email', p_user.email::text,
      'aud', app_private.jwt_audience(),
      'exp', extract(epoch FROM now())::integer + expires_in
    ),
    app_private.jwt_secret()
  );

  refresh_raw := encode(gen_random_bytes(32), 'hex');
  INSERT INTO app.refresh_tokens (user_id, token_hash, expires_at)
  VALUES (p_user.id, encode(digest(refresh_raw, 'sha256'), 'hex'), now() + interval '30 days');

  session.access_token := access;
  session.refresh_token := refresh_raw;
  session.token_type := 'bearer';
  session.expires_in := expires_in;
  session.user_id := p_user.id;
  session.email := p_user.email::text;
  session.full_name := p_user.full_name;
  session.locale := p_user.locale;
  session.preferred_currency := p_user.preferred_currency::text;
  session.app_role := p_user.app_role::text;
  RETURN session;
END;
$$;

CREATE OR REPLACE FUNCTION public.register(
  email text,
  password text,
  full_name text,
  locale text DEFAULT 'en',
  preferred_currency text DEFAULT 'USD'
)
RETURNS public.auth_session
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, app_private, public
AS $$
DECLARE
  new_user app.users;
BEGIN
  IF email IS NULL OR position('@' IN email) = 0 THEN
    RAISE EXCEPTION 'Invalid email' USING ERRCODE = '22023';
  END IF;
  IF password IS NULL OR char_length(password) < 8 THEN
    RAISE EXCEPTION 'Password must be at least 8 characters' USING ERRCODE = '22023';
  END IF;
  IF full_name IS NULL OR btrim(full_name) = '' THEN
    RAISE EXCEPTION 'Name is required' USING ERRCODE = '22023';
  END IF;
  IF locale NOT IN ('en', 'tr', 'ar') THEN
    RAISE EXCEPTION 'Unsupported locale' USING ERRCODE = '22023';
  END IF;
  IF preferred_currency NOT IN ('USD', 'EUR', 'TRY', 'IQD') THEN
    RAISE EXCEPTION 'Unsupported currency' USING ERRCODE = '22023';
  END IF;

  INSERT INTO app.users (email, password_hash, full_name, locale, preferred_currency)
  VALUES (
    lower(btrim(email)),
    app_private.hash_password(password),
    btrim(full_name),
    locale,
    preferred_currency::app.currency_code
  )
  RETURNING * INTO new_user;

  RETURN app_private.issue_session(new_user);
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Email already registered' USING ERRCODE = '23505';
END;
$$;

CREATE OR REPLACE FUNCTION public.login(email text, password text)
RETURNS public.auth_session
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, app_private, public
AS $$
DECLARE
  found app.users;
BEGIN
  SELECT * INTO found
  FROM app.users u
  WHERE u.email = lower(btrim(login.email))
    AND u.deleted_at IS NULL;

  IF found.id IS NULL OR NOT app_private.verify_password(password, found.password_hash) THEN
    RAISE EXCEPTION 'Invalid credentials' USING ERRCODE = '28000';
  END IF;

  RETURN app_private.issue_session(found);
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_session(refresh_token text)
RETURNS public.auth_session
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, app_private, public
AS $$
DECLARE
  token_row app.refresh_tokens;
  found app.users;
  hashed text;
BEGIN
  hashed := encode(digest(refresh_token, 'sha256'), 'hex');

  SELECT * INTO token_row
  FROM app.refresh_tokens
  WHERE token_hash = hashed
    AND revoked_at IS NULL
    AND expires_at > now()
  FOR UPDATE;

  IF token_row.id IS NULL THEN
    RAISE EXCEPTION 'Invalid refresh token' USING ERRCODE = '28000';
  END IF;

  UPDATE app.refresh_tokens SET revoked_at = now() WHERE id = token_row.id;

  SELECT * INTO found FROM app.users WHERE id = token_row.user_id AND deleted_at IS NULL;
  IF found.id IS NULL THEN
    RAISE EXCEPTION 'Account disabled' USING ERRCODE = '28000';
  END IF;

  RETURN app_private.issue_session(found);
END;
$$;

CREATE OR REPLACE FUNCTION public.logout(refresh_token text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, app_private, public
AS $$
BEGIN
  UPDATE app.refresh_tokens
  SET revoked_at = now()
  WHERE token_hash = encode(digest(refresh_token, 'sha256'), 'hex')
    AND revoked_at IS NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.request_password_reset(email text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, app_private, public
AS $$
DECLARE
  found app.users;
  raw_token text;
  env text;
BEGIN
  SELECT * INTO found FROM app.users u
  WHERE u.email = lower(btrim(request_password_reset.email)) AND u.deleted_at IS NULL;

  env := COALESCE((SELECT value FROM app.app_settings WHERE key = 'environment'), 'development');

  IF found.id IS NULL THEN
    RETURN json_build_object('ok', true, 'delivery', 'none');
  END IF;

  raw_token := encode(gen_random_bytes(24), 'hex');
  INSERT INTO app.password_reset_tokens (user_id, token_hash, expires_at)
  VALUES (found.id, encode(digest(raw_token, 'sha256'), 'hex'), now() + interval '1 hour');

  -- Production must send this token via an out-of-band channel. It is returned
  -- only when environment=development so clients can test without a mailer.
  IF env = 'development' THEN
    RETURN json_build_object(
      'ok', true,
      'delivery', 'development_response_only',
      'reset_token', raw_token
    );
  END IF;

  RETURN json_build_object('ok', true, 'delivery', 'queued');
END;
$$;

CREATE OR REPLACE FUNCTION public.reset_password(reset_token text, new_password text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, app_private, public
AS $$
DECLARE
  token_row app.password_reset_tokens;
BEGIN
  IF new_password IS NULL OR char_length(new_password) < 8 THEN
    RAISE EXCEPTION 'Password must be at least 8 characters' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO token_row
  FROM app.password_reset_tokens
  WHERE token_hash = encode(digest(reset_token, 'sha256'), 'hex')
    AND used_at IS NULL
    AND expires_at > now()
  FOR UPDATE;

  IF token_row.id IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired reset token' USING ERRCODE = '28000';
  END IF;

  UPDATE app.users
  SET password_hash = app_private.hash_password(new_password)
  WHERE id = token_row.user_id;

  UPDATE app.password_reset_tokens SET used_at = now() WHERE id = token_row.id;
  UPDATE app.refresh_tokens SET revoked_at = now()
  WHERE user_id = token_row.user_id AND revoked_at IS NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_profile(
  full_name text DEFAULT NULL,
  locale text DEFAULT NULL,
  preferred_currency text DEFAULT NULL,
  phone text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, app_private, public
AS $$
DECLARE
  uid uuid;
  updated app.users;
BEGIN
  uid := app_private.require_user_id();

  IF locale IS NOT NULL AND locale NOT IN ('en', 'tr', 'ar') THEN
    RAISE EXCEPTION 'Unsupported locale' USING ERRCODE = '22023';
  END IF;
  IF preferred_currency IS NOT NULL AND preferred_currency NOT IN ('USD', 'EUR', 'TRY', 'IQD') THEN
    RAISE EXCEPTION 'Unsupported currency' USING ERRCODE = '22023';
  END IF;

  UPDATE app.users u
  SET
    full_name = COALESCE(NULLIF(btrim(update_profile.full_name), ''), u.full_name),
    locale = COALESCE(update_profile.locale, u.locale),
    preferred_currency = COALESCE(update_profile.preferred_currency::app.currency_code, u.preferred_currency),
    phone = COALESCE(update_profile.phone, u.phone)
  WHERE u.id = uid
  RETURNING * INTO updated;

  RETURN json_build_object(
    'id', updated.id,
    'email', updated.email,
    'full_name', updated.full_name,
    'locale', updated.locale,
    'preferred_currency', updated.preferred_currency,
    'phone', updated.phone,
    'app_role', updated.app_role
  );
END;
$$;
