CREATE OR REPLACE FUNCTION public.activate_esim(esim_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, app_private, public
AS $$
DECLARE
  uid uuid;
  esim app.user_esims;
BEGIN
  uid := app_private.require_user_id();

  SELECT * INTO esim FROM app.user_esims WHERE id = activate_esim.esim_id AND user_id = uid FOR UPDATE;
  IF esim.id IS NULL THEN
    RAISE EXCEPTION 'eSIM not found' USING ERRCODE = 'P0002';
  END IF;
  IF esim.status IN ('depleted', 'expired', 'cancelled', 'failed') THEN
    RAISE EXCEPTION 'This eSIM can no longer be activated' USING ERRCODE = '23514';
  END IF;
  IF esim.status = 'active' THEN
    RETURN json_build_object('id', esim.id, 'status', esim.status, 'activated_at', esim.activated_at);
  END IF;
  IF esim.status <> 'ready' THEN
    RAISE EXCEPTION 'eSIM is not ready for activation' USING ERRCODE = '23514';
  END IF;

  UPDATE app.user_esims
  SET status = 'active', activated_at = now()
  WHERE id = esim.id
  RETURNING * INTO esim;

  PERFORM app_private.notify(
    uid, 'esim_activated',
    'eSIM activated', 'eSIM etkinleştirildi', 'تم تفعيل الشريحة',
    'This eSIM is now active. Its balance cannot be shared with other eSIMs.',
    'Bu eSIM artık aktif. Bakiyesi başka bir eSIM ile paylaşılamaz.',
    'أصبحت هذه الشريحة نشطة. لا يمكن مشاركة رصيدها مع شريحة أخرى.',
    jsonb_build_object('esim_id', esim.id)
  );

  RETURN json_build_object(
    'id', esim.id,
    'status', esim.status,
    'activated_at', esim.activated_at,
    'remaining_balance', esim.remaining_balance,
    'is_mock', esim.is_mock
  );
END;
$$;

-- Server-side balance mutation. Client values are display-only.
CREATE OR REPLACE FUNCTION public.apply_esim_usage(
  esim_id uuid,
  usage_amount numeric,
  source text DEFAULT 'mock_sync'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, app_private, public
AS $$
DECLARE
  uid uuid;
  esim app.user_esims;
  new_remaining numeric;
  new_status app.esim_status;
BEGIN
  uid := app_private.require_user_id();
  IF usage_amount IS NULL OR usage_amount <= 0 THEN
    RAISE EXCEPTION 'usage_amount must be positive' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO esim FROM app.user_esims WHERE id = apply_esim_usage.esim_id AND user_id = uid FOR UPDATE;
  IF esim.id IS NULL THEN
    RAISE EXCEPTION 'eSIM not found' USING ERRCODE = 'P0002';
  END IF;
  IF esim.status NOT IN ('ready', 'active') THEN
    RAISE EXCEPTION 'Usage cannot be applied in the current eSIM state' USING ERRCODE = '23514';
  END IF;

  new_remaining := GREATEST(esim.remaining_balance - usage_amount, 0);
  new_status := CASE WHEN new_remaining = 0 THEN 'depleted'::app.esim_status
                     WHEN esim.status = 'ready' THEN 'active'::app.esim_status
                     ELSE esim.status END;

  PERFORM set_config('app.allow_balance_update', 'on', true);

  UPDATE app.user_esims
  SET remaining_balance = new_remaining,
      status = new_status,
      activated_at = COALESCE(activated_at, now())
  WHERE id = esim.id;

  INSERT INTO app.esim_usage (esim_id, usage_amount, balance_before, balance_after, source)
  VALUES (esim.id, usage_amount, esim.remaining_balance, new_remaining, COALESCE(source, 'mock_sync'));

  IF new_remaining > 0 AND new_remaining <= (esim.original_balance * 0.15) THEN
    PERFORM app_private.notify(
      uid, 'low_balance',
      'Low data balance', 'Düşük veri bakiyesi', 'رصيد بيانات منخفض',
      'This eSIM is running low. Balance cannot be moved from another eSIM.',
      'Bu eSIM''in bakiyesi azalıyor. Başka eSIM''den aktarım yok.',
      'رصيد هذه الشريحة منخفض. لا يمكن نقل الرصيد من شريحة أخرى.',
      jsonb_build_object('esim_id', esim.id, 'remaining_balance', new_remaining)
    );
  END IF;

  RETURN json_build_object(
    'esim_id', esim.id,
    'balance_before', esim.remaining_balance,
    'balance_after', new_remaining,
    'status', new_status,
    'source', COALESCE(source, 'mock_sync')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.expire_due_esims()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, app_private, public
AS $$
DECLARE
  uid uuid;
  n integer;
BEGIN
  uid := app_private.require_user_id();
  UPDATE app.user_esims
  SET status = 'expired'
  WHERE status IN ('ready', 'active')
    AND expires_at IS NOT NULL
    AND expires_at < now()
    AND (user_id = uid OR app.current_app_role() = 'admin');
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_notification_read(notification_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, public
AS $$
BEGIN
  UPDATE app.notifications
  SET is_read = true
  WHERE id = notification_id AND user_id = app_private.require_user_id();
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, public
AS $$
BEGIN
  UPDATE app.notifications
  SET is_read = true
  WHERE user_id = app_private.require_user_id() AND is_read = false;
END;
$$;

-- Admin-only helpers live in public but EXECUTE is granted only to admin.
CREATE OR REPLACE FUNCTION public.admin_list_users()
RETURNS TABLE (
  id uuid,
  email citext,
  full_name text,
  app_role app.user_role,
  locale text,
  preferred_currency app.currency_code,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, public
AS $$
BEGIN
  IF app.current_app_role() <> 'admin' THEN
    RAISE EXCEPTION 'Admin role required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT u.id, u.email, u.full_name, u.app_role, u.locale, u.preferred_currency, u.created_at
  FROM app.users u
  WHERE u.deleted_at IS NULL
  ORDER BY u.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_plan_active(plan_id uuid, is_active boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, public
AS $$
BEGIN
  IF app.current_app_role() <> 'admin' THEN
    RAISE EXCEPTION 'Admin role required' USING ERRCODE = '42501';
  END IF;
  UPDATE app.esim_plans SET is_active = admin_set_plan_active.is_active WHERE id = plan_id;
END;
$$;
