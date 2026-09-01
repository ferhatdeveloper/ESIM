CREATE OR REPLACE FUNCTION app_private.setting_numeric(p_key text, p_default numeric)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE((SELECT value::numeric FROM app.app_settings WHERE key = p_key), p_default);
$$;

CREATE OR REPLACE FUNCTION app_private.guard_esim_assignment()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
      RAISE EXCEPTION 'eSIM cannot be reassigned' USING ERRCODE = '23514';
    END IF;
    IF OLD.status IN ('depleted', 'expired', 'cancelled')
       AND NEW.status IN ('pending', 'provisioning', 'ready', 'active') THEN
      RAISE EXCEPTION 'Terminal eSIM cannot be reactivated' USING ERRCODE = '23514';
    END IF;
    IF NEW.remaining_balance IS DISTINCT FROM OLD.remaining_balance
       AND current_setting('app.allow_balance_update', true) IS DISTINCT FROM 'on' THEN
      RAISE EXCEPTION 'Balance updates must go through apply_esim_usage' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_user_esims_guard
  BEFORE UPDATE ON app.user_esims
  FOR EACH ROW EXECUTE FUNCTION app_private.guard_esim_assignment();

CREATE OR REPLACE FUNCTION app_private.guard_usage_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'eSIM usage history is immutable' USING ERRCODE = '42501';
END;
$$;

CREATE TRIGGER trg_esim_usage_no_update
  BEFORE UPDATE OR DELETE ON app.esim_usage
  FOR EACH ROW EXECUTE FUNCTION app_private.guard_usage_immutable();

CREATE OR REPLACE FUNCTION public.create_checkout(
  plan_id uuid,
  currency text,
  idempotency_key text
)
RETURNS public.checkout_quote
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, app_private, public
AS $$
DECLARE
  uid uuid;
  plan app.esim_plans;
  price app.plan_prices;
  country app.countries;
  region app.regions;
  existing app.orders;
  tax_rate numeric;
  fee_rate numeric;
  subtotal numeric;
  tax_amt numeric;
  fee_amt numeric;
  total_amt numeric;
  new_order app.orders;
  quote public.checkout_quote;
  dest text;
BEGIN
  uid := app_private.require_user_id();

  IF idempotency_key IS NULL OR btrim(idempotency_key) = '' THEN
    RAISE EXCEPTION 'idempotency_key is required' USING ERRCODE = '22023';
  END IF;
  IF currency NOT IN ('USD', 'EUR', 'TRY', 'IQD') THEN
    RAISE EXCEPTION 'Unsupported currency' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO existing
  FROM app.orders
  WHERE user_id = uid AND idempotency_key = btrim(create_checkout.idempotency_key);

  IF existing.id IS NOT NULL THEN
    SELECT oi.plan_id INTO plan.id FROM app.order_items oi WHERE oi.order_id = existing.id;
    SELECT * INTO plan FROM app.esim_plans WHERE id = plan.id;
    SELECT * INTO country FROM app.countries WHERE id = plan.country_id;
    SELECT * INTO region FROM app.regions WHERE id = plan.region_id;
    dest := COALESCE(country.name_en, region.name_en, 'eSIM');
    quote.order_id := existing.id;
    quote.plan_id := plan.id;
    quote.destination := dest;
    quote.plan_name := plan.name_en;
    quote.data_amount_mb := plan.data_amount_mb;
    quote.validity_days := plan.validity_days;
    quote.currency := existing.currency::text;
    quote.subtotal := existing.subtotal;
    quote.tax := existing.tax;
    quote.fees := existing.fees;
    quote.total := existing.total;
    quote.payment_mode := 'mock';
    RETURN quote;
  END IF;

  SELECT * INTO plan
  FROM app.esim_plans p
  WHERE p.id = create_checkout.plan_id AND p.is_active;

  IF plan.id IS NULL THEN
    RAISE EXCEPTION 'Plan not available' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO price
  FROM app.plan_prices
  WHERE plan_id = plan.id AND currency = create_checkout.currency::app.currency_code;

  IF price.id IS NULL THEN
    RAISE EXCEPTION 'Price not available for currency' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO country FROM app.countries WHERE id = plan.country_id;
  SELECT * INTO region FROM app.regions WHERE id = plan.region_id;

  tax_rate := app_private.setting_numeric('tax_rate', 0);
  fee_rate := app_private.setting_numeric('fee_rate', 0);
  subtotal := price.amount;
  tax_amt := round(subtotal * tax_rate, 2);
  fee_amt := round(subtotal * fee_rate, 2);
  total_amt := subtotal + tax_amt + fee_amt;

  INSERT INTO app.orders (
    user_id, status, currency, subtotal, tax, fees, total, idempotency_key
  ) VALUES (
    uid, 'pending_payment', create_checkout.currency::app.currency_code,
    subtotal, tax_amt, fee_amt, total_amt, btrim(create_checkout.idempotency_key)
  )
  RETURNING * INTO new_order;

  INSERT INTO app.order_items (order_id, plan_id, quantity, unit_price, currency)
  VALUES (new_order.id, plan.id, 1, subtotal, new_order.currency);

  INSERT INTO app.payments (order_id, provider, status, amount, currency)
  VALUES (new_order.id, 'mock', 'pending', total_amt, new_order.currency);

  dest := COALESCE(country.name_en, region.name_en, 'eSIM');
  quote.order_id := new_order.id;
  quote.plan_id := plan.id;
  quote.destination := dest;
  quote.plan_name := plan.name_en;
  quote.data_amount_mb := plan.data_amount_mb;
  quote.validity_days := plan.validity_days;
  quote.currency := new_order.currency::text;
  quote.subtotal := new_order.subtotal;
  quote.tax := new_order.tax;
  quote.fees := new_order.fees;
  quote.total := new_order.total;
  quote.payment_mode := 'mock';
  RETURN quote;
END;
$$;

-- Mock payment provider adapter. Replace the body later with a real provider
-- without changing Flutter. This function is not a live card processor.
CREATE OR REPLACE FUNCTION app_private.capture_mock_payment(
  p_payment app.payments,
  p_succeed boolean
)
RETURNS app.payments
LANGUAGE plpgsql
AS $$
DECLARE
  updated app.payments;
BEGIN
  IF p_succeed THEN
    UPDATE app.payments
    SET status = 'captured',
        provider_payment_id = COALESCE(provider_payment_id, 'MOCK-PAY-' || substr(id::text, 1, 8))
    WHERE id = p_payment.id
    RETURNING * INTO updated;
    INSERT INTO app.payment_transactions (payment_id, txn_type, status, note)
    VALUES (p_payment.id, 'capture', 'captured', 'Mock payment captured');
  ELSE
    UPDATE app.payments SET status = 'failed' WHERE id = p_payment.id
    RETURNING * INTO updated;
    INSERT INTO app.payment_transactions (payment_id, txn_type, status, note)
    VALUES (p_payment.id, 'capture', 'failed', 'Mock payment failed');
  END IF;
  RETURN updated;
END;
$$;

-- Mock eSIM provider. Installation values are prefixed MOCK- and must not be
-- treated as a live SM-DP+ payload.
CREATE OR REPLACE FUNCTION app_private.mock_provision_esim(p_order app.orders, p_plan app.esim_plans)
RETURNS TABLE (
  iccid text,
  smdp_address text,
  activation_code text,
  confirmation_code text,
  is_mock boolean
)
LANGUAGE sql
AS $$
  SELECT
    'MOCK-ICCID-' || upper(substr(replace(p_order.id::text, '-', ''), 1, 12)),
    'mock-smdp.example.invalid',
    'MOCK-ACT-' || upper(substr(replace(p_order.id::text, '-', ''), 1, 10)),
    'MOCK-CONF-' || upper(substr(replace(p_order.id::text, '-', ''), 1, 6)),
    true;
$$;

CREATE OR REPLACE FUNCTION app_private.assign_provisioned_esim(
  p_order app.orders,
  p_plan app.esim_plans,
  p_iccid text,
  p_smdp text,
  p_activation text,
  p_confirmation text,
  p_is_mock boolean
)
RETURNS app.user_esims
LANGUAGE plpgsql
AS $$
DECLARE
  created app.user_esims;
BEGIN
  INSERT INTO app.user_esims (
    user_id, order_id, plan_id, provider_id,
    iccid, smdp_address, activation_code, confirmation_code,
    original_balance, remaining_balance, balance_unit,
    status, expires_at, is_mock
  ) VALUES (
    p_order.user_id, p_order.id, p_plan.id, p_plan.provider_id,
    p_iccid, p_smdp, p_activation, p_confirmation,
    p_plan.data_amount_mb, p_plan.data_amount_mb, 'MB',
    'ready',
    now() + make_interval(days => p_plan.validity_days),
    p_is_mock
  )
  RETURNING * INTO created;

  UPDATE app.orders SET status = 'completed' WHERE id = p_order.id;

  PERFORM app_private.notify(
    p_order.user_id,
    'esim_ready',
    'Your eSIM is ready',
    'eSIM''iniz hazır',
    'شريحة eSIM جاهزة',
    'Install the eSIM from My eSIMs. This is a one-time product with its own balance.',
    'eSIM''i eSIM''lerim ekranından kurun. Bakiye yalnızca bu eSIM''e aittir.',
    'ثبّت الشريحة من شاشتي. الرصيد يخص هذه الشريحة فقط.',
    jsonb_build_object('esim_id', created.id, 'order_id', p_order.id, 'is_mock', p_is_mock)
  );
  RETURN created;
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_mock_payment(order_id uuid, succeed boolean DEFAULT true)
RETURNS public.purchase_result
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, app_private, public
AS $$
DECLARE
  uid uuid;
  ord app.orders;
  pay app.payments;
  plan app.esim_plans;
  existing app.user_esims;
  provisioned RECORD;
  created app.user_esims;
  result public.purchase_result;
BEGIN
  uid := app_private.require_user_id();

  SELECT * INTO ord FROM app.orders WHERE id = confirm_mock_payment.order_id AND user_id = uid FOR UPDATE;
  IF ord.id IS NULL THEN
    RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO existing FROM app.user_esims WHERE user_esims.order_id = ord.id;
  IF existing.id IS NOT NULL THEN
    result.order_id := ord.id;
    result.order_status := ord.status::text;
    result.payment_status := (SELECT status::text FROM app.payments WHERE payments.order_id = ord.id);
    result.esim_id := existing.id;
    result.esim_status := existing.status::text;
    result.is_mock_provisioning := existing.is_mock;
    result.message := 'Already provisioned for this order';
    RETURN result;
  END IF;

  SELECT * INTO pay FROM app.payments WHERE payments.order_id = ord.id FOR UPDATE;
  IF pay.status = 'captured' AND ord.status IN ('paid', 'provisioning', 'completed') THEN
    NULL;
  ELSIF ord.status <> 'pending_payment' THEN
    RAISE EXCEPTION 'Order is not awaiting payment' USING ERRCODE = '23514';
  END IF;

  IF pay.status <> 'captured' THEN
    pay := app_private.capture_mock_payment(pay, succeed);
  END IF;

  IF pay.status <> 'captured' THEN
    UPDATE app.orders SET status = 'failed' WHERE id = ord.id;
    PERFORM app_private.notify(
      uid, 'payment_failed',
      'Payment failed', 'Ödeme başarısız', 'فشل الدفع',
      'The mock payment did not capture. No eSIM was created.',
      'Sahte ödeme alınamadı. eSIM oluşturulmadı.',
      'لم يتم التقاط الدفع التجريبي. لم يتم إنشاء شريحة.',
      jsonb_build_object('order_id', ord.id)
    );
    result.order_id := ord.id;
    result.order_status := 'failed';
    result.payment_status := pay.status::text;
    result.esim_id := NULL;
    result.esim_status := NULL;
    result.is_mock_provisioning := true;
    result.message := 'Mock payment failed; no eSIM created';
    RETURN result;
  END IF;

  UPDATE app.orders SET status = 'paid' WHERE id = ord.id RETURNING * INTO ord;
  PERFORM app_private.notify(
    uid, 'purchase_successful',
    'Purchase successful', 'Satın alma başarılı', 'تم الشراء بنجاح',
    'Payment captured. Provisioning your one-time eSIM.',
    'Ödeme alındı. Tek kullanımlık eSIM hazırlanıyor.',
    'تم التقاط الدفع. جارٍ تجهيز الشريحة لمرة واحدة.',
    jsonb_build_object('order_id', ord.id)
  );

  SELECT p.* INTO plan
  FROM app.order_items i
  JOIN app.esim_plans p ON p.id = i.plan_id
  WHERE i.order_id = ord.id;

  UPDATE app.orders SET status = 'provisioning' WHERE id = ord.id RETURNING * INTO ord;

  SELECT * INTO provisioned FROM app_private.mock_provision_esim(ord, plan);

  IF provisioned.iccid IS NULL THEN
    UPDATE app.orders SET status = 'provisioning' WHERE id = ord.id;
    PERFORM app_private.notify(
      uid, 'provisioning_failed',
      'Provisioning needs attention', 'Provizyon dikkat gerektiriyor', 'يحتاج التجهيز إلى متابعة',
      'Mock provider did not return installation data. No active eSIM was created.',
      'Sahte sağlayıcı kurulum verisi döndürmedi. Aktif eSIM oluşturulmadı.',
      'لم يُرجع المزوّد التجريبي بيانات التثبيت. لم تُنشأ شريحة نشطة.',
      jsonb_build_object('order_id', ord.id)
    );
    result.order_id := ord.id;
    result.order_status := 'provisioning';
    result.payment_status := pay.status::text;
    result.esim_id := NULL;
    result.esim_status := NULL;
    result.is_mock_provisioning := true;
    result.message := 'Provisioning recoverable; no fake active eSIM created';
    RETURN result;
  END IF;

  created := app_private.assign_provisioned_esim(
    ord, plan,
    provisioned.iccid, provisioned.smdp_address,
    provisioned.activation_code, provisioned.confirmation_code,
    provisioned.is_mock
  );

  result.order_id := ord.id;
  result.order_status := 'completed';
  result.payment_status := pay.status::text;
  result.esim_id := created.id;
  result.esim_status := created.status::text;
  result.is_mock_provisioning := true;
  result.message := 'Mock provisioning completed; not a live carrier profile';
  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.retry_provisioning(order_id uuid)
RETURNS public.purchase_result
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, app_private, public
AS $$
DECLARE
  uid uuid;
  ord app.orders;
  pay app.payments;
  plan app.esim_plans;
  existing app.user_esims;
  provisioned RECORD;
  created app.user_esims;
  result public.purchase_result;
BEGIN
  uid := app_private.require_user_id();
  SELECT * INTO ord FROM app.orders WHERE id = retry_provisioning.order_id AND user_id = uid FOR UPDATE;
  IF ord.id IS NULL THEN
    RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO existing FROM app.user_esims WHERE user_esims.order_id = ord.id;
  IF existing.id IS NOT NULL THEN
    RAISE EXCEPTION 'eSIM already exists for this order' USING ERRCODE = '23505';
  END IF;

  SELECT * INTO pay FROM app.payments WHERE payments.order_id = ord.id;
  IF pay.status <> 'captured' THEN
    RAISE EXCEPTION 'Payment is not captured' USING ERRCODE = '23514';
  END IF;

  SELECT p.* INTO plan
  FROM app.order_items i
  JOIN app.esim_plans p ON p.id = i.plan_id
  WHERE i.order_id = ord.id;

  SELECT * INTO provisioned FROM app_private.mock_provision_esim(ord, plan);
  created := app_private.assign_provisioned_esim(
    ord, plan,
    provisioned.iccid, provisioned.smdp_address,
    provisioned.activation_code, provisioned.confirmation_code,
    provisioned.is_mock
  );

  result.order_id := ord.id;
  result.order_status := 'completed';
  result.payment_status := pay.status::text;
  result.esim_id := created.id;
  result.esim_status := created.status::text;
  result.is_mock_provisioning := true;
  result.message := 'Mock retry provisioning completed';
  RETURN result;
END;
$$;
